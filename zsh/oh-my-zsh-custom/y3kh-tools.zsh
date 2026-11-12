# ============================================================================
#  y3kh — modern CLI stack (Aylin, 2026-11-11)
#  eza / bat / fzf / zoxide / delta / duf  — all colour-matched to Catppuccin
# ============================================================================

# ---------------------------------------------------------------- eza (ls) --
alias ls='eza --icons --group-directories-first'
alias l='eza --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first --git --time-style=long-iso'
alias la='eza -a --icons --group-directories-first'
alias lt='eza --tree --level=2 --icons --group-directories-first'
alias ltt='eza --tree --level=3 --icons --group-directories-first'
alias lta='eza --tree --level=2 -a --icons'
export EZA_COLORS="da=1;34:gm=1;33:xx=1;31"

# ---------------------------------------------------------------- bat (cat) --
if (( $+commands[batcat] )); then
  # only advertise a theme that bat actually knows about
  if batcat --list-themes 2>/dev/null | grep -qx 'Catppuccin-Mocha'; then
    export BAT_THEME="${BAT_THEME:-Catppuccin-Mocha}"
  else
    export BAT_THEME="${BAT_THEME:-Monokai Extended}"
  fi
  alias cat='batcat --style=plain --paging=never'
  alias catn='batcat --style=numbers --paging=never'
  alias catp='batcat --paging=never'          # paged, with header + line numbers
  alias less='batcat --paging=always'
fi

# ------------------------------------------------------------- duf / ncdu ----
alias df='duf'          # keep real `du` intact for scripts and muscle memory
alias disks='duf --only local'

# -------------------------------------------------------------- zoxide (cd) --
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd z)"           # `z partialdir` jumps anywhere
  alias j='z'
  alias ji='zi'
fi

# ---------------------------------------------------------------- fzf look ---
export FZF_DEFAULT_COMMAND='fdfind --hidden --follow --exclude .git --exclude node_modules'
export FZF_DEFAULT_OPTS="
  --height 60% --layout=reverse --border=rounded --info=inline-right
  --pointer='▶' --marker='✓' --prompt='  ' --separator='─'
  --color=fg:#cdd6f4,fg+:#1e1e2e,bg:#1e1e2e,bg+:#89b4fa,hl:#f9e2af,hl+:#f9e2af
  --color=info:#94e2d5,prompt:#f5c2e7,pointer:#f5c2e7,marker:#a6e3a1,spinner:#94e2d5,header:#f38ba8,border:#45475a
  --bind='ctrl-/:toggle-preview' --bind='ctrl-u:preview-half-page-up' --bind='ctrl-d:preview-half-page-down'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'batcat --style=numbers --color=always --line-range=:300 {}' --preview-window 'right:60%:rounded:wrap'"
export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git --exclude node_modules'
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always --group-directories-first {}' --preview-window 'right:60%:rounded'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window 'down:3:wrap:rounded' --bind 'ctrl-y:execute-silent(echo -n {2..} | xclip -selection clipboard 2>/dev/null)+abort'"

# Ctrl+T (files), Alt+C (dirs), Ctrl+R (history) — fzf key bindings only.
# NOT fzf's completion.zsh: it rebinds TAB and would fight fzf-tab (which owns
# TAB for the coloured dropdown). Also only load them in a real tty: the script
# saves/restores `zle`, which errors under `zsh -i -c` (no zle) and spams stderr.
if [[ -t 0 && -o interactive ]]; then
  [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && \
    source /usr/share/doc/fzf/examples/key-bindings.zsh
fi

# fuzzy-kill / fuzzy-git helpers
fk() { local pid; pid=$(ps -ef | sed 1d | fzf -m --header='kill> ' | awk '{print $2}'); [[ -n $pid ]] && echo "$pid" | xargs -r sudo kill -9; }
fgb() { git branch --sort=-committerdate | sed 's/^[* ] //' | fzf --header='checkout> ' | xargs -r git checkout; }
fgl() { git log --oneline --color=always --graph -n 200 | fzf --ansi --header='git log> ' --preview 'git show --stat --color=always {1}' --preview-window 'right:60%:rounded'; }

# ---------------------------------------------------------------- ripgrep ----
alias rgi='rg -i'
alias rgf='rg --files-with-matches'

# ------------------------------------------------------------------ history --
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_VERIFY
HISTSIZE=100000
SAVEHIST=100000
[[ -d ~/.cache/zsh ]] || mkdir -p ~/.cache/zsh
export HISTFILE=~/.cache/zsh/zsh_history

# ------------------------------------------------------------- git (delta) ---
if (( $+commands[delta] )); then
  export GIT_PAGER=delta
  export DELTA_FEATURES="side-by-side line-numbers decorations navigate"
fi

# ============================================================================
#  welcome banner (fastfetch) — Catppuccin colours, VPN/tailnet at a glance
# ============================================================================
if (( $+commands[fastfetch] )) && [[ -o interactive && -t 0 && -z $Y3KH_QUIET ]]; then
  if [[ -z $Y3KH_BANNER_SHOWN ]]; then
    fastfetch --config "$HOME/.config/fastfetch/config.jsonc" 2>/dev/null
    export Y3KH_BANNER_SHOWN=1        # once per terminal window, not per sub-shell
  fi
fi
alias banner='fastfetch --config ~/.config/fastfetch/config.jsonc'
alias nobanner='export Y3KH_QUIET=1'
alias yesbanner='unset Y3KH_QUIET; unset Y3KH_BANNER_SHOWN'

# ============================================================================
#  atuin — SQLite history + fuzzy search (owns Ctrl+R; fzf keeps Ctrl+T/Alt+C)
# ============================================================================
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-up-arrow)"
  alias ah='atuin search --interactive'
  alias ah-stats='atuin stats'
  alias ah-sync='atuin sync'
fi

# ============================================================================
#  TUIs
# ============================================================================
alias lg='lazygit'                       # full git TUI
alias zj='zellij'                        # modern multiplexer (alternative to tmux)
alias zja='zellij attach'
alias btop='btop --utf-force'
alias disks='duf'



