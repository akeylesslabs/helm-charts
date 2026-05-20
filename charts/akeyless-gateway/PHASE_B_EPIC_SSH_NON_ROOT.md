# Phase B Epic: Non-Root SSH Bastion

**Parent:** ASM-17961 (Kyverno strict-policy hardening)

## Summary

Refactor SRA SSH Bastion to run as non-root (UID 1001), achieving full Kyverno `restricted` profile compliance without policy exceptions.

## Background

ASM-17961 Phase A implemented interim hardening:
- Dropped `privileged: true`
- Narrowed capabilities to 7 (from unrestricted)
- SSH listens on port 2222 (container), Service port 22 (external)
- **Still requires root (UID 0)** due to `mount --bind /dev/pts`, `adduser`/`deluser`, `mknod` for per-session chroot jails

Phase A was a ~5-day stop-gap. Phase B is the full solution.

## Goals

1. **Run sshd as `akeyless` user (UID 1001)** with only `CAP_NET_BIND_SERVICE` (if port 22) or no caps (if port 2222)
2. **Drop all session-level root operations:** no `mount --bind`, no `adduser`/`deluser`, no `mknod`
3. **Zero Kyverno exceptions:** pass `restricted` profile without annotations
4. **Maintain functionality:** SSH recording, per-session isolation, chroot jails, file transfer (SFTP)

## Technical Design

### 1. Replace `mount --bind /dev/pts` with PTY fd-passing

**Current:** Per-session chroot jail has `/dev/pts` bind-mounted from host (requires `CAP_SYS_ADMIN`).

**New:**
- Allocate PTY **outside** the chroot jail (in the main `ssh-proxy-server` process)
- Pass the PTY master/slave fds into the session process via `socketpair` or `SCM_RIGHTS`
- Session process runs inside chroot without needing `/dev/pts` at all
- Precedent: OpenSSH `ChrootDirectory` works without `/dev/pts` bind when `ForceCommand` allocates its own PTY

**Implementation:**
- `handler.go`: `setupSessionJail()` — allocate `pty.Start()` before `os.Chroot()`
- Pass `cmd.Stdin`, `cmd.Stdout`, `cmd.Stderr` to child via inherited fds (standard Go `exec.Cmd` already does this)
- Remove `exec.Command("mount", "--bind", "/dev/pts", jailPath+"/dev/pts")` (lines 410–414 in `targets-handler-linux/handler.go`)

### 2. Replace `adduser`/`deluser` with user-namespace mapping

**Current:** Each SSH session dynamically creates a real Unix user via `adduser` (requires `CAP_CHOWN`, `CAP_SETUID`, `CAP_SETGID`, `CAP_DAC_OVERRIDE`, `CAP_FOWNER`).

**New:**
- Run the SSH bastion container with **user namespaces** enabled (`userns_mode: host` in Docker, `hostUsers: false` in K8s pod securityContext)
- Map session UIDs (e.g., 10000–20000 inside container) to unprivileged UIDs on the host
- No real `/etc/passwd` mutation needed — the kernel's user namespace handles UID translation
- Session processes run as ephemeral UIDs that don't require `adduser`

**Implementation:**
- Helm chart: Add `pod.spec.securityContext.hostUsers: false` when `strictSecurityPolicy.enabled` (K8s 1.25+)
- Docker Compose: Add `userns_mode: "host"` (or custom mapping via `--userns-remap`)
- `handler.go`: Replace `exec.Command("adduser", ...)` with UID allocation from a pool (e.g., `getNextSessionUID()` returns 10000, 10001, ...)
- `deluser` removal: Not needed — ephemeral UIDs auto-reclaimed when session ends

### 3. Replace `mknod` with pre-initialized device nodes

**Current:** Session jails dynamically create `/dev/null`, `/dev/zero`, etc. via `mknod` (requires `CAP_MKNOD`).

**New:**
- Pre-create all necessary device nodes at **build time** in the Dockerfile (when running as root during image build):

```dockerfile
RUN mkdir -p /jail-template/dev && \
    mknod /jail-template/dev/null c 1 3 && \
    mknod /jail-template/dev/zero c 1 5 && \
    mknod /jail-template/dev/random c 1 8 && \
    mknod /jail-template/dev/urandom c 1 9 && \
    chmod 666 /jail-template/dev/* && \
    chown -R akeyless:akeyless /jail-template
```

- At session start, `cp -a /jail-template /tmp/sessions/session-123` (copy preserves device nodes; no `mknod` needed at runtime)

**Implementation:**
- Dockerfile: Add `/jail-template` with pre-created devices
- `handler.go`: `setupSessionJail()` — replace `exec.Command("mknod", ...)` with `exec.Command("cp", "-a", "/jail-template", jailPath)`

### 4. Run sshd as `akeyless` user

