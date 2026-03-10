
export ZSH="$HOME/.oh-my-zsh"
export PATH="$PATH:$HOME/.local/bin"

ZSH_THEME=""

plugins=(git
zsh-syntax-highlighting
    zsh-autosuggestions
    z)

nv() {
  local target="${1:-.}"
  (cd "$target" && nvim .)
}
eval "$(oh-my-posh init zsh --config ~/.config/omp/catppucin.omp.json)"
source $ZSH/oh-my-zsh.sh

alias l='lsd -l'
alias la='lsd -a'
alias lla='lsd -la'
alias lt='lsd --tree'
alias ls='lsd'

# bun completions
[ -s "/home/lilwasd/.bun/_bun" ] && source "/home/lilwasd/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
