# NVM lazy load
if [ -s "$(brew --prefix nvm)/nvm.sh" ]; then
  [ -s "$(brew --prefix nvm)/bash_completion" ] && . "$(brew --prefix nvm)/bash_completion"
  alias nvm='unalias nvm node npm && . "$(brew --prefix nvm)"/nvm.sh && nvm'
  alias node='unalias nvm node npm && . "$(brew --prefix nvm)"/nvm.sh && node'
  alias npm='unalias nvm node npm && . "$(brew --prefix nvm)"/nvm.sh && npm'
fi
