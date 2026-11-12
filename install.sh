#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  zshell installer — Catppuccin Mocha terminal / desktop setup
#  Target: Ubuntu 24.04 / Linux Mint 22.x (Cinnamon)
#
#  Usage:
#    bash install.sh [--dry-run] [--minimal] [--no-desktop] [--no-nvim] [--no-tmux]
#
#  Can also be piped straight from GitHub (it clones itself first):
#    bash -c "$(gh api -H 'Accept: application/vnd.github.raw' \
#                repos/yekyawhan/zshell/contents/install.sh)"
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO_SLUG="yekyawhan/zshell"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DRY_RUN=0 ; WITH_DESKTOP=1 ; WITH_NVIM=1 ; WITH_TMUX=1 ; MINIMAL=0 ; KEEP_ZSHRC=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=1 ;;
    --no-desktop) WITH_DESKTOP=0 ;;
    --no-nvim)    WITH_NVIM=0 ;;
    --no-tmux)    WITH_TMUX=0 ;;
    --keep-zshrc) KEEP_ZSHRC=1 ;;
    --minimal)    MINIMAL=1 ; WITH_DESKTOP=0 ; WITH_NVIM=0 ;;
    -h|--help)    sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2 ; exit 2 ;;
  esac
done

log()  { printf '\033[38;5;183m▸\033[0m %s\n' "$*"; }
warn() { printf '\033[38;5;215m!\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[38;5;150m✔\033[0m %s\n' "$*"; }
run()  { if (( DRY_RUN )); then printf '  \033[38;5;245m+ %s\033[0m\n' "$*"; else "$@" ; fi }

# sudo helper
#   interactive terminal      -> sudo prompts normally
#   SUDO_PASSWORD=<pw> set    -> fully unattended
#   neither (CI / piped run)  -> passwordless sudo only, with a clear message
if [[ -n "${SUDO_PASSWORD:-}" ]]; then
  sdo() { printf '%s\n' "$SUDO_PASSWORD" | sudo -S "$@" 2>/dev/null || sudo "$@" ; }
elif [[ -t 0 ]]; then
  sdo() { sudo "$@" ; }
else
  sdo() { sudo -n "$@" 2>/dev/null || { warn "sudo needs a password here — re-run interactively or set SUDO_PASSWORD=…"; return 1; } ; }
fi

# ── locate (or fetch) the dotfiles tree ──────────────────────────────────────
SRC="${BASH_SOURCE[0]:-}"
case "$SRC" in
  ""|bash|sh|/bin/bash|/bin/sh|-) SCRIPT_DIR="" ;;     # piped run: no file on disk
  *) SCRIPT_DIR="$(cd "$(dirname "$SRC")" 2>/dev/null && pwd || echo "")" ;;
esac
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/zsh/.zshrc" ]]; then
  REPO_DIR="$SCRIPT_DIR"
else
  REPO_DIR="$DOTFILES_DIR"
  if [[ ! -f "$REPO_DIR/zsh/.zshrc" ]]; then
    log "fetching $REPO_SLUG into $REPO_DIR"
    if run git clone --depth 1 "https://github.com/$REPO_SLUG.git" "$REPO_DIR"; then
      :                                    # public repo — plain https, no auth needed
    elif command -v gh >/dev/null 2>&1 && run gh repo clone "$REPO_SLUG" "$REPO_DIR" -- --depth 1; then
      :                                    # fallback (gh, e.g. for a private fork)
    else
      warn "could not clone $REPO_SLUG — clone it yourself and run install.sh from inside it"; exit 1
    fi
  fi
fi
log "using dotfiles from $REPO_DIR"

ARCH="$(uname -m)"                       # x86_64 / aarch64
case "$ARCH" in
  x86_64)  NF_ARCH="x86_64" ; LG_ARCH="x86_64" ; AT_ARCH="x86_64-unknown-linux-gnu" ; ZJ_ARCH="x86_64-unknown-linux-musl" ; NV_ARCH="x86_64" ; TS_ARCH="x64" ;;
  aarch64) NF_ARCH="arm64"  ; LG_ARCH="arm64"  ; AT_ARCH="aarch64-unknown-linux-gnu" ; ZJ_ARCH="aarch64-unknown-linux-musl" ; NV_ARCH="arm64" ; TS_ARCH="arm64" ;;
  *) warn "unsupported arch $ARCH"; exit 1 ;;
