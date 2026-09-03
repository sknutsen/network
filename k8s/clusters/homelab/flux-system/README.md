# flux-system

Created by `flux bootstrap`. See [k8s/README.md](../../../README.md).

Do not add `gotk-components.yaml` or `gotk-sync.yaml` by hand. After
bootstrap those files land here and must stay in git so the cluster can
reconcile.

If you later add a `kustomization.yaml` in the parent directory, it must
list `./flux-system` so prune does not delete the controllers.