**Current:** `sshd` runs as root in `supervisord.conf` (`user=root`).

**New:**
- Change `supervisord.conf`: `user=akeyless`
- If port 22 (privileged): Add `CAP_NET_BIND_SERVICE` to container securityContext (already default in Phase A)
- If port 2222 (unprivileged): No caps needed

**Implementation:**
- `bastions/ssh-proxy/config/supervisord.conf`: Change `[program:ssh-proxy-server]` and `[program:sshd]` `user=root` → `user=akeyless`
- Helm chart: `ssh-deployment.yaml` — when `strictSecurityPolicy.enabled`:
  ```yaml
  securityContext:
    runAsUser: 1001
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    capabilities:
      drop: [ALL]
      add: [NET_BIND_SERVICE]  # Only if Service port 22; omit if 2222
  ```

### 5. Validate SFTP/file transfer

**Current:** SFTP subsystem (`internal-sftp` in `sshd_config`) works because sshd is root.

**New:** `internal-sftp` runs as the session user (already unprivileged). Test:
- Connect via Guacamole → SSH target → upload/download file
- Verify recording captures SFTP traffic

## Success Criteria

- [ ] SSH bastion Deployment runs as `runAsUser: 1001`, `runAsNonRoot: true`
- [ ] Container `securityContext`: `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, optionally `add: [NET_BIND_SERVICE]`
- [ ] No `privileged: true`, no `CAP_SYS_ADMIN`, `CAP_MKNOD`, `CAP_CHOWN`, `CAP_SETUID`, `CAP_SETGID`, `CAP_FOWNER`, `CAP_DAC_OVERRIDE`
- [ ] Kyverno `restricted` policy passes without exclusions
- [ ] Functional tests pass:
  - [ ] SSH session connects, shell interactive
  - [ ] Per-session chroot jail isolates users
  - [ ] Session recording works (audit trail)
  - [ ] SFTP file upload/download via Guacamole
  - [ ] Multi-session concurrency (10+ simultaneous users)
  - [ ] Session cleanup (no leaked processes/UIDs after disconnect)

## Testing Plan

1. **Unit tests:** `targets-handler-linux/handler_test.go` — mock `setupSessionJail()`, verify no `mount`/`adduser`/`mknod` calls
2. **Integration tests:** Deploy to K8s test cluster with Kyverno `restricted` policy enabled
3. **Load test:** 50 concurrent SSH sessions, measure CPU/memory, verify no jail leaks
4. **Security audit:** Run `kube-bench`, `kubesec`, `trivy` against rendered manifests
5. **Customer acceptance:** Deploy to pilot customer environment, validate their Kyverno policies pass

## Risks

1. **User namespaces not supported by all K8s distros** (e.g., older GKE versions, some on-prem clusters)
   - **Mitigation:** Feature-gate on K8s version check; fallback to Phase A if `hostUsers: false` unsupported
2. **PTY fd-passing may break interactive shell edge cases** (e.g., terminal resizing, raw mode)
   - **Mitigation:** Extensive testing with `tmux`, `vim`, `top`, etc.; ensure `TIOCGWINSZ` ioctl propagates
3. **Chroot jail escape** if device nodes or UID mapping misconfigured
   - **Mitigation:** Security review by external auditor; compare to OpenSSH `ChrootDirectory` reference implementation

## Timeline

- **Design/POC:** 1 week (PTY fd-passing prototype)
- **Implementation:** 2 weeks (Dockerfile, handler.go, supervisord, Helm chart)
- **Testing/QA:** 1 week (functional, load, security)
- **Total:** ~4 weeks (adjust for team capacity)

## Dependencies

- **K8s 1.25+** for `hostUsers: false` (user namespaces)
- **Helm chart refactor:** Conditional logic for Phase A vs Phase B based on `strictSecurityPolicy.sshPhaseB.enabled`
- **Image rebuild:** `akeyless/zero-trust-bastion` Dockerfile changes

## Stakeholders

- **Security team:** Approve user-namespace mapping, PTY fd-passing design
- **DevOps:** Validate K8s distro support (GKE, EKS, AKS, on-prem)
- **Customer success:** Pilot with high-security customers (financial services, healthcare)

## Documentation

- Update `STRICT_SECURITY_POLICY.md`: Remove "Phase A exception" section, add "Phase B complete" badge
- Add `docs/SSH_BASTION_ARCHITECTURE.md`: Diagram of PTY allocation, user namespaces, jail setup
- Update `README.md`: "Full non-root SSH bastion in v2.0+"

## Related Issues

- **Parent:** ASM-17961 (Kyverno strict-policy hardening)
- **Upstream:** Consider upstreaming PTY fd-passing pattern to OpenSSH (if novel)
- **Follow-up:** Apply same pattern to ZTWA dispatcher/worker (separate ticket)
