# Router (OptiPlex 9020 MT)

NixOS modules for the homelab edge router. The flake is at the **repo root**
(`nixosConfigurations.optiplex`). Design sources:

- [docs/vlan-plan.md](../docs/vlan-plan.md)
- [docs/firewall-matrix.md](../docs/firewall-matrix.md)
- [docs/decisions.md](../docs/decisions.md)

Remaining first-boot leftovers: **[OPEN-QUESTIONS.md](OPEN-QUESTIONS.md)**. Resolved answers: [docs/decisions.md](../docs/decisions.md).

## Install (nixos-anywhere)

Disk layout is `hosts/optiplex/disko.nix`: GPT, 512 MiB ESP label `BOOT` -> `/boot`, remainder ext4 label `nixos` -> `/`. No ZFS/btrfs for v1. UniFi OS Server wants tens of GB free on `/`. Optional 4 GiB swap only if RAM is 8 GiB or less.

**Firmware:** UEFI, Secure Boot off, SATA AHCI. After install, SSH is accepted only from the trusted VLAN (`10.10.20.0/24`). SSH keys for `zdk` (admin) and `root` are already in `configuration.nix`. Keep a keyboard and monitor attached until that path works.

### 1. Bootstrap SSH on the OptiPlex

nixos-anywhere needs Linux + SSH as root (or passwordless sudo). A Windows install cannot kexec.

- **Existing Linux:** enable root SSH. Leave about 2 GiB RAM free for kexec.
- **Blank disk:** boot a NixOS installer ISO in UEFI mode. On the live system start `sshd`, set a temporary root password, and note the IPv4 (`ip -br addr`). Identify the target disk (`lsblk -d -o NAME,SIZE,MODEL` and `/dev/disk/by-id/`).

Give the live system internet on **one** NIC (I217LM into the current LAN is fine). Do not connect i350 port 1 to the production switch until cutover: the installed system will serve `10.10.x.0/24` DHCP on tagged VLANs.

Set `disko.devices.disk.main.device` in `hosts/optiplex/configuration.nix` to that disk (`/dev/sda` is the default; prefer a `/dev/disk/by-id/...` path).

### 2. Run nixos-anywhere from a workstation

From the **repo root**. This Mac cannot build `x86_64-linux` locally, so pass `--build-on remote` (the OptiPlex builds the closure). Pingu (NixOS, same architecture) can build locally and omit that flag.

Git flakes ignore untracked files. Stage the tree, or pass `--flake "path:$PWD#optiplex"`. Quote flake URIs in zsh (`'.#optiplex'`); otherwise `#` is a glob and you get `no matches found`.

```bash
cd /path/to/net

nix run github:nix-community/nixos-anywhere -- \
  --flake '.#optiplex' \
  --target-host root@INSTALLER_IP \
  --build-on remote \
  --generate-hardware-config nixos-generate-config ./router/hosts/optiplex/hardware-configuration.nix \
  --phases kexec,disko,install
```

If you are already on a NixOS installer, nixos-anywhere skips kexec. Leave reboot out of `--phases` so you can set a console root password with `nixos-enter` on `/mnt` before the machine becomes the gateway. Then reboot from the live session.

The SSH host key changes. After reboot the installer DHCP address is gone.

If the remote build runs out of memory (8 GiB OptiPlex building a full closure), run nixos-anywhere from Pingu instead, or add RAM.

**NICs (already in flake):**

| MAC | Name | Role |
|-----|------|------|
| `34:17:eb:96:84:20` | `wan0` | I217LM -> modem |
| `a0:36:9f:33:ae:96` | `lan0` | i350 port 1 -> CRS310 trunk |
| `a0:36:9f:33:ae:97` | `spare0` | i350 port 2, forced down |

Confirm port 1 <-> `ae:96` with a physical cable test after first boot.

**WAN:** DHCP. **SSH:** trusted VLAN only.

## Layout

```
router/
├── lib/constants.nix       # VLANs, hosts, ports (sync with docs)
├── hosts/optiplex/
│   ├── configuration.nix   # site knobs (iface names, disk, toggles)
│   ├── disko.nix           # GPT ESP + ext4
│   ├── hardware.nix        # bootloader + NIC kernel modules
│   └── hardware-configuration.nix  # generated at install
└── modules/
    ├── networking.nix      # WAN + VLAN trunk
    ├── dhcp.nix            # dnsmasq (IoT DNS follows enableBlocky)
    ├── dns.nix             # Unbound split-horizon
    ├── firewall.nix        # nftables from firewall-matrix
    ├── caddy.nix           # Caddy; Caddyfile in services/caddy/
    ├── vpn.nix             # WireGuard (Stage 6, off by default)
    ├── unifi.nix           # UniFi OS Server (rootless Podman + systemd)
    ├── dnsupdater.nix      # Domeneshop DDNS timer stub
    ├── monitoring.nix      # node_exporter
    └── ssh.nix
```

**Stage flags** in `hosts/optiplex/configuration.nix`: `enableBlocky` stays **false** until Blocky answers at `10.10.30.21`. `enableWanCaddy` stays **false** until Stage 7. Lab TLS is DNS-01 (Domeneshop plugin + sops) — see `caddy.nix`. Caddyfile: `services/caddy/Caddyfile`.

## Build / deploy (once hardware knobs are set)

```bash
# From repo root (Linux builder or on janus):
nix build '.#nixosConfigurations.optiplex.config.system.build.toplevel'

# On janus (after install):
nixos-rebuild switch --flake /path/to/net#optiplex

# From a Linux workstation (SSH from trusted VLAN):
nixos-rebuild switch --flake '.#optiplex' --target-host root@10.10.20.1
```

## UniFi OS Server

**Functional** on janus. Vendor linux-x64 binaries (impure) plus flake units in
`unifi.nix`: rootless Podman as `uosserver`, systemd `uosserver.service`. Not a
nixpkgs service — the installer cannot write `/etc/systemd/system` (Nix store
symlink). `enableUnifi` is on. `nix-ld` is required for the vendor ELF.

**Access:** UI `:11443` from trusted / servers / mgmt (+ wg0). Inform `:8080`.
Until the Caddy vhost is uncommented, browse `https://10.10.10.1:11443`.
`unifi.lab.zdk.no` already points at Caddy (`.30.1`). Headscale (Stage 6)
listens on **`127.0.0.1:8081`** so it does not collide with Inform.

**Inform Host Override:** **`10.10.10.1`**. The AP's native VLAN is 10, so it
cannot use `10.10.30.1` (Caddy). Caddy LAN INPUT is trusted + servers (+ VPN),
not mgmt.

**Data:** `/var/lib/uosserver` (service), `/home/uosserver` (rootless storage),
`/var/lib/unifi-os-server` (vendor). Runs **only** on this router — do not
resurrect the TrueNAS Network Application. The updater unit stays disabled so
`nixos-rebuild` does not fail when the binary exits 1.

Stage 3 leftover: adopt U7 Lite; map SSIDs per vlan-plan (`Hai-Fi Wai-Fi` /
`(IoT)` / `(Guest)`).

**If binaries are missing** (reinstall): run the vendor installer as root
(`sudo ./linux-x64-*-x64`), then `systemctl start uosserver`.
