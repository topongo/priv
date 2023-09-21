#!/bin/zs

cd $(dirname $0)

source configs.sh
source colors.sh

if [[ -f pid ]] && kill -0 $(cat pid) 2> /dev/null; then
  echo_ -o 31 "Other instance already running, exiting."
  sleep 3
  exit 2
fi

echo $$ > pid

if [ $UID != 0 ]; then
  echo_ -o 31 Root access needed.
  exit 1
fi

if [ -b /dev/mapper/private_space ]; then
  echo_ -n "Storage already open"
  if mountpoint -q mount; then
    echo_ -c " and mounted"
  else
    echo_ -c " but not mounted, mounting..."
    mount /dev/mapper/private_space mount
  fi
else
  echo_ -n "Opening data image... "
  cryptsetup open --key-file $PRIVATE_SPACE_KEY storage.img private_space
  if mount /dev/mapper/private_space mount; then 
    echo_ -co 32 "OK!"
  else
    echo_ -co 31 "FAIL!"
    echo_ -o 31 "Failed to mount image, exiting..."
    sleep 3
    exit 1
  fi
fi

if ! mountpoint /srv/nfs/private > /dev/null; then
  echo_ -n "NFS binding not mounted, mounting now... "
  if mount -B mount /srv/nfs/private; then
    echo_ -co 32 "OK!"
  else
    echo_ -co 31 "FAILED!"
    echo_ -o 31 "Failed to bind nfs, exiting..."
    sleep 3
    exit 1
  fi
fi

echo_ Starting umount daemon
./umount.sh $1 &
UMOUNT_PID=$!

function k(){
  echo
  echo_ "Killed umount daemon"
  kill -SIGKILL $UMOUNT_PID
}

function ctrl_c(){
  echo
  echo_ -o 31 Received SIGINT
  echo_ "Waiting for umount daemon to exit... (send ^C to kill chid)"
  trap k INT
  tail --pid=$UMOUNT_PID -f /dev/null
  echo_ "Umount daemon exited, exiting."
  sleep 3
  exit 0
}

trap ctrl_c INT

echo_ "(SIGINT trapped, press ^C to send signal to child)"

sleep 3
echo_ "Umount damon started, detaching..."

if echo "$STY" | grep private > /dev/null; then
  sudo -u $PRIVATE_SPACE_USER screen -d "$STY"
else
  echo_ -o 33 "Not in a screen session, remaining attached."
fi

tail --pid=$UMOUNT_PID -f /dev/null

echo_ Umount daemon exited, exiting.
sleep 3
