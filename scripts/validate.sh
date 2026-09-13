#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
caddyfile="$root/services/caddy/Caddyfile"
fail=0
nix_cmd=(nix --extra-experimental-features "nix-command flakes")

# GitHub Actions sets CI=true. Local runs may skip missing tools; CI must not.
skip_or_fail() {
  if [ -n "${CI:-}" ]; then
    echo "$1 (required in CI)" >&2
    fail=1
  else
    echo "$1 — skip"
  fi
}

echo "==> Caddyfile format"
run_caddy_fmt() {
  if command -v caddy >/dev/null 2>&1; then
    caddy fmt "$caddyfile"
  elif command -v nix >/dev/null 2>&1; then
    "${nix_cmd[@]}" run nixpkgs#caddy -- fmt "$caddyfile"
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
    skip_or_fail "caddy/nix not found"
  else
    echo "caddy fmt failed" >&2
    fail=1
  fi
fi

echo "==> network-presence exporter tests"
if command -v python3 >/dev/null 2>&1; then
  if ! python3 -m unittest discover -s "$root/router/modules" -p 'test_*.py' -q; then
    echo "network-presence exporter tests failed" >&2
    fail=1
  fi
else
  skip_or_fail "python3 not found"
fi

echo "==> nix flake check"
if command -v nix >/dev/null 2>&1; then
  if ! "${nix_cmd[@]}" flake check --all-systems "$root"; then
    if [ -n "${CI:-}" ]; then
      echo "flake check failed" >&2
      fail=1
    else
      echo "flake check failed (common on Darwin for x86_64-linux). Falling back to eval." >&2
    fi
  fi
  echo "==> router flake eval"
  if ! "${nix_cmd[@]}" eval "${root}#nixosConfigurations.optiplex.config.networking.hostName"; then
    echo "router flake eval failed" >&2
    fail=1
  fi
else
  skip_or_fail "nix not found"
fi

echo "==> nodes flake eval"
if command -v nix >/dev/null 2>&1; then
  if ! "${nix_cmd[@]}" eval "path:${root}/nodes#nixosConfigurations.nordri.config.networking.hostName"; then
    echo "nodes flake eval failed" >&2
    fail=1
  fi
else
  skip_or_fail "nix not found"
fi

echo "==> kustomize build k8s"
kustomize_build() {
  local overlay="$1"
  if command -v kubectl >/dev/null 2>&1; then
    kubectl kustomize "$overlay"
  elif command -v kustomize >/dev/null 2>&1; then
    kustomize build "$overlay"
  elif command -v nix >/dev/null 2>&1; then
    "${nix_cmd[@]}" run nixpkgs#kustomize -- build "$overlay"
  else
    return 2
  fi
}
for overlay in \
  "$root/k8s/clusters/homelab/infra/core" \
  "$root/k8s/clusters/homelab/infra/config" \
  "$root/k8s/clusters/homelab/apps"; do
  echo "    $overlay"
  if out="$(kustomize_build "$overlay" 2>&1)"; then
    :
  else
    status=$?
    if [ "$status" -eq 2 ]; then
      skip_or_fail "kubectl/kustomize/nix not found"
      break
    fi
    echo "$out" >&2
    echo "kustomize build failed: $overlay" >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "==> OK"
