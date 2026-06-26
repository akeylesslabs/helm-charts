# keyway — helm-charts render-test + lint runner

Keyway tool (the akeyless tooling standard): typed YAML config validated before
use, a typed `Outcome` + JSON receipt, exit codes `0/1/2`, and **zero shell**.
The only subprocess is `helm`, invoked via `os/exec` with a discrete argument
list — never through a shell. It replaces the `.github/scripts/*.sh` chart glue.

## Subcommands

| Command | What it does |
|---|---|
| `keyway lint` | `helm lint` every (configured) chart |
| `keyway unittest` | `helm unittest` every chart that ships a `tests/` suite — the pure-render gate (no cluster, deterministic). Charts without a suite are **skipped**, not failed. |
| `keyway ci` | `lint` + `unittest` across all charts, one aggregate JSON receipt |

## Run — nix (the sanctioned entry point)

The apps inject a `helm` wrapped with the `helm-unittest` plugin, so there is no
`helm plugin install` and no PATH assumption:

```sh
nix run ./tools/keyway#keyway-ci
nix run ./tools/keyway#keyway-unittest
nix run ./tools/keyway#keyway-lint
nix run ./tools/keyway#keyway-ci -- --receipt keyway-receipt.json
```

## Run — local dev (helm + helm-unittest already on PATH)

```sh
cd tools/keyway && go test ./...
go run . ci                 # from the repo root
```

## Config — `keyway.yaml` (repo root)

Typed; **unknown keys are rejected**. A missing file falls back to the defaults
(`helm` + `charts/`, lint + unittest enabled). See the committed `keyway.yaml`.

## Exit codes (Keyway)

| Code | Meaning |
|---|---|
| `0` | every gate passed |
| `1` | a gate evaluated and **failed** (lint or render findings) |
| `2` | the **tool** errored (bad config, helm missing) — never collapsed with `1` |

## Render tests

Suites live next to each chart at `charts/<chart>/tests/*_test.yaml`
(helm-unittest). They render templates and assert on the output — no cluster
needed. `failedTemplate` assertions prove a chart's fail-loud guards fire.
