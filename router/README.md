# Router (OptiPlex 9020 MT)

NixOS flake for the homelab edge router. Design sources:

- [docs/vlan-plan.md](../docs/vlan-plan.md)
- [docs/firewall-matrix.md](../docs/firewall-matrix.md)
- [docs/decisions.md](../docs/decisions.md)

Open bring-up questions: **[OPEN-QUESTIONS.md](OPEN-QUESTIONS.md)**.

## Install (fresh NixOS)

**Recommended disk layout** (single internal disk, UEFI):

| Partition | Size | FS | Label | Mount |
|-----------|------|-----|-------|-------|
| ESP | 512 MiB | FAT32 | `BOOT` | `/boot` |
| root | remainder | ext4 | `nixos` | `/` |
| swap (optional) | 4 GiB | swap | `swap` | — only if RAM ≤ 8 GiB |

NixOS generations already give rollback; keep the layout simple (no ZFS/btrfs required for v1). UniFi OS Server wants tens of GB free on `/`.

Example from the installer (`/dev/sda` — check with `lsblk`):

```bash
sudo parted /dev/sda -- mklabel gpt
sudo parted /dev/sda -- mkpart ESP fat32 1MiB 513MiB
sudo parted /dev/sda -- set 1 esp on
sudo parted /dev/sda -- mkpart root ext4 513MiB 100%
sudo mkfs.fat -F 32 -n BOOT /dev/sda1
sudo mkfs.ext4 -L nixos /dev/sda2
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/BOOT /mnt/boot
```

Then either:

1. Minimal `nixos-install` with a tiny config, clone this repo, `nixos-rebuild switch --flake .#optiplex`, or
2. Copy `router/` into `/mnt/etc/nixos` style flake and install with `nixos-install --flake /mnt/path/to/router#optiplex`.

**NICs (already in flake):**

| MAC | Name | Role |
|-----|------|------|
| `34:17:eb:96:84:20` | `wan0` | I217LM → modem |
| `a0:36:9f:33:ae:96` | `lan0` | i350 port 1 → CRS310 trunk |
| `a0:36:9f:33:ae:97` | `spare0` | i350 port 2, forced down |

Confirm port 1 ↔ `ae:96` with a physical cable test after first boot.

**WAN:** DHCP. **SSH:** trusted VLAN (`10.10.20.0/24`) only — add an authorized key before locking yourself out.

## Layout

```
router/
├── flake.nix
├── lib/constants.nix       # VLANs, hosts, ports (sync with docs)
├── hosts/optiplex/
│   ├── configuration.nix   # site knobs (iface names, toggles)
│   └── hardware.nix        # stub — replace from nixos-generate-config
└── modules/
    ├── networking.nix      # WAN + VLAN trunk
    ├── dhcp.nix            # dnsmasq
    ├── dns.nix             # Unbound split-horizon
    ├── firewall.nix        # nftables from firewall-matrix
    ├── vpn.nix             # WireGuard (Stage 6, off by default)
    ├── unifi.nix           # Podman prep for UniFi OS Server
    ├── dnsupdater.nix      # Domeneshop DDNS timer stub
    ├── monitoring.nix      # node_exporter
    └── ssh.nix
```

## Build / deploy (once hardware knobs are set)

```bash
# On a workstation with Nix:
nix build .#nixosConfigurations.optiplex.config.system.build.toplevel

# On the OptiPlex (after install):
nixos-rebuild switch --flake /path/to/net/router#optiplex
```

## UniFi OS Server

Not packaged in the flake. After NixOS is up:

1. Install UniFi OS Server (vendor Podman installer).
2. Open UI on `:11443` from trusted VLAN.
3. Set Inform Host Override to the router IP the AP reaches (often `10.10.10.1`).
4. Adopt U7 Lite; map SSIDs per vlan-plan.
