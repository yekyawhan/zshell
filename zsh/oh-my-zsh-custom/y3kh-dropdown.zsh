# ============================================================================
#  y3kh — zsh completion "dropdown" + colours  (Aylin, 2026-11-11)
#  Sourced automatically by oh-my-zsh (custom/*.zsh), i.e. AFTER the plugins,
#  so these zstyles override everything else.
# ============================================================================

# --- colours for the completion list come from LS_COLORS --------------------
if (( $+commands[dircolors] )); then
  eval "$(dircolors -b)"
fi
export LS_COLORS

# --- the menu itself: appears while typing, arrow keys + TAB to walk it -----
# NOTE (learned the hard way): do NOT override ':completion:*' menu/completer/
# matcher-list here — zsh-autocomplete sets those itself, and overriding them
# stops it from drawing its list entirely (no dropdown at all).
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''

# group headers: KEEP THEM PLAIN.
# zsh does not prompt-expand the `format` style in every listing path, and
# fzf-tab passes it through to fzf as-is - '%F{cyan}%d%f' showed up as literal
# escape text inside the popup. Text only, no %-escapes.
zstyle ':completion:*:descriptions' format '%d'
zstyle ':completion:*:messages'     format '%d'

# smart matching / typo tolerance

# directory / process / ssh niceties

# speed: cache the completion dump

# --- keys / options (what makes it feel like the "youtuber" setup) ---------
setopt AUTO_MENU AUTO_LIST COMPLETE_IN_WORD ALWAYS_TO_END
setopt NO_FLOW_CONTROL                  # ^S / ^Q usable again
setopt HIST_FCNTL_LOCK
bindkey '^[[Z' reverse-menu-complete    # shift-TAB walks the menu backwards

# fish-style inline suggestion colour (must be set before the plugin defaults
# are used; harmless when the plugin is already loaded)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'

# ============================================================================
#  oh-my-posh themes — a curated set (~/.ohmyposhthemes) + oh-my-posh built-ins
# ============================================================================
export POSH_THEMES_PATH="${POSH_THEMES_PATH:-$HOME/.ohmyposhthemes}"

# theme            -> switch the prompt for this shell
# theme-list       -> show what is available
theme() {
  local name="${1%.omp.json}"
  if [[ -z "$name" ]]; then
    print -P "%F{cyan}available themes:%f"
    ls -1 "$HOME/.ohmyposhthemes" | sed 's/\.omp\.json$//' | paste -sd' ' -
    return 0
  fi
  local f="$HOME/.ohmyposhthemes/$name.omp.json"
  if [[ -f "$f" ]]; then
    eval "$(oh-my-posh init zsh --config "$f")"
    print -P "%F{green}prompt theme → $name%f"
  else
    print -P "%F{red}no such theme: $name%f"
    theme
  fi
}
alias theme-list='ls -1 ~/.ohmyposhthemes | sed "s/\.omp\.json$//"'
alias theme-show='oh-my-posh print primary --config'

# quick presets for the three classic themes
alias theme-atomic='eval "$(oh-my-posh init zsh --config ~/.ohmyposhthemes/atomic.omp.json)"'
alias theme-tokyo='eval "$(oh-my-posh init zsh --config ~/.ohmyposhthemes/tokyo.omp.json)"'
alias theme-jandedobbeleer='eval "$(oh-my-posh init zsh --config ~/.ohmyposhthemes/jandedobbeleer.omp.json)"'
# ============================================================================
#  fzf-tab: the coloured dropdown that pops up on TAB (the "youtuber" look)
# ============================================================================
if (( $+commands[fzf] )); then
  # nice dark palette + a tall enough list that it reads like a menu
  zstyle ':fzf-tab:*' fzf-flags \
    --color=fg:#a6adc8,bg:#11111b,hl:#f9e2af,fg+:#cdd6f4,bg+:#313244,hl+:#f9e2af \
    --color=pointer:#f5c2e7,marker:#a6e3a1,spinner:#89dceb,info:#9399b2,border:#45475a,header:#89b4fa
  zstyle ':fzf-tab:*' fzf-min-height 20
  zstyle ':fzf-tab:*' switch-group ',' '.'
  zstyle ':fzf-tab:*' continuous-trigger '/'          # keep the menu open
  zstyle ':fzf-tab:*' accept-line enter
  zstyle ':fzf-tab:*' popup-min-size 40 8

  # previews where they help
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath 2>/dev/null | head -40'
  zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'systemctl status $word 2>/dev/null | head -20'
  zstyle ':fzf-tab:complete:git-(add|diff|restore|checkout):*' fzf-preview \
    'git diff --color=always -- $word 2>/dev/null | head -60'
  zstyle ':fzf-tab:complete:kill:*' fzf-preview \
    'ps -p ${(M)${(f)"$(ps -eo pid,args)"}:#([[:space:]]|^)$word([[:space:]]|$)} -o pid,args 2>/dev/null'
fi

# ============================================================================
#  "dropdown appears while you TYPE"  (auto-list on every keystroke)
#  zsh-autocomplete's live list does not draw with this config, so we drive
#  zle's own list-choices from a self-insert wrapper - native, no plugin.
# ============================================================================
_y3kh_list_choices() {
  local -i min=2                     # don't spray a list for 1-char input
  (( ${#${(z)BUFFER}} )) || return   # empty line
  (( ${#BUFFER} >= min )) || return
  zle list-choices 2>/dev/null
}

_y3kh_self_insert() {
  zle .self-insert
  _y3kh_list_choices
}
zle -N self-insert _y3kh_self_insert

# keep the list coming after deleting characters too
_y3kh_backward_delete_char() {
  zle .backward-delete-char
  _y3kh_list_choices
}
zle -N backward-delete-char _y3kh_backward_delete_char

# big lists: show them packed, and never wait for a slow completion
setopt AUTO_LIST LIST_PACKED
unsetopt LIST_BEEP            # the auto-list must never beep/warn on every key
