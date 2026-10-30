#!/usr/bin/env bash
# ShadowStrike OS SBOM generator.
# Writes a dated, local, SBOM-style inventory under sbom/ next to this script:
#   sbom/sbom-YYYYmmdd-HHMMSS/
#     dpkg-packages.txt    every dpkg package with its version
#     pipx-list.txt        pipx environments, or a note that pipx is absent
#     tool-manifest.csv    a copy of the curated manifest as provisioned from
#     SUMMARY.txt          counts and generation details
# Read-only apart from its output directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$SCRIPT_DIR/sbom/sbom-$STAMP"

mkdir -p "$OUT_DIR"

echo "ShadowStrike OS SBOM"
echo "Output: $OUT_DIR"

# dpkg inventory (Debian and Kali base).
if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' \
    | sort > "$OUT_DIR/dpkg-packages.txt"
else
  echo "dpkg-query not available on this system." > "$OUT_DIR/dpkg-packages.txt"
fi

# pipx inventory (pipx rows of the manifest land here).
if command -v pipx >/dev/null 2>&1; then
  pipx list --include-injected > "$OUT_DIR/pipx-list.txt" 2>&1 || pipx list > "$OUT_DIR/pipx-list.txt" 2>&1
else
  echo "pipx not installed." > "$OUT_DIR/pipx-list.txt"
fi

# Go tool inventory, when a Go workspace exists.
if [[ -d "$HOME/go/bin" ]]; then
  ls -1 "$HOME/go/bin" | sort > "$OUT_DIR/go-bin.txt"
fi

# The manifest as the statement of intent.
if [[ -f "$SCRIPT_DIR/tool-manifest.csv" ]]; then
  cp -a "$SCRIPT_DIR/tool-manifest.csv" "$OUT_DIR/tool-manifest.csv"
fi

DPKG_COUNT=0
[[ -f "$OUT_DIR/dpkg-packages.txt" ]] && DPKG_COUNT="$(wc -l < "$OUT_DIR/dpkg-packages.txt" | tr -d ' ')"
MANIFEST_COUNT=0
[[ -f "$OUT_DIR/tool-manifest.csv" ]] && MANIFEST_COUNT="$(($(wc -l < "$OUT_DIR/tool-manifest.csv" | tr -d ' ') - 1))"

cat > "$OUT_DIR/SUMMARY.txt" <<EOF
ShadowStrike OS SBOM summary
Operator: Epsilon0xCell
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Host: $(hostname 2>/dev/null || echo unknown)
Kernel: $(uname -r 2>/dev/null || echo unknown)
Architecture: $(uname -m 2>/dev/null || echo unknown)
dpkg packages recorded: $DPKG_COUNT
Manifest rows recorded: $MANIFEST_COUNT
Files: dpkg-packages.txt, pipx-list.txt, tool-manifest.csv, go-bin.txt (when a Go workspace exists)
EOF

echo "dpkg packages: $DPKG_COUNT"
echo "Manifest rows: $MANIFEST_COUNT"
echo "Wrote: $OUT_DIR/SUMMARY.txt"
