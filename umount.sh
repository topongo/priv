#!/bin/zsh

cd $(dirname $0)
source colors.sh
source configs.sh
[ -z $TELEGRAM_TOKEN ] || export PRIVATE_SPACE_TELEGRAM=true

if [ $UID != 0 ]; then
  echo_ Root access needed.
  exit 1
fi

if ! [[ "$1" =~ '^[0-9]+$' ]] ; then
  timeout=$((60 * 60))
else
  timeout=$(($1 * 60))
fi

function kill_processes() {
  if ! [ -z $PRIVATE_SPACE_SMB ]; then
    processes=$(lsof /srv/nfs/private | grep -v PID | awk '{print $2}' | paste -s -d' ')
    if ! [ -z "$processes" ]; then echo_ -n List of hanging processes: ; echo_ -co 31 " $processes"; fi
    for p in $processes; do
      if ! [ -z $PRIVATE_SPACE_SMB ] && [ "$(ps -p $p -o comm= 2> /dev/null)" = "smbd" ]; then
        echo_ -n The hanging process is smb daemon. Stopping service...
        systemctl stop smb
        echo_ -c Done
        if eval "kill -0 $p" 2> /dev/null; then
          echo_ -o 31 "Process smbd is resisive. Killing it. (this is an error)"
          eval "kill -9 $p"
        fi
      else
        eval "kill -9 $p"
        echo_ "Killed process $p"
      fi
    done
  else
   lsof mount | grep -v PID | awk '{print $2}' | xargs kill -9
  fi
}

function actual_umount(){
  if ! [ -z $PRIVATE_SPACE_AUTO_SUSPEND ]; then
    echo x > /var/auto_suspend/override_c
    echo_ "Override cancelled for auto_suspend"
  fi

  if ! [ -z $PRIVATE_SPACE_NFS ]; then
    # check if nfs binding is actually mounted
    if mountpoint /srv/nfs/private > /dev/null; then
      # try to umount nfs binding
      systemctl stop nfs-server
      if ! umount -f /srv/nfs/private > /dev/null; then
        echo_ /srv/nfs/private is busy, trying to kill processes...
        kill_processes

        # retry after killing processes
        if ! umount -f /srv/nfs/private > /dev/null; then
          systemctl start nfs-server
          exit 1
        else
          echo_ Successfully killed and unmounted /srv/nfs/private
        fi
      fi
      systemctl start nfs-server
    fi
  fi

  if mountpoint mount > /dev/null; then
    # try to umount actual data
    if ! umount -f mount > /dev/null; then
      echo_ Private space is busy, trying to kill processes...
      kill_processes

      # retry after killing processes
      while ! umount -f mount > /dev/null; do
        # notify user
        if ! [ -z $PRIVATE_SPACE_TELEGRAM ]; then
          echo_ "Failed to forcibly umount private space, need some assistance..." | /home/$PRIVATE_SPACE_USER/bin/telegram-notify
          break
        else
          sleep 60
        fi
      done
    fi
  fi

  if [ -e /dev/mapper/private_space ]; then
    if ! cryptsetup close private_space; then
      echo_ "Failed to close luks private partition, need some assistance..." | sudo -u $PRIVATE_SPACE_USER /home/$PRIVATE_SPACE_USER/bin/telegram-notify
    fi
  fi

  if ! [ -z $PRIVATE_SPACE_SMB ]; then 
    systemctl start smb
  fi
}

function ctrl_c(){
  echo
  echo_ Interrupt signal received, unmounting now.
  actual_umount
  echo_ Done
  exit 0
}

trap ctrl_c INT
if ! [ -z $PRIVATE_SPACE_AUTO_SUSPEND ]; then
  echo_ "Override autosuspend for requested timeout"
  echo $timeout > /var/auto_suspend/override
fi

echo_ "Sleeping for $timeout seconds... (press ^C to unmount now)"
sleep $timeout

actual_umount




echo_ -o 32 Done
