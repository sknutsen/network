# Router bring-up — remaining

Resolved first-boot answers live in [`docs/decisions.md`](../docs/decisions.md).
Rationale: [`docs/decision-briefs.md`](../docs/decision-briefs.md). Stage
checklists: [`docs/implementation-stages.md`](../docs/implementation-stages.md).

**For agents:** Do not re-open crossed-off items here. Record new choices in
`decisions.md`, mark the matching brief **Resolved**, and keep this file to
unanswered leftovers only.

## Deferred

1. [ ] **MAC addresses** for remaining dnsmasq reservations. Known hosts
   are in `router/lib/constants.nix` (`macs`) and `router/modules/dhcp.nix`.
   Still unknown: Turing Pi BMC, RK1s (nordri–vestri), Socrates, Peon,
   Samsung TV, Rusken, Switch, Odyssey, Chromecast. Do not block Stage 2.

## Operational (not design — already on Stage 1–2 checklists)

- Confirm i350 port 1 ↔ `lan0` after first boot (`ethtool -p lan0`).
- Bridge the OBOS Nett modem at router cutover.
