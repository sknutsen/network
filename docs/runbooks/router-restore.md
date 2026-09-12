# Janus restore

Rebuild or replace the OptiPlex edge router. Install details:
[router/README.md](../../router/README.md).

SSH after cutover is **trusted VLAN only** (`10.10.20.0/24`). Keep a console
until that path works.

## What the flake does not restore

| Path | Why it matters |
| ---- | -------------- |
| `/var/lib/sops-nix/key.txt` | Janus age identity. Caddy and DNSUpdater Domeneshop env (and WG) will not decrypt without it. |
| `/var/lib/uosserver`, `/home/uosserver`, `/var/lib/unifi-os-server` | UniFi OS Server state (sites, Inform, AP adoption). |
| `/var/lib/caddy` | Issued certs. DNS-01 can re-issue; expect a delay. |

Backup the age key **offline** (same class as `$HOME/keys/homelab-cluster.age`,
but this file is the **janus** recipient, not the RK1/Flux cluster key).
Recipients for `secrets/router.yaml`: janus + pingu + remorse — not the
cluster key.

## Reinstall (disk loss)

1. Confirm WAN/LAN MACs still match `configuration.nix` (`wan0` I217LM,
   `lan0` i350 port 1). Disk knob is `disko.devices.disk.main.device`
   (`/dev/sda` today — prefer a `/dev/disk/by-id/…` path if you change it).
2. From the repo root, run nixos-anywhere per [router/README.md](../../router/README.md).
   This Mac needs `--build-on remote`. Quote `'.#optiplex'`.
3. Leave reboot out of `--phases` on a blank box so you can set a console
   root password with `nixos-enter` if SSH keys are not enough.
4. **Before** the first `nixos-rebuild` that needs secrets, restore:

   ```bash
   sudo mkdir -p /var/lib/sops-nix
   sudo cp janus.age /var/lib/sops-nix/key.txt
   sudo chmod 600 /var/lib/sops-nix/key.txt
   sudo chown root:root /var/lib/sops-nix/key.txt
   ```

   If the janus key is gone, `age-keygen` a new one, add the public key to
   `secrets/.sops.yaml`, and `sops updatekeys secrets/router.yaml`.
5. Switch:

   ```bash
   # on janus
   nixos-rebuild switch --flake /path/to/net#optiplex

   # from a Linux builder on trusted
   nixos-rebuild switch --flake '.#optiplex' --target-host root@10.10.20.1
   ```

6. Restore UniFi data **or** reinstall vendor binaries
   (`sudo ./linux-x64-*-x64`) and `systemctl start uosserver`, then
   re-adopt the U7 Lite and Flex Minis. Inform Host Override stays
   **`10.10.10.1`** — not Caddy on `10.10.30.1`.
7. Smoke: WAN NAT, VLAN DHCP, `dig @10.10.20.1 janus.lab.zdk.no`,
   `curl -I https://auth.lab.zdk.no`, UniFi Inform from the AP.

Do not `nixos-anywhere` a **running** janus the way you would an installer.
That path is for a blank or already-abandoned disk.

## Config-only (disk intact)

```bash
nixos-rebuild switch --flake '.#optiplex' --target-host root@10.10.20.1
```

If sops fails: check `key.txt` mode `600`, that the file is the janus
identity listed in `secrets/.sops.yaml`, and
`systemctl status sops-install-secrets`.

## Do not

- Point Inform at `10.10.30.1`.
- Copy the **cluster** age key onto janus (RK1s + Flux only).
- Enable `enableWanCaddy` as part of a restore. That is Stage 7.
- Start compose Authelia / Forgejo on TrueNAS to “replace” Caddy. They
  collide with the Apps.
