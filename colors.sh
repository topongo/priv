function echo_(){
  local COLOR="\e[36m"
  local LEAD=":: "
  if [ "$1" = "-n" ]; then
    echo -ne "$LEAD$COLOR${@:2}\e[0m"
  elif [ "$1" = "-c" ]; then
    echo -e "$COLOR${@:2}\e[0m"
  elif [ "$1" = "-o" ]; then
    echo "$LEAD\e[${2}m${@:3}\e[0m"
  elif [ "$1" = "-co" ]; then
    echo -e "\e[${2}m${@:3}\e[0m"
  else
    echo -e "$LEAD$COLOR${@}\e[0m"
  fi
}

alias red="echo_ -o 31"
alias green="echo_"
alias yellow="echo_ -o 33"
alias blue="echo_ -o 36"

alias redn="echo_ -no 31"
alias greenn="echo_ -n"
alias yellown="echo_ -no 33"
alias bluen="echo_ -no 36"
