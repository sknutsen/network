# Router bring-up — remaining

Resolved first-boot answers live in [`docs/decisions.md`](../docs/decisions.md).
Rationale: [`docs/decision-briefs.md`](../docs/decision-briefs.md). Stage
checklists: [`docs/implementation-stages.md`](../docs/implementation-stages.md).

**For agents:** Do not re-open crossed-off items here. Record new choices in
`decisions.md`, mark the matching brief **Resolved**, and keep this file to
unanswered leftovers only.

## Deferred

1. [ ] **MAC addresses** for remaining dnsmasq reservations. Known hosts are in
       `router/lib/constants.nix` (`macs`) and `router/modules/dhcp.nix`. Still
       unknown: Socrates, Peon, Nintendo Switch. RK1 `end0` MACs are reserved.