esac
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

gh_latest() {  # $1=repo  → prints tag
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1
}

# ── 1. apt packages ──────────────────────────────────────────────────────────
log "apt packages"
run sdo apt-get update -qq
APT_PKGS=(zsh tmux git curl unzip jq fzf eza bat zoxide fd-find ripgrep git-delta
          ncdu duf tree btop imagemagick python3-venv xclip
          fonts-noto-core fonts-noto-color-emoji papirus-icon-theme gnome-terminal)
(( WITH_DESKTOP )) && APT_PKGS+=(gir1.2-secret-1)
run sdo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PKGS[@]}" || warn "apt issues — continuing"

# ── 2. Nerd Font (prompt icons) ──────────────────────────────────────────────
if ! fc-list 2>/dev/null | grep -qi "nerd"; then
  log "installing Meslo Nerd Font"
  run mkdir -p "$HOME/.local/share/fonts"
  run curl -fsSL -o "$TMP/meslo.zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
  run unzip -qo "$TMP/meslo.zip" -d "$HOME/.local/share/fonts"
  run fc-cache -f
else
  ok "nerd font already present"
fi

# ── 3. GitHub-release binaries (not in apt) ──────────────────────────────────
install_tar_bin() {  # $1=url  $2=binary  $3=dest
  curl -fsSL -o "$TMP/dl.tgz" "$1" || { warn "download failed: $1"; return 1; }
  tar xzf "$TMP/dl.tgz" -C "$TMP" 2>/dev/null
  local found; found="$(find "$TMP" -maxdepth 3 -type f -name "$2" | head -1)"
  [[ -n "$found" ]] && sdo install -m755 "$found" "$3" || { warn "binary $2 not found in archive"; return 1; }
}

command -v fastfetch >/dev/null || {
  log "fastfetch"
  run curl -fsSL -o "$TMP/ff.deb" "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb"
  run sdo apt-get install -y "$TMP/ff.deb"
}
command -v lazygit >/dev/null || {
  log "lazygit $(gh_latest jesseduffield/lazygit)"
  LG_V="$(gh_latest jesseduffield/lazygit)"; LG_V="${LG_V#v}"
  run install_tar_bin "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_V}_linux_${LG_ARCH}.tar.gz" lazygit /usr/local/bin/lazygit
}
command -v atuin >/dev/null || {
  log "atuin"
  run install_tar_bin "https://github.com/atuinsh/atuin/releases/latest/download/atuin-${AT_ARCH}.tar.gz" atuin /usr/local/bin/atuin
}
command -v zellij >/dev/null || {
  log "zellij"
  run install_tar_bin "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ZJ_ARCH}.tar.gz" zellij /usr/local/bin/zellij
}
if ! command -v nvim >/dev/null || [[ "$(nvim --version | head -1)" == *"v0.9"* ]]; then
  log "neovim (latest)"
  run curl -fsSL -o "$TMP/nvim.tgz" "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NV_ARCH}.tar.gz"
  run sdo tar xzf "$TMP/nvim.tgz" -C /opt
  run sdo ln -sf "/opt/nvim-linux-${NV_ARCH}/bin/nvim" /usr/local/bin/nvim
fi
command -v tree-sitter >/dev/null || {
  log "tree-sitter CLI (for nvim-treesitter)"
  run curl -fsSL -o "$TMP/ts.zip" "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-cli-linux-${TS_ARCH}.zip"
  run unzip -qo "$TMP/ts.zip" -d "$TMP/tsx"
  run sdo install -m755 "$TMP/tsx/tree-sitter" /usr/local/bin/tree-sitter
}

# ── 4. shell: oh-my-zsh + plugins + oh-my-posh ───────────────────────────────
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log "oh-my-zsh"
  run git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh"
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for p in "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions" \
         "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting" \
         "fzf-tab https://github.com/Aloxaf/fzf-tab"; do
  set -- $p
  [[ -d "$ZSH_CUSTOM/plugins/$1" ]] || { log "plugin $1"; run git clone --depth 1 "$2" "$ZSH_CUSTOM/plugins/$1"; }
