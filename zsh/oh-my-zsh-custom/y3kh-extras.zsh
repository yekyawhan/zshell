# y3kh — ssh host launcher + VPN/tailnet helpers
# (new file, sourced after y3kh-tools.zsh; fzf menu on Ctrl+G)

Y3K_HOSTS="${Y3K_HOSTS:-$HOME/.config/y3kh/ssh-hosts.txt}"

# ── helper: is tailscale up? ────────────────────────────────────────────────
_tailnet_state() {
  if ! command -v tailscale >/dev/null 2>&1; then print -n "no-ts"; return; fi
  local ip; ip=$(timeout 2 tailscale ip -4 2>/dev/null | head -1)
  [[ -n $ip ]] && print -n "$ip" || print -n "down"
}

# ── helper: active VPN connections ─────────────────────────────────────────
_vpn_state() {
  local v; v=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2=="vpn"{printf "%s ", $1}')
  [[ -n $v ]] && print -n "${v% }" || print -n "none"
}

vpn-status() {
  print -P "%F{cyan}── VPN / network ──%f"
  print -P "  %F{white}tailnet   %f$(_tailnet_state)"
  print -P "  %F{white}vpn       %f$(_vpn_state)"
  print -P "  %F{white}lan ip    %f$(ip -4 -o addr show scope global | awk '{print $2" "$4}' | paste -sd', ' -)"
  print -P "  %F{white}default   %f$(ip route | awk '/^default/{print $3" via "$5; exit}')"
  if command -v tailscale >/dev/null 2>&1; then
    print -P "%F{cyan}── tailnet peers ──%f"
    timeout 3 tailscale status 2>/dev/null | head -12
  fi
}

# ── host launcher: fzf list of the estate, Ctrl+G ──────────────────────────
_y3kh_pick_host() {
  [[ -r $Y3K_HOSTS ]] || { zle -M "no host list at $Y3K_HOSTS"; return 1; }
  local pick
  pick=$(grep -vE '^\s*(#|$)' "$Y3K_HOSTS" \
        | fzf --height 60% --layout=reverse --border=rounded \
              --prompt='ssh ▸ ' --pointer='▶' \
              --header="$(printf '\\e[1;35mestate hosts\\e[0m  —  type to filter, Enter to ssh')" \
              --preview 'echo {} | awk -F"|" "{print \$3}" | sed "s/^ *//" | xargs -r -I{} sh -c "echo; echo  \\\"\\\$\$ {}\\\"; echo" ' \
              --preview-window 'down:6:wrap:rounded')
  [[ -z $pick ]] && return 0
  local host; host=$(echo "$pick" | awk -F'|' '{gsub(/ /,"",$1); print $1}')
  zle -M "connecting to $host …"
  BUFFER="ssh $host"
  zle accept-line
}
zle -N _y3kh_pick_host
bindkey '^G' _y3kh_pick_host          # Ctrl+G inside zsh

# same thing from a normal prompt / alias
hosts-list() { grep -vE '^\s*(#|$)' "$Y3K_HOSTS" | column -t -s'|'; }
alias hl='hosts-list'
alias ho='print -z "$(hosts-list | fzf --height 50% --layout=reverse | awk "{print \$1}")"'

# ── your own host shortcuts belong in ~/.config/y3kh/local.zsh ─────────────
# (see config/y3kh/local.zsh.example) so they stay out of this repo.
