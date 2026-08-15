#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Checking router flake evaluates (if nix available)"
if command -v nix >/dev/null 2>&1; then
  nix --extra-experimental-features 'nix-command flakes' \
    eval "${root}/router#nixosConfigurations.optiplex.config.networking.hostName"
else
  echo "nix not found — skip flake eval"
fi

echo "==> OK"