done
command -v oh-my-posh >/dev/null || {
  log "oh-my-posh"
  run bash -c 'curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d /tmp/omp'
  run sdo install -m755 /tmp/omp/oh-my-posh /usr/local/bin/oh-my-posh
}

# ── 5. dotfiles ──────────────────────────────────────────────────────────────
log "installing dotfiles"
# ~/.zshrc — never clobber it silently. An existing file that differs from ours is
# backed up first (aliases usually live in it), and --keep-zshrc leaves it alone
# entirely: the shell config wants one thing only, to source local.zsh last.
LOCAL_SOURCE_LINE='[[ -r "$HOME/.config/y3kh/local.zsh" ]] && source "$HOME/.config/y3kh/local.zsh"'
if [[ -f "$HOME/.zshrc" ]] && ! cmp -s "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"; then
  STAMP="$(date +%Y%m%d-%H%M%S)"
  run cp "$HOME/.zshrc" "$HOME/.zshrc.pre-zshell-$STAMP"
  warn "your own ~/.zshrc was saved as ~/.zshrc.pre-zshell-$STAMP"
  warn "personal aliases/ssh hosts belong in ~/.config/y3kh/local.zsh — it is sourced last"
  if (( KEEP_ZSHRC )); then
    log "keeping your ~/.zshrc (--keep-zshrc); only ensuring it sources local.zsh"
    if ! grep -q 'config/y3kh/local.zsh' "$HOME/.zshrc"; then
      SNIP="$(mktemp)"
      printf '\n# ── local overrides (not committed) ────────────────────────────────────\n%s\n' \
        "$LOCAL_SOURCE_LINE" > "$SNIP"
      run bash -c 'cat "$0" >> "$HOME/.zshrc"' "$SNIP"
      run rm -f "$SNIP"
    fi
  else
    run cp "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"
  fi
else
  run cp "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"
