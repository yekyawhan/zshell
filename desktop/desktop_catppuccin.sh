#!/bin/bash
# sudo helper — works interactively, or non-interactively when SUDO_PASSWORD is set
if [[ -n "${SUDO_PASSWORD:-}" ]]; then
  sdo() { printf '%s\n' "$SUDO_PASSWORD" | sudo -S "$@" 2>/dev/null || sudo "$@"; }
else
  sdo() { sudo "$@"; }
fi

# Catppuccin Mocha for the Cinnamon desktop: GTK theme, recoloured Cinnamon
# shell theme, Papirus icons (+mauve folders), Bibata cursor, generated
# wallpaper. Idempotent.
set -e
export DISPLAY=:0 XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" DBUS_SESSION_BUS_ADDRESS=unix:path=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus

# 1 ── GTK theme (apps: nemo, dialogs, settings) -----------------------------
mkdir -p ~/.themes
cd /tmp/dl
unzip -q -o catppuccin-gtk.zip -d ~/.themes/
GTK=$(ls -d ~/.themes/catppuccin-mocha-mauve* 2>/dev/null | head -1)
echo "gtk theme dir: $(basename "$GTK")"

# 2 ── Cinnamon shell theme (panel/menu), recoloured from Mint-Y-Dark-Aqua ---
THEME=~/.themes/Catppuccin-Mocha-Cinnamon
rm -rf "$THEME"; mkdir -p "$THEME"
cp -r /usr/share/themes/Mint-Y-Dark-Aqua/cinnamon "$THEME/"
sed -i \
  -e 's/#1f9ede/#cba6f7/gI' -e 's/#303036/#313244/gI' -e 's/#222226/#1e1e2e/gI' \
  -e 's/#3c3c44/#45475a/gI' -e 's/#494951/#45475a/gI' -e 's/#44444c/#585b70/gI' \
  -e 's/#38383e/#313244/gI' -e 's/#e1e1e1/#cdd6f4/gI' -e 's/#c3c3c3/#a6adc8/gI' \
  -e 's/#c01c28/#f38ba8/gI' -e 's/#F27835/#fab387/gI' -e 's/#ffffff/#f5e0dc/gI' \
  "$THEME"/cinnamon/*.css
cat > "$THEME/index.theme" <<EOF
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=Catppuccin-Mocha-Cinnamon
Comment=Catppuccin Mocha (Aylin)
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=$(basename "$GTK")
IconTheme=Papirus-Dark
CursorTheme=Bibata-Modern-Classic
EOF

# 3 ── Papirus folders recoloured to Catppuccin Mocha ------------------------
if ! command -v papirus-folders >/dev/null; then
  curl -fsSL -o /tmp/papirus-folders \
    https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders
  sdo install -m755 /tmp/papirus-folders /usr/local/bin/papirus-folders
fi
sdo papirus-folders -C cat-mocha-mauve --theme Papirus-Dark >/dev/null 2>&1 || echo "  (papirus-folders recolor skipped)"

# 4 ── wallpaper (generated, Catppuccin Mocha) -------------------------------
mkdir -p ~/Pictures/wallpapers
convert -size 1920x1080 gradient:'#1e1e2e-#11111b' /tmp/wall_base.png
convert -size 1400x1400 radial-gradient:'#cba6f7-#11111b' -resize 1920x1080\! /tmp/wall_glow.png
convert /tmp/wall_base.png /tmp/wall_glow.png -compose Screen -composite \
        -blur 0x55 -attenuate 0.05 +noise Gaussian ~/Pictures/wallpapers/catppuccin-mocha.png
rm -f /tmp/wall_base.png /tmp/wall_glow.png
echo "wallpaper: $(identify ~/Pictures/wallpapers/catppuccin-mocha.png | head -1)"

# 5 ── apply ----------------------------------------------------------------
set_() { gsettings set "$1" "$2" "$3" 2>/dev/null || echo "  (no key: $1 $2)"; }
set_ org.cinnamon.desktop.interface gtk-theme           "$(basename "$GTK")"
set_ org.cinnamon.desktop.interface icon-theme          'Papirus-Dark'
set_ org.cinnamon.desktop.interface cursor-theme        'Bibata-Modern-Classic'
set_ org.cinnamon.desktop.interface font-name           'Noto Sans 10'
set_ org.cinnamon.desktop.interface document-font-name  'Noto Sans 10'
set_ org.gnome.desktop.interface    monospace-font-name 'MesloLGLDZ Nerd Font 10'
set_ org.cinnamon.theme             name                'Catppuccin-Mocha-Cinnamon'
set_ org.cinnamon.desktop.wm.preferences theme          'Catppuccin-Mocha-Cinnamon'
set_ org.cinnamon.desktop.background picture-uri        'file://$HOME/Pictures/wallpapers/catppuccin-mocha.png'
set_ org.cinnamon.desktop.background picture-options    'zoom'
set_ org.cinnamon.desktop.screensaver picture-uri       'file://$HOME/Pictures/wallpapers/catppuccin-mocha.png'

echo "--- applied ---"
for k in "org.cinnamon.desktop.interface gtk-theme" "org.cinnamon.theme name" \
         "org.cinnamon.desktop.interface icon-theme" "org.cinnamon.desktop.interface cursor-theme" \
         "org.cinnamon.desktop.background picture-uri" "org.cinnamon.desktop.interface font-name"; do
  printf "%-52s %s\n" "$k" "$(gsettings get $k)"
done
