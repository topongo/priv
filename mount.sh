#!/bin/zsh

PREFIX=/usr/lib/priv
PIDFILE=/run/priv.pid
source $PREFIX/colors.sh
source $PREFIX/conf.sh

if [[ -f $PIDFILE ]] && kill -0 $(cat $PIDFILE) 2> /dev/null; then
  red "Other instance already running, exiting."
  sleep 3
  exit 2
fi

echo $$ > $PIDFILE

if [ $UID != 0 ]; then
  red Root access needed.
  exit 1
fi

if [ -b /dev/mapper/$PRIV_DEVICE ]; then
  bluen "Storage already open"
  if mountpoint -q $PRIV_MOUNT; then
    bluec " and mounted"
  else
    bluec " but not mounted, mounting..."
    mount /dev/mapper/$PRIV_DEVICE $PRIV_MOUNT
  fi
else
  bluen "Opening data image... "
  cryptsetup open --key-file $PRIV_KEY_FILE $PRIV_STORAGE $PRIV_DEVICE
  if mount /dev/mapper/$PRIV_DEVICE $PRIV_MOUNT; then 
    greenc "OK!"
  else
    redc "FAIL!"
    red "Failed to mount image, exiting..."
    sleep 3
    exit 1
  fi
fi
	
if ! [ -z $PRIV_NFS ]; then
    if ! mountpoint $PRIV_NFS > /dev/null; then
      bluen "NFS binding not mounted, mounting now... "
      if mount -B $PRIV_MOUNT $PRIV_NFS; then
	greenc "OK!"
      else
	redc "FAILED!"
	red "Failed to bind nfs, exiting..."
	sleep 3
	exit 1
      fi
    fi
fi

blue Starting umount daemon
/usr/lib/priv/umount.sh $1 &
UMOUNT_PID=$!
echo $UMOUNT_PID > /run/privu.pid

function k(){
  echo
  blue "Killed umount daemon"
  kill -SIGKILL $UMOUNT_PID
}

function ctrl_c(){
  echo
  red Received SIGINT
  blue "Waiting for umount daemon to exit... (send ^C to kill chid)"
  trap k INT
  while kill -0 $UMOUNT_PID 2> /dev/null; do
      sleep 1;
  done
  blue "Umount daemon exited, exiting."
  sleep 3
  exit 0
}

trap ctrl_c INT

blue "(SIGINT trapped, press ^C to send signal to child)"

sleep 3
blue "Umount damon started, detaching..."

PRIV_USER=$(getent passwd $PRIV_USER | cut -d: -f1)
if echo "$STY" | grep priv > /dev/null; then
  sudo -u $PRIV_USER screen -d $STY
else
  yellow "Not in a screen session, remaining attached."
fi

while kill -0 $UMOUNT_PID 2> /dev/null; do
    sleep 1
done

blue Umount daemon exited, exiting.
sleep 3
