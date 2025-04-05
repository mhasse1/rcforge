## ###########################################################################
## set the prompt
## reference:
##   https://subscription.packtpub.com/book/application-development/9781783282937/1/ch01lvl1sec10/the-shell-prompt
##   https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.html
##   color guide: https://jonasjacek.github.io/colors/
## %(!.#.%%) => Equivalent to %# in the zsh prompt => %(!.priv.not)
## ###########################################################################

# Autoload zsh's version control system
autoload -Uz vcs_info

# Configure vcs_info for Git
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*' formats " %F{magenta}(git:%b%m)%f"
zstyle ':vcs_info:git*' actionformats " %F{magenta}(git:%b|%a%m)%f"
zstyle ':vcs_info:git*' check-for-changes true
zstyle ':vcs_info:git*' stagedstr " *"
zstyle ':vcs_info:git*' unstagedstr " +"

# Precmd hook to update version control information
precmd() {
    vcs_info
}

# Add vcs_info to the prompt
export PROMPT="
%(!.%K{88}%F{white}%B     root     %b%f%k
.)%# [%F{cyan}%n%f@%F{yellow}%m%f] %F{green}%~%f\${vcs_info_msg_0_}
"
export PS2="%K{7} %k   "

## Older, simpler prompt
## export PROMPT="
## %(!.%K{88}%F{white}%B     root     %b%f%k
## .)%# [%F{cyan}%n%f@%F{yellow}%m%f] %F{green}%~%f
## "
## export PS2="%K{7} %k   "
