#!/bin/zsh

PREFIX=/usr/lib/priv
source $PREFIX/colors.sh
source $PREFIX/conf.sh

if [ $UID != 0 ]; then
  blue Root access needed.
  exit 1
fi

if ! [[ "$1" =~ '^[0-9]+$' ]] ; then
  timeout=$((60 * 60))
else
  timeout=$(($1 * 60))
fi

function kill_processes() {
  if ! [ -z $PRIV_SMB ]; then
    processes=$(lsof /srv/nfs/private | grep -v PID | awk '{print $2}' | paste -s -d' ')
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
   lsof mount | grep -v PID | awk '{print $2}' | xargs kill -9
  fi
}

function actual_umount(){
  if ! [ -z $PRIV_AUTOSUSPEND ]; then
    echo x > /var/auto_suspend/override_c
    blue "Override cancelled for auto_suspend"
  fi

  if ! [ -z $PRIV_NFS ]; then
    # check if nfs binding is actually mounted
    if mountpoint /srv/nfs/private > /dev/null; then
      # try to umount nfs binding
      systemctl stop nfs-server
      if ! umount -f /srv/nfs/private > /dev/null; then
        blue /srv/nfs/private is busy, trying to kill processes...
        kill_processes

        # retry after killing processes
        if ! umount -f /srv/nfs/private > /dev/null; then
          curl https://ntfy.sh/$PRIV_NTFY -H 'Priority: high' -d "Failed to umount priv nfs, need user intervention"	  
          systemctl start nfs-server
          exit 1
        else
          blue Successfully killed and unmounted /srv/nfs/private
        fi
      fi
      # restart nfs
      systemctl start nfs-server
    fi
  fi

  if mountpoint $PRIV_MOUNT > /dev/null; then
    # try to umount actual data
    if ! umount -f $PRIV_MOUNT > /dev/null; then
      blue Private space is busy, trying to kill processes...
      kill_processes

      # retry after killing processes
      while ! umount -f $PRIV_MOUNT > /dev/null; do
        # notify user
        if ! [ -z $PRIV_NTFY ]; then
          curl https://ntfy.sh/$PRIV_NTFY -H 'Priority: high' -d "Failed to umount priv, need user intervention"
          break
        else
          sleep 60
        fi
      done
    fi
  fi

  if [ -e /dev/mapper/$PRIV_DEVICE ]; then
    if ! cryptsetup close $PRIV_DEVICE; then
      curl https://ntfy.sh/$PRIV_NTFY -H 'Priority: high' -d "Failed to close priv, need user intervention"
    fi
  fi

  if ! [ -z $PRIV_SMB ]; then 
    systemctl start smb
  fi
}

function ctrl_c(){
  echo
  blue Interrupt signal received, unmounting now.
  actual_umount
  blue Done
  exit 0
}

trap ctrl_c INT
if ! [ -z $PRIV_AUTOSUSPEND ]; then
  blue "Override autosuspend for requested timeout"
  echo $timeout > /var/auto_suspend/override
fi

blue "Sleeping for $timeout seconds... (press ^C to unmount now)"
sleep $timeout

actual_umount




green Done
