"""Prometheus exporter for dnsmasq leases and ARP neighbors.

Inventory JSON (from router/lib/constants.nix) marks known MACs. Bind
:9101 on janus; scrape from the servers VLAN only.
"""

from __future__ import annotations

import argparse
import ipaddress
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

LEASES_DEFAULT = "/var/lib/dnsmasq/dnsmasq.leases"
ARP_DEFAULT = "/proc/net/arp"
INVENTORY_DEFAULT = "/etc/network-presence/inventory.json"


def normalize_mac(mac: str) -> str:
    return mac.strip().lower()


def prom_escape(value: str) -> str:
    return (
        value.replace("\\", r"\\")
        .replace("\n", " ")
        .replace("\r", " ")
        .replace('"', r"\"")
    )


def load_inventory(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"macs": {}, "vlans": []}
    data = json.loads(path.read_text(encoding="utf-8"))
    macs = {normalize_mac(k): v for k, v in data.get("macs", {}).items()}
    return {"macs": macs, "vlans": data.get("vlans", [])}


def vlan_for_ip(ip: str, vlans: list[dict[str, Any]]) -> tuple[str, str]:
    try:
        addr = ipaddress.ip_address(ip)
    except ValueError:
        return "unknown", ""
    for vlan in vlans:
        network = vlan.get("network")
        if not network:
            continue
        try:
            if addr in ipaddress.ip_network(network, strict=False):
                return str(vlan.get("name", "unknown")), str(vlan.get("id", ""))
        except ValueError:
            continue
    return "unknown", ""


def parse_leases(text: str) -> list[dict[str, str]]:
    """dnsmasq lease file: expiry mac ip hostname clientid [iaid]."""
    leases = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 4:
            continue
        expiry, mac, ip, hostname = parts[0], parts[1], parts[2], parts[3]
        if hostname in {"*", ""}:
            hostname = ""
        leases.append(
            {
                "expiry": expiry,
                "mac": normalize_mac(mac),
                "ip": ip,
                "hostname": hostname,
            }
        )
    return leases


def parse_arp(text: str) -> list[dict[str, str]]:
    """Kernel /proc/net/arp. Skip incomplete entries."""
    neighbors = []
    for i, raw in enumerate(text.splitlines()):
        if i == 0:
            continue
        parts = raw.split()
        if len(parts) < 6:
            continue
        ip, _hwtype, flags, mac, _mask, device = parts[:6]
        mac = normalize_mac(mac)
        if mac in {"00:00:00:00:00:00", "<incomplete>"}:
            continue
        if flags in {"0x0", "0x00"}:
            continue
        neighbors.append({"ip": ip, "mac": mac, "device": device, "flags": flags})
    return neighbors


def lookup_name(mac: str, inventory: dict[str, Any]) -> str:
    entry = inventory.get("macs", {}).get(mac)
    if not entry:
        return ""
    return str(entry.get("name", ""))


def collect(
    leases_path: Path, arp_path: Path, inventory: dict[str, Any]
) -> dict[str, Any]:
    leases_text = (
        leases_path.read_text(encoding="utf-8") if leases_path.is_file() else ""
    )
    arp_text = arp_path.read_text(encoding="utf-8") if arp_path.is_file() else ""
    leases = parse_leases(leases_text)
    neighbors = parse_arp(arp_text)
    vlans = inventory.get("vlans", [])

    for lease in leases:
        vlan, vlan_id = vlan_for_ip(lease["ip"], vlans)
        name = lookup_name(lease["mac"], inventory)
        lease["vlan"] = vlan
        lease["vlan_id"] = vlan_id
        lease["inventory_name"] = name
        lease["known"] = "true" if name else "false"

    for neigh in neighbors:
        vlan, vlan_id = vlan_for_ip(neigh["ip"], vlans)
        name = lookup_name(neigh["mac"], inventory)
        neigh["vlan"] = vlan
        neigh["vlan_id"] = vlan_id
        neigh["inventory_name"] = name
        neigh["known"] = "true" if name else "false"

    seen_macs = {item["mac"] for item in leases} | {item["mac"] for item in neighbors}
    unknown = sorted(
        {item["mac"] for item in leases + neighbors if item["known"] == "false"}
    )
    inventory_up = []
    for mac, entry in sorted(inventory.get("macs", {}).items()):
        inventory_up.append(
            {
                "mac": mac,
                "name": str(entry.get("name", "")),
                "up": "1" if mac in seen_macs else "0",
            }
        )

    return {
        "leases": leases,
        "neighbors": neighbors,
        "unknown_macs": unknown,
        "inventory_up": inventory_up,
    }


def _labels(**fields: str) -> str:
    parts = [f'{key}="{prom_escape(value)}"' for key, value in fields.items()]
    return "{" + ",".join(parts) + "}"