fi
run cp "$REPO_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
run mkdir -p "$ZSH_CUSTOM"
run cp "$REPO_DIR"/zsh/oh-my-zsh-custom/*.zsh "$ZSH_CUSTOM/"
run mkdir -p "$HOME/.ohmyposhthemes" && run cp "$REPO_DIR"/oh-my-posh/themes/*.omp.json "$HOME/.ohmyposhthemes/"
run cp "$REPO_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
run mkdir -p "$HOME/.config/fastfetch" && run cp "$REPO_DIR/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/"
run mkdir -p "$HOME/.config/atuin/themes" && run cp "$REPO_DIR/config/atuin/config.toml" "$HOME/.config/atuin/" && run cp "$REPO_DIR"/config/atuin/themes/*.toml "$HOME/.config/atuin/themes/" 2>/dev/null
run mkdir -p "$HOME/.config/lazygit" && run cp "$REPO_DIR"/config/lazygit/*.yml "$HOME/.config/lazygit/"
run mkdir -p "$HOME/.config/zellij" && run cp "$REPO_DIR/config/zellij/config.kdl" "$HOME/.config/zellij/"
run mkdir -p "$HOME/.config/y3kh"
# generic host-list example (never overwrite a real one)
if [[ ! -f "$HOME/.config/y3kh/ssh-hosts.txt" ]]; then
  run cp "$REPO_DIR/config/y3kh/ssh-hosts.example.txt" "$HOME/.config/y3kh/ssh-hosts.txt"
fi
# personal overrides: template only — never overwrite an existing local.zsh
if [[ ! -f "$HOME/.config/y3kh/local.zsh" ]]; then
  run cp "$REPO_DIR/config/y3kh/local.zsh.example" "$HOME/.config/y3kh/local.zsh"
  ok "created ~/.config/y3kh/local.zsh (put your ssh/vpn/personal aliases here)"
fi

# ── carry over the user's OWN aliases so nothing is lost ─────────────────────
# local.zsh is sourced last by .zshrc, so anything imported here keeps working.
IMPORT_FROM=()
if [[ -n "${STAMP:-}" && -f "$HOME/.zshrc.pre-zshell-$STAMP" ]]; then
  IMPORT_FROM+=("$HOME/.zshrc.pre-zshell-$STAMP")        # the file we just replaced
fi
for _f in "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.zsh_aliases" "$HOME/.bash_profile"; do
  [[ -f "$_f" ]] && IMPORT_FROM+=("$_f")
done
if (( ${#IMPORT_FROM[@]} )) && [[ -f "$REPO_DIR/scripts/import-aliases.py" ]]; then
  log "carrying over your existing aliases (they keep working)"
  run python3 "$REPO_DIR/scripts/import-aliases.py" --into "$HOME/.config/y3kh/local.zsh" "${IMPORT_FROM[@]}"
fi
run mkdir -p "$HOME/.config/bat/themes" && run cp "$REPO_DIR"/config/bat/themes/*.tmTheme "$HOME/.config/bat/themes/" 2>/dev/null
run batcat cache --build || true

# ── 6. Myanmar font rendering (optional, harmless elsewhere) ────────────────
if [[ -f "$REPO_DIR/config/fontconfig/69-y3kh-myanmar-unicode.conf" ]]; then
  log "fontconfig: Unicode Burmese preference"
  run sdo install -m644 "$REPO_DIR/config/fontconfig/69-y3kh-myanmar-unicode.conf" /etc/fonts/conf.d/
  run sdo fc-cache -f
fi

# ── 7. tmux plugins (TPM) ────────────────────────────────────────────────────
if (( WITH_TMUX )); then
  log "tmux plugins"
  [[ -d "$HOME/.tmux/plugins/tpm" ]] || run git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  run tmux new-session -d -s _installdeps
  run "$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "tmux plugin install skipped"
  run tmux kill-server
fi

# ── 8. neovim (LazyVim + Catppuccin) ─────────────────────────────────────────
if (( WITH_NVIM )); then
  log "neovim config (LazyVim + Catppuccin)"
  run mkdir -p "$HOME/.config"
  [[ -d "$HOME/.config/nvim" ]] && run cp -r "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$$"
  run cp -r "$REPO_DIR/nvim" "$HOME/.config/nvim"
  if (( ! DRY_RUN )); then
    log "syncing nvim plugins (this takes a few minutes)"
    nvim --headless "+Lazy! sync" +qa >/tmp/nvim-sync.log 2>&1 || warn "Lazy sync reported issues — see /tmp/nvim-sync.log"
    ok "nvim plugins synced"
  fi
fi

# ── 9. desktop (terminal profile, GTK/Cinnamon theme, icons, wallpaper) ─────
if (( WITH_DESKTOP )); then
  log "desktop theming (terminal profile + Cinnamon)"
  run bash "$REPO_DIR/desktop/style_terminal.sh" || warn "terminal profile step failed"
  run bash "$REPO_DIR/desktop/desktop_catppuccin.sh" || warn "desktop theme step failed"
  if [[ -d "$REPO_DIR/desktop/cinnamon-theme" ]]; then
    run mkdir -p "$HOME/.themes/Catppuccin-Mocha-Cinnamon/cinnamon"
    run cp -r "$REPO_DIR/desktop/cinnamon-theme/." "$HOME/.themes/Catppuccin-Mocha-Cinnamon/"
  fi
fi

# ── 10. default shell ───────────────────────────────────────────────────────
if [[ "${SHELL:-}" != */zsh ]]; then
  log "setting zsh as login shell"
  run sdo chsh -s "$(command -v zsh)" "$(whoami)" || warn "chsh failed — run: chsh -s $(command -v zsh)"
fi

# ── done ────────────────────────────────────────────────────────────────────
echo
ok "install complete"
cat <<'EOF'

  Open a NEW terminal (or run: exec zsh) and try:
    Ctrl+R   atuin  — fuzzy shell history
    Ctrl+T   fzf    — fuzzy file finder (bat preview)
    Alt+C    fzf    — fuzzy cd (eza tree preview)
    Ctrl+G   ssh    — ssh host launcher
    Tab      fzf-tab — coloured completion dropdown
    lg / nvim / zj / btop / duf / eza / batcat …

  Prompt themes:  theme-list  →  theme tokyo   (atomic is the default)
  VPN / tailnet:  vpn-status
  Banner off:     nobanner (this shell) · export Y3KH_QUIET=1 (permanent)

EOF
