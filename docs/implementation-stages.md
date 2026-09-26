# Build record

The staged rollout that produced this network is finished. This file is not
a backlog and not a sequence to resume.

What is deployed is the tree:

- `router/` — janus (NixOS)
- `nodes/` — RK1 NixOS, k3s on
- `switch/` — CRS310
- `services/` — Caddy, TrueNAS compose, app notes
- `k8s/` — Flux
- `secrets/` — sops

Those hosts are described from [plan.md](plan.md). If a document and a host
disagree, the host wins; update the document.

Open follow-ups: [todo.md](todo.md).

NPU/GPU kernel work stays in
[plans/rk1-bsp-fork.md](plans/rk1-bsp-fork.md).

Comments and headings that still say "Stage N" name when a piece was added.
They are not tasks.

## Where the old stages live now

| Former area | Living description |
|-------------|--------------------|
| Design, VLANs, firewall, inventory | [vlan-plan.md](vlan-plan.md), [firewall-matrix.md](firewall-matrix.md), [inventory.md](inventory.md), [decisions.md](decisions.md) |
| Router | [router/README.md](../router/README.md), `router/hosts/optiplex/configuration.nix` |
| Switch and Wi-Fi | [switch/README.md](../switch/README.md), [vlan-plan.md](vlan-plan.md) |
| Services and k3s | [architecture.md](architecture.md), service READMEs, [nodes/README.md](../nodes/README.md), [k8s/README.md](../k8s/README.md) |
| VPN | [runbooks/wireguard-clients.md](runbooks/wireguard-clients.md), [runbooks/headscale.md](runbooks/headscale.md), `router/modules/vpn.nix` |
| Public HTTPS | [runbooks/wan-caddy.md](runbooks/wan-caddy.md), `services/caddy/Caddyfile` |
| Operations | [runbooks/](runbooks/) |
