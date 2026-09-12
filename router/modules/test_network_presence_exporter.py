"""Tests for network-presence-exporter (stdlib unittest)."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location(
    "network_presence_exporter", ROOT / "network-presence-exporter.py"
)
assert SPEC and SPEC.loader
EXP = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXP)

INVENTORY = {
    "macs": {
        "f0:2f:74:dd:e6:48": {"name": "pingu"},
        "cc:28:aa:42:c2:9d": {"name": "truenas"},
    },
    "vlans": [
        {"name": "trusted", "id": 20, "network": "10.10.20.0/24"},
        {"name": "servers", "id": 30, "network": "10.10.30.0/24"},
        {"name": "iot", "id": 40, "network": "10.10.40.0/24"},
    ],
}

LEASES = """\
0 f0:2f:74:dd:e6:48 10.10.20.10 pingu 01:f0:2f:74:dd:e6:48
1710000000 aa:bb:cc:dd:ee:ff 10.10.40.200 * 01:aa:bb:cc:dd:ee:ff
"""

ARP = """\
IP address       HW type     Flags       HW address            Mask     Device
10.10.20.10      0x1         0x2         f0:2f:74:dd:e6:48     *        vlan20
10.10.30.20      0x1         0x2         cc:28:aa:42:c2:9d     *        vlan30
10.10.20.99      0x1         0x0         00:00:00:00:00:00     *        vlan20
10.10.50.5       0x1         0x2         de:ad:be:ef:00:01     *        vlan50
"""


class ParseTests(unittest.TestCase):
    def test_leases_star_hostname(self):
        leases = EXP.parse_leases(LEASES)
        self.assertEqual(len(leases), 2)
        self.assertEqual(leases[0]["hostname"], "pingu")
        self.assertEqual(leases[1]["hostname"], "")
        self.assertEqual(leases[1]["mac"], "aa:bb:cc:dd:ee:ff")

    def test_arp_skips_incomplete(self):
        neighbors = EXP.parse_arp(ARP)
        macs = {n["mac"] for n in neighbors}
        self.assertIn("f0:2f:74:dd:e6:48", macs)
        self.assertNotIn("00:00:00:00:00:00", macs)
        self.assertEqual(len(neighbors), 3)

    def test_vlan_for_ip(self):
        self.assertEqual(
            EXP.vlan_for_ip("10.10.20.10", INVENTORY["vlans"]),
            ("trusted", "20"),
        )
        self.assertEqual(
            EXP.vlan_for_ip("8.8.8.8", INVENTORY["vlans"]),
            ("unknown", ""),
        )

    def test_prom_escape(self):
        self.assertEqual(EXP.prom_escape('a"b\\c'), r"a\"b\\c")


class CollectTests(unittest.TestCase):
    def test_known_unknown_and_inventory(self):
        with tempfile.TemporaryDirectory() as tmp:
            t = Path(tmp)
            (t / "leases").write_text(LEASES, encoding="utf-8")
            (t / "arp").write_text(ARP, encoding="utf-8")
            snap = EXP.collect(t / "leases", t / "arp", INVENTORY)

        pingu = next(x for x in snap["leases"] if x["ip"] == "10.10.20.10")
        self.assertEqual(pingu["known"], "true")
        self.assertEqual(pingu["inventory_name"], "pingu")
        self.assertEqual(pingu["vlan"], "trusted")

        mystery = next(x for x in snap["leases"] if x["ip"] == "10.10.40.200")
        self.assertEqual(mystery["known"], "false")
        self.assertEqual(mystery["vlan"], "iot")

        self.assertIn("aa:bb:cc:dd:ee:ff", snap["unknown_macs"])
        self.assertIn("de:ad:be:ef:00:01", snap["unknown_macs"])
        self.assertNotIn("f0:2f:74:dd:e6:48", snap["unknown_macs"])

        up = {item["name"]: item["up"] for item in snap["inventory_up"]}
        self.assertEqual(up["pingu"], "1")
        self.assertEqual(up["truenas"], "1")

    def test_render_metrics(self):
        with tempfile.TemporaryDirectory() as tmp:
            t = Path(tmp)
            (t / "leases").write_text(LEASES, encoding="utf-8")
            (t / "arp").write_text(ARP, encoding="utf-8")
            snap = EXP.collect(t / "leases", t / "arp", INVENTORY)
        text = EXP.render_metrics(snap)
        self.assertIn("network_dhcp_lease_info{", text)
        self.assertIn('hostname="pingu"', text)
        self.assertIn("network_unknown_devices 2", text)
        self.assertIn('network_inventory_up{mac="cc:28:aa:42:c2:9d",name="truenas"} 1', text)
        self.assertIn("# EOF", text)


if __name__ == "__main__":
    unittest.main()
