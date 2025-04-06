## ###########################################################################
## setup interactive environment
## ###########################################################################
set -o vi
autoload -U colors && colors
setopt PROMPT_SUBST
setopt interactivecomments
setopt auto_cd
export EDITOR=/opt/homebrew/bin/vim
