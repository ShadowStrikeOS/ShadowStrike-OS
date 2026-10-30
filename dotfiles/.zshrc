# ShadowStrike OS zsh configuration.
# Operator: Epsilon0xCell
# Design rules: documented, boring where it should be, and every enhancement
# degrades gracefully when its tool is absent.

# --- MOTD ---------------------------------------------------------------------
# Printed once per interactive shell. The file is deployed by provision.sh.
if [[ -o interactive && -f "$HOME/shadowstrike/motd.txt" ]]; then
  cat "$HOME/shadowstrike/motd.txt"
  # fastfetch adds the system summary under the MOTD when it is installed.
  command -v fastfetch >/dev/null 2>&1 && fastfetch
fi

# --- History -------------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY        # append instead of overwriting the history file
setopt SHARE_HISTORY         # share history across concurrent shells
setopt HIST_IGNORE_ALL_DUPS  # one entry per command, newest wins
setopt HIST_IGNORE_SPACE     # commands starting with a space stay unrecorded
setopt EXTENDED_HISTORY      # record timestamps with each entry

# --- Completion ------------------------------------------------------------------
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select                 # arrow key menu
zstyle ':completion:*' matcher-list 'm:{a-z}=({A-Z})'  # case insensitive match
setopt AUTO_CD               # typing a directory name cds into it
setopt INTERACTIVE_COMMENTS  # allow comments at the prompt

# --- Path -------------------------------------------------------------------------
export PATH="$HOME/shadowstrike/bin:$HOME/.local/bin:$HOME/go/bin:$PATH"
export EDITOR="${EDITOR:-nano}"
export VISUAL="$EDITOR"

# Colour helpers used by the fallback prompt and aliases.
autoload -Uz colors && colors

# --- Prompt -------------------------------------------------------------------------
# Preferred: starship, when installed. Fallback: a built in two line prompt in
# the theme greens that shows user, host, directory, and the git branch when
# one exists. The fallback is the guarantee, starship is the polish.
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  autoload -Uz vcs_info
  zstyle ':vcs_info:*' enable git
  zstyle ':vcs_info:git:*' formats ' (%b)'
  precmd() { vcs_info }
  setopt PROMPT_SUBST
  PROMPT='%F{46}%n@%m%f %F{120}%~%f%F{40}${vcs_info_msg_0_}%f
%F{46}>%f '
  RPROMPT='%F{22}%T%f'
fi

# --- Aliases that earn their place ----------------------------------------------------
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me; echo'
alias serve='python3 -m http.server'
alias engage='cd "$HOME/shadowstrike/engagements"'
alias notes='cd "$HOME/shadowstrike/notes"'
alias reports='cd "$HOME/shadowstrike/reports"'
# Run sbom.sh from wherever this repo was placed in the machine, for example:
#   ~/shadowstrike-os/sbom.sh   (adjust to the real path)
# bat and fd ship under different binary names on Debian based systems.
command -v batcat >/dev/null 2>&1 && alias bat='batcat'
command -v fdfind >/dev/null 2>&1 && alias fd='fdfind'
command -v eza >/dev/null 2>&1 && alias ls='eza --group-directories-first'

# fzf key bindings when fzf is installed (Ctrl-R history, Ctrl-T files).
if command -v fzf >/dev/null 2>&1; then
  [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
fi

# zsh syntax highlighting and autosuggestions, only when the packages exist.
for plugin in \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [[ -f "$plugin" ]] && source "$plugin"
done
