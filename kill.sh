#!/bin/zsh

function kill_processes() {
  if ! [ -z $PRIV_SMB ]; then
    processes=$(lsof $PRIV_MOUNT 2> /dev/null | grep -v PID | awk '{print $2}' | paste -s -d' ')
    if ! [ -z "$processes" ]; then bluen List of hanging processes: ; yellowc " $processes"; fi
    for p in $processes; do
      if [ "$(ps -p $p -o comm= 2> /dev/null)" = "smbd" ]; then
        bluen The hanging process is smb daemon. Stopping service...
        systemctl stop smb
        bluec Done
        if eval "kill -0 $p" 2> /dev/null; then
          red "Process smbd is resisive. Killing it. (this is an error)"
          eval "kill -9 $p"
        fi
      else
        eval "kill -9 $p"
        bluen "Killed process $p"
      fi
    done
  else
    processes="$(lsof $PRIV_MOUNT 2> /dev/null | grep -v PID | awk '{print $2}')"
    if ! [[ -z $processes ]]; then
      echo "$processes" | xargs kill -9
    fi
  fi
}
