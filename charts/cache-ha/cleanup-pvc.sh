#!/bin/bash

# Simple script to clean up PVCs for a Helm release
# Usage: ./cleanup-pvc.sh <release-name> [namespace]

RELEASE_NAME=${1:-"test-gateway"}
NAMESPACE=${2:-"default"}

echo "Cleaning up PVCs for release: $RELEASE_NAME in namespace: $NAMESPACE"

# Get all PVCs for this release
kubectl get pvc -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" -o json | \
jq -r '.items[] | .metadata.name' | while read -r pvc_name; do
  if [ -n "$pvc_name" ]; then
    echo "Deleting PVC: $pvc_name"
    kubectl delete pvc "$pvc_name" -n "$NAMESPACE" --ignore-not-found=true
  fi
done

echo "PVC cleanup completed"
