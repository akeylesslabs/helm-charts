## Summary

This PR adds Pod Disruption Budget (PDB) support for the Akeyless Kubernetes Secrets Injection webhook, addressing ASM-14766.

## Changes Made

### ✨ New Features
- **Pod Disruption Budget Support**: Added PDB configuration for the webhook deployment to ensure high availability during cluster maintenance operations
- **Enhanced Label Management**: Introduced centralized label helpers for consistent labeling across all webhook resources

### 🔧 Improvements
- **Template Refactoring**: Fixed typo in `deployment.type` helper function (was `deyploymant.type`)
- **Label Standardization**: Consolidated duplicate label definitions into reusable helper templates
- **Chart Version**: Bumped chart version from 1.17.1 to 1.17.2

### 📁 Files Modified
- `charts/akeyless-k8s-secrets-injection/Chart.yaml` - Version bump
- `charts/akeyless-k8s-secrets-injection/templates/_helpers.tpl` - Added label helpers, fixed typo
- `charts/akeyless-k8s-secrets-injection/templates/webhook-deployment.yaml` - Updated to use new helpers
- `charts/akeyless-k8s-secrets-injection/templates/webhook-pdb.yaml` - **NEW**: PDB template
- `charts/akeyless-k8s-secrets-injection/templates/webhook-servicaccount.yaml` - Updated labels
- `charts/akeyless-k8s-secrets-injection/templates/webhook-service.yaml` - Updated labels
- `charts/akeyless-k8s-secrets-injection/values.yaml` - Added PDB configuration options

## Configuration

The PDB can be configured through the `values.yaml`:

```yaml
pdb:
  enabled: false  # Set to true to enable PDB
  labels: {}      # Custom labels for the PDB
  annotations: {} # Custom annotations for the PDB
  minAvailable: "" # Number/percentage of pods that must be available
  maxUnavailable: "" # Number/percentage of pods that can be unavailable
```

**Note**: PDB is only applicable to Deployments, not DaemonSets.

## Testing

- [ ] Verified PDB template renders correctly with various configurations
- [ ] Tested label helpers across all modified templates
- [ ] Confirmed backward compatibility with existing deployments

## Related Issues

- **ASM-14766**: Add PDB support for k8s-injector

## Breaking Changes

None. This is a backward-compatible enhancement.

## Checklist

- [x] Chart version bumped
- [x] Labels and selectors updated consistently
- [x] PDB configuration documented
- [x] Template helpers added for maintainability
- [x] All existing functionality preserved