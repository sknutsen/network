# Hardware procurement (Norway)

Reference BOM for ~60 m² flat. **Chosen:** Dell OptiPlex 9020 MT (on hand). See [decisions.md](../decisions.md).

Prices indicative NOK incl. 25% MVA; check [Prisjakt](https://www.prisjakt.no) before buying.

## Retailers

| Retailer | Good for |
|----------|----------|
| [avXperten.no](https://www.avxperten.no) | MikroTik, Ubiquiti |
| [Senetic.no](https://www.senetic.no) | MikroTik, enterprise |
| [Komplett.no](https://www.komplett.no) | UniFi APs, UPS |
| [Dustin.no](https://www.dustin.no) | MikroTik |
| [Finn.no](https://www.finn.no) | Used desktops for router builds |

## Chosen BOM (9020 MT)

Core networking gear is **procured**. Remaining optional items are out of scope for v1.

| Item | Model | Status | NOK (approx.) |
|------|-------|--------|---------------|
| Router | OptiPlex 9020 MT + Intel i350-T2 | **Acquired** | 0 |
| Switch | MikroTik CRS310-8G+2S+IN | **Acquired** | 0 (~2 200) |
| AP | Ubiquiti U7 Lite | **Acquired** | 0 (~1 200) |
| PoE injector | 802.3af for U7 Lite | **Acquired** | 0 (~300) |
| UPS | APC 700 VA class | **Deferred** — not required for v1 | ~1 000 later |

**v1 procurement complete** for router, NIC, switch, AP, and injector.

## Router: OptiPlex 9020 MT

| Spec | Detail |
|------|--------|
| Onboard NIC | Intel I217LM 1 GbE → WAN |
| CPU | Haswell i5/i7 — AES-NI for WireGuard |
| Expansion | PCIe x16 + x1 — i350-T2 dual-port for trunk (**acquired**) |
| Power | ~25–45 W |

**Cabling:** I217LM → modem; i350 port 1 → CRS310 trunk; i350 port 2 spare.

## Switch: CRS310-8G+2S+IN (acquired)

8× 2.5GbE + 2× 10G SFP+. **No PoE** — U7 Lite powered by owned 802.3af injector (13 W). Port plan: [inventory.md](../inventory.md). Port 2 is 2.5 GbE — matches the AP uplink.

## UPS (deferred)

Not required for the current plan. Procure later for graceful shutdown / power dips; Stage 8 UPS test is optional until then.

## WiFi: Ubiquiti U7 Lite (acquired)

WiFi 7 (802.11be), dual-band 2.4/5 GHz, ~115 m² coverage — sufficient for 60 m². 2.5 GbE uplink on CRS310 port 2 via owned PoE injector. Managed by **UniFi OS Server on the OptiPlex** (not TrueNAS).

## Alternates (not purchased)

| Tier | Example | NOK |
|------|---------|-----|
| Budget router | ThinkCentre M720q + Intel NIC | 1 500–3 000 |
| Fanless router | Topton N100 4-port | 2 000–2 800 |
| Premium router | Protectli VP2420 | 4 500–6 000 |

Norwegian fibre typically ≤1 Gbps — OptiPlex or N100 handles this with headroom.
