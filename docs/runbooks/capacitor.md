# Capacitor (`capacitor.lab.zdk.no`)

In-cluster Flux UI. TLS and Authelia stay on janus. Traefik on
`10.10.30.100:80` is HTTP only. Laptop “Capacitor Next” is optional and
does not replace this.

Login is Authelia user **`zdk`**, same as Grafana. There is no Capacitor
password form.

## Path

```
browser (trusted)
  → Caddy 10.10.30.1 (dns01 + Authelia forward_auth)
  → Traefik 10.10.30.100 Host(capacitor.lab.zdk.no)
  → Service capacitor.flux-system:9000
```

Unbound `capacitor.lab.zdk.no` is an explicit A to Caddy (`10.10.30.1`).

Flux objects:

- `OCIRepository` / `Kustomization` `capacitor` in `flux-system`
  (`k8s/clusters/homelab/infra/core/capacitor.yaml`)
- IngressRoute `capacitor` in `flux-system`
  (`infra/config/ingressroutes.yaml`)
- NetworkPolicy `allow-capacitor` — bootstrap netpol only allows
  flux-system; Traefik is in another namespace
  (`infra/config/capacitor-netpol.yaml`)

## Healthy

```bash
kubectl -n flux-system get kustomization capacitor
kubectl -n flux-system get deploy,svc,pod -l app.kubernetes.io/name=onechart
kubectl -n flux-system get netpol allow-capacitor
curl -sI https://capacitor.lab.zdk.no
```

Expect Authelia redirect or 200 after login. Pod Ready. Service `:9000`.

## Failures

| Symptom | Fix |
| ------- | --- |
| 502 / empty upstream | Traefik or the pod is down. `kubectl -n flux-system describe pod` on the Capacitor pod. Confirm MetalLB still owns `.100`. |
| Timeout / hang after Authelia | Netpol. Without `allow-capacitor`, Traefik cannot reach `:9000`. |
| Authelia loop | Hitting Capacitor while `auth.lab.zdk.no` is down. Fix Authelia first (`10.10.30.20:9091`). |
| `NXDOMAIN` / wrong host | Unbound missing the A record — janus not rebuilt after `dns.nix` change. |
| TLS internal error | ACME, not Capacitor. [acme-failure.md](acme-failure.md). |
| Flux not pulling OCI | `kubectl -n flux-system describe ocirepository capacitor`. Image must be `linux/arm64`. |

Caddy already sends `Host` to Traefik. Do not add a second IngressRoute
in `monitoring` or `default`.

## Do not

- Unsuspend the Zdk `GitRepository` to “test” Capacitor.
- Schedule Capacitor (or anything else) on nordri. CP taint stays.
- Put Authelia in the cluster in front of Capacitor. Forward-auth is
  Caddy’s job.
- Browse it from IoT / guest (Caddy INPUT is trusted + servers + later VPN).
