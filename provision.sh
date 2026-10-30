#!/usr/bin/env bash
# ShadowStrike OS provisioning.
# Run INSIDE a fresh OrbStack Kali machine (ARM64). Idempotent: safe to re-run.
# Usage:
#   ./provision.sh            provision this machine
#   ./provision.sh --dry-run  print every action, change nothing
#
# Root is never assumed. Privileged steps go through sudo, and every sudo
# call is printed (in dry-run mode it is printed and not executed).
set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
elif [[ $# -gt 0 ]]; then
  echo "usage: $0 [--dry-run]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/tool-manifest.csv"
DOTFILES="$SCRIPT_DIR/dotfiles"
ASSETS="$SCRIPT_DIR/assets"
WORK_ROOT="$HOME/shadowstrike"
BACKUP_ROOT="$HOME/.shadowstrike-backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '%s\n' "$*"; }
act() { say "ACTION: $*"; }

# run_cmd prints the command in dry-run mode and executes it otherwise.
run_cmd() {
  if [[ $DRY_RUN -eq 1 ]]; then
    say "DRY-RUN: $*"
  else
    act "$*"
    "$@"
  fi
}

# sudo_cmd is the only path to privilege. In dry-run mode it prints the full
# sudo invocation and does nothing, so a dry run lists every root action.
sudo_cmd() {
  if [[ $DRY_RUN -eq 1 ]]; then
    say "DRY-RUN (sudo): sudo $*"
  else
    act "sudo $*"
    sudo "$@"
  fi
}

make_dir() {
  run_cmd mkdir -p "$1"
}

# deploy_file SRC DEST: backs up an existing different DEST into the
# timestamped backup folder before replacing it. Skips identical files.
deploy_file() {
  local src="$1" dest="$2"
  if [[ ! -f "$src" ]]; then
    say "SKIP (missing source): $src"
    return 0
  fi
  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    say "OK (unchanged): $dest"
    return 0
  fi
  if [[ -f "$dest" ]]; then
    local backup_dir="$BACKUP_ROOT/$STAMP"
    run_cmd mkdir -p "$backup_dir"
    run_cmd cp -a "$dest" "$backup_dir/$(basename "$dest")"
    say "BACKUP: $dest -> $backup_dir/$(basename "$dest")"
  fi
  run_cmd mkdir -p "$(dirname "$dest")"
  run_cmd cp -a "$src" "$dest"
  say "DEPLOY: $src -> $dest"
}

say "ShadowStrike OS provisioning"
say "Operator: Epsilon0xCell"
say "Mode: $([[ $DRY_RUN -eq 1 ]] && echo dry-run || echo live)"
say "Home: $HOME"
say ""

# --- 1. Directory layout ---------------------------------------------------
say "== Directory layout =="
for d in \
  "$WORK_ROOT" \
  "$WORK_ROOT/engagements" \
  "$WORK_ROOT/loot" \
  "$WORK_ROOT/notes" \
  "$WORK_ROOT/reports" \
  "$WORK_ROOT/wordlists" \
  "$WORK_ROOT/tools" \
  "$WORK_ROOT/bin" \
  "$WORK_ROOT/sbom" \
  "$HOME/.config/fastfetch" \
  "$HOME/Pictures/shadowstrike" \
  "$BACKUP_ROOT"; do
  make_dir "$d"
done
say ""

# --- 2. Curated apt baseline ------------------------------------------------
say "== Apt baseline (manifest rows marked apt) =="
if [[ -f "$MANIFEST" ]]; then
  mapfile -t APT_PKGS < <(awk -F',' 'NR > 1 && $3 == "apt" { print $1 }' "$MANIFEST")
  if [[ ${#APT_PKGS[@]} -gt 0 ]]; then
    say "Packages: ${APT_PKGS[*]}"
    sudo_cmd apt-get update
    sudo_cmd apt-get install -y "${APT_PKGS[@]}"
  else
    say "No apt rows found in manifest."
  fi
else
  say "SKIP: manifest not found at $MANIFEST"
fi
say ""

# --- 3. Dotfiles -------------------------------------------------------------
say "== Dotfiles =="
deploy_file "$DOTFILES/.zshrc" "$HOME/.zshrc"
deploy_file "$DOTFILES/tmux.conf" "$HOME/.tmux.conf"
deploy_file "$DOTFILES/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
deploy_file "$DOTFILES/fastfetch/logo.txt" "$HOME/.config/fastfetch/logo.txt"
deploy_file "$DOTFILES/motd.txt" "$WORK_ROOT/motd.txt"
say ""

# --- 4. MOTD -----------------------------------------------------------------
say "== MOTD =="
say "MOTD is deployed to $WORK_ROOT/motd.txt and printed by .zshrc on"
say "interactive shells. fastfetch runs after it when fastfetch is installed."
say ""

# --- 5. Wallpaper note --------------------------------------------------------
say "== Wallpaper =="
if [[ -f "$ASSETS/org-logo-globe-suit.jpg" ]]; then
  run_cmd cp -a "$ASSETS/org-logo-globe-suit.jpg" "$HOME/Pictures/shadowstrike/org-logo-globe-suit.jpg"
fi
WALLPAPER_NOTE="$WORK_ROOT/WALLPAPER.txt"
if [[ $DRY_RUN -eq 1 ]]; then
  say "DRY-RUN: write wallpaper note to $WALLPAPER_NOTE"
else
  cat > "$WALLPAPER_NOTE" <<'EOF'
ShadowStrike OS wallpaper and lock screen
Source image: ~/Pictures/shadowstrike/org-logo-globe-suit.jpg
Also kept in this repo under assets/org-logo-globe-suit.jpg

Set it, centred, on a black (#050505) background. Do not stretch it.
Static use of the logo is never recoloured. Silver is the mark.

Desktop session hints:
  XFCE:  xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s ~/Pictures/shadowstrike/org-logo-globe-suit.jpg
  GNOME: gsettings set org.gnome.desktop.background picture-uri-dark file:///home/OPERATOR/Pictures/shadowstrike/org-logo-globe-suit.jpg
Replace OPERATOR with the machine user name before running the GNOME line.
EOF
  say "WROTE: $WALLPAPER_NOTE"
fi
say ""

# --- 6. User services ---------------------------------------------------------
say "== User services =="
SERVICE_DIR="$HOME/.config/systemd/user"
make_dir "$SERVICE_DIR"
if [[ $DRY_RUN -eq 1 ]]; then
  say "DRY-RUN: write $SERVICE_DIR/shadowstrike-sbom.service and .timer (weekly SBOM)"
  say "DRY-RUN: systemctl --user daemon-reload; systemctl --user enable --now shadowstrike-sbom.timer (only if a user systemd manager is running)"
else
  cat > "$SERVICE_DIR/shadowstrike-sbom.service" <<EOF
[Unit]
Description=ShadowStrike OS SBOM generation

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/sbom.sh
EOF
  cat > "$SERVICE_DIR/shadowstrike-sbom.timer" <<'EOF'
[Unit]
Description=Weekly ShadowStrike OS SBOM

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF
  if command -v systemctl >/dev/null 2>&1 && systemctl --user is-system-running >/dev/null 2>&1; then
    systemctl --user daemon-reload || true
    systemctl --user enable --now shadowstrike-sbom.timer || true
    say "ENABLED: shadowstrike-sbom.timer"
  else
    say "NOTE: no running user systemd manager here; timer files installed but not enabled."
  fi
fi
say ""

# --- 7. Kernel parity audit ----------------------------------------------------
say "== Kernel parity audit =="
AUDIT=""
for candidate in \
  "$SCRIPT_DIR/kernel-parity/audit.sh" \
  "$SCRIPT_DIR/../kernel-parity/audit.sh"; do
  if [[ -f "$candidate" ]]; then
    AUDIT="$candidate"
    break
  fi
done
if [[ -n "$AUDIT" ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    say "DRY-RUN: bash $AUDIT"
  else
    act "bash $AUDIT"
    bash "$AUDIT" || say "NOTE: audit exited non-zero; read its summary before proceeding."
  fi
else
  say "SKIP: kernel-parity/audit.sh not present alongside this folder."
fi
say ""
say "Provisioning complete (mode: $([[ $DRY_RUN -eq 1 ]] && echo dry-run, nothing changed || echo live))."
say "Next: install the manual rows of tool-manifest.csv, then run ./sbom.sh."
