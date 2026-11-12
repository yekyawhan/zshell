#!/bin/bash
# sudo helper — works interactively, or non-interactively when SUDO_PASSWORD is set
if [[ -n "${SUDO_PASSWORD:-}" ]]; then
  sdo() { printf '%s\n' "$SUDO_PASSWORD" | sudo -S "$@" 2>/dev/null || sudo "$@"; }
else
  sdo() { sudo "$@"; }
fi

# Style the default gnome-terminal profile: Catppuccin Mocha + Nerd Font +
# padding/opacity. Idempotent; safe to re-run.
set -u
export DISPLAY=:0 XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" DBUS_SESSION_BUS_ADDRESS=unix:path=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus
P=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
BASE="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$P/"
echo "profile: $P"

set_() { gsettings set "$BASE" "$1" "$2" 2>/dev/null || echo "  (skip $1)"; }

set_ visible-name "'Catppuccin Mocha'"
set_ use-system-font false
FONT=$(fc-list : family | tr ',' '\n' | grep -E "^ ?MesloLG(M|LDZ) Nerd Font( Mono)?$" | sort -u | head -1 | sed 's/^ //')
FONT=${FONT:-"MesloLGL Nerd Font"}
echo "font: $FONT"
set_ font "'$FONT 12'"
set_ background-color "'#1E1E2E'"
set_ foreground-color "'#CDD6F4'"
set_ bold-color-same-as-fg true
set_ bold-is-bright true
set_ cursor-colors-set true
set_ cursor-background-color "'#F5E0DC'"
set_ cursor-foreground-color "'#1E1E2E'"
set_ cursor-shape ibeam
set_ cursor-blink-mode on
# Catppuccin Mocha 16-colour palette
set_ palette "['#45475A', '#F38BA8', '#A6E3A1', '#F9E2AF', '#89B4FA', '#F5C2E7', '#94E2D5', '#BAC2DE', '#585B70', '#F38BA8', '#A6E3A1', '#F9E2AF', '#89B4FA', '#F5C2E7', '#94E2D5', '#A6ADC8']"
set_ use-transparent-background true
set_ background-transparency-percent 8
set_ scrollback-unlimited true
set_ audible-bell false
set_ allow-bold true
set_ show-scrollbar false
set_ cell-width-scale 1.0
set_ cell-height-scale 1.1
set_ login-shell false
set_ default-size-columns 120
set_ default-size-rows 34

echo "--- verify ---"
for k in visible-name font background-color foreground-color use-transparent-background cursor-shape scrollback-unlimited; do
  printf "%-28s %s\n" "$k" "$(gsettings get "$BASE" "$k")"
done
