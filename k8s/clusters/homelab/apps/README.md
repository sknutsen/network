# apps

No in-cluster application deploy. Apex `zdk.no` is not a homelab site.

The Flux `apps` Kustomization stays so `prune: true` removes the old Zdk
GitRepository / IngressRoute stub. Do not add those objects back.
