# Forgejo (`code.zdk.no`)

Self-hosted Git forge on TrueNAS Docker. Deployed via `services/truenas/docker-compose.yml`.

## Configuration

| Setting | Value |
|---------|-------|
| Public URL | `https://code.zdk.no` (Stage 7) |
| ROOT_URL | `https://code.lab.zdk.no` until Stage 7, then `https://code.zdk.no` |
| Data | `/mnt/tank/services/forgejo/data` |
| Config | `/mnt/tank/services/forgejo/config` |

## Git transport

- **WAN:** HTTPS only (`git clone https://code.zdk.no/user/repo.git`)
- **WAN SSH:** disabled — no WAN INPUT for `:22`
- **Internal/VPN:** SSH optional via WireGuard or trusted VLAN (container SSH on port 2222 if enabled)

## Stage 7 checklist

1. Disable open registration in Forgejo admin
2. Create admin account
3. Confirm router has **no WAN :22** forward
4. Include `tank/services/forgejo` in NAS backup snapshots