def render_metrics(snapshot: dict[str, Any]) -> str:
    lines = [
        "# HELP network_dhcp_lease_info Active dnsmasq DHCP lease (1 = present).",
        "# TYPE network_dhcp_lease_info gauge",
    ]
    for lease in snapshot["leases"]:
        lines.append(
            "network_dhcp_lease_info"
            + _labels(
                mac=lease["mac"],
                ip=lease["ip"],
                hostname=lease["hostname"],
                vlan=lease["vlan"],
                vlan_id=lease["vlan_id"],
                known=lease["known"],
                inventory_name=lease["inventory_name"],
            )
            + " 1"
        )

    lines += [
        "# HELP network_dhcp_lease_expiry_timestamp Unix expiry of a DHCP lease; 0 = infinite.",
        "# TYPE network_dhcp_lease_expiry_timestamp gauge",
    ]
    for lease in snapshot["leases"]:
        lines.append(
            "network_dhcp_lease_expiry_timestamp"
            + _labels(mac=lease["mac"], ip=lease["ip"])
            + f" {lease['expiry']}"
        )

    lines += [
        "# HELP network_neighbor_info Kernel IPv4 neighbor (ARP) entry (1 = present).",
        "# TYPE network_neighbor_info gauge",
    ]
    for neigh in snapshot["neighbors"]:
        lines.append(
            "network_neighbor_info"
            + _labels(
                mac=neigh["mac"],
                ip=neigh["ip"],
                device=neigh["device"],
                vlan=neigh["vlan"],
                vlan_id=neigh["vlan_id"],
                known=neigh["known"],
                inventory_name=neigh["inventory_name"],
            )
            + " 1"
        )

    counts: dict[tuple[str, str], int] = {}
    for lease in snapshot["leases"]:
        key = (lease["vlan"], lease["known"])
        counts[key] = counts.get(key, 0) + 1
    lines += [
        "# HELP network_dhcp_leases Count of active DHCP leases by VLAN and inventory match.",
        "# TYPE network_dhcp_leases gauge",
    ]
    for (vlan, known), n in sorted(counts.items()):
        lines.append(
            f'network_dhcp_leases{{vlan="{prom_escape(vlan)}",known="{known}"}} {n}'
        )

    lines += [
        "# HELP network_unknown_devices Unique MACs seen in leases or ARP that are not in inventory.",
        "# TYPE network_unknown_devices gauge",
        f"network_unknown_devices {len(snapshot['unknown_macs'])}",
        "# HELP network_inventory_up 1 if an inventory MAC is present in leases or ARP.",
        "# TYPE network_inventory_up gauge",
    ]
    for item in snapshot["inventory_up"]:
        lines.append(
            "network_inventory_up"
            + _labels(mac=item["mac"], name=item["name"])
            + f" {item['up']}"
        )

    lines.append("# EOF")
    return "\n".join(lines) + "\n"


class MetricsHandler(BaseHTTPRequestHandler):
    server_version = "network-presence-exporter/1.0"

    def log_message(self, fmt: str, *args: Any) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def do_GET(self) -> None:  # noqa: N802
        if self.path.split("?", 1)[0] == "/healthz":
            body = b"ok\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path.split("?", 1)[0] != "/metrics":
            self.send_error(404, "not found")
            return
        snapshot = collect(
            Path(self.server.leases_path),  # type: ignore[attr-defined]
            Path(self.server.arp_path),  # type: ignore[attr-defined]
            self.server.inventory,  # type: ignore[attr-defined]
        )
        body = render_metrics(snapshot).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def serve(listen: str, leases: Path, arp: Path, inventory_path: Path) -> None:
    host, _, port_s = listen.rpartition(":")
    if not host:
        host = "0.0.0.0"
    inventory = load_inventory(inventory_path)
    httpd = ThreadingHTTPServer((host, int(port_s)), MetricsHandler)
    httpd.leases_path = str(leases)  # type: ignore[attr-defined]
    httpd.arp_path = str(arp)  # type: ignore[attr-defined]
    httpd.inventory = inventory  # type: ignore[attr-defined]
    sys.stderr.write(
        f"network-presence-exporter listening on {host}:{port_s} "
        f"leases={leases} arp={arp} inventory={inventory_path}\n"
    )
    httpd.serve_forever()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--listen",
        default=os.environ.get("NETWORK_PRESENCE_LISTEN", "0.0.0.0:9101"),
        help="host:port (default 0.0.0.0:9101)",
    )
    parser.add_argument(
        "--leases",
        default=os.environ.get("NETWORK_PRESENCE_LEASES", LEASES_DEFAULT),
    )
    parser.add_argument(
        "--arp",
        default=os.environ.get("NETWORK_PRESENCE_ARP", ARP_DEFAULT),
    )
    parser.add_argument(
        "--inventory",
        default=os.environ.get("NETWORK_PRESENCE_INVENTORY", INVENTORY_DEFAULT),
    )
    args = parser.parse_args(argv)
    serve(args.listen, Path(args.leases), Path(args.arp), Path(args.inventory))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
