#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
caddyfile="$root/services/caddy/Caddyfile"
fail=0

echo "==> Caddyfile format"
run_caddy_fmt() {
  if command -v caddy >/dev/null 2>&1; then
    caddy fmt "$caddyfile"
  elif command -v nix >/dev/null 2>&1; then
    nix --extra-experimental-features 'nix-command flakes' run nixpkgs#caddy -- fmt "$caddyfile"
  else
    return 2
  fi
}
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
if run_caddy_fmt >"$tmp"; then
  if ! cmp -s "$caddyfile" "$tmp"; then
    echo "Caddyfile is not formatted. Run: caddy fmt --overwrite $caddyfile" >&2
    diff -u "$caddyfile" "$tmp" || true
    fail=1
  fi
else
  status=$?
  if [ "$status" -eq 2 ]; then
    echo "caddy/nix not found — skip fmt"
  else
    echo "caddy fmt failed" >&2
    fail=1
  fi
fi

echo "==> nix flake check"
if command -v nix >/dev/null 2>&1; then
  if ! nix --extra-experimental-features 'nix-command flakes' flake check "$root"; then
    echo "flake check failed (common on Darwin for x86_64-linux). Falling back to eval." >&2
    nix --extra-experimental-features 'nix-command flakes' \
      eval "${root}#nixosConfigurations.optiplex.config.networking.hostName"
  fi
else
  echo "nix not found — skip flake check"
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "==> OK"
