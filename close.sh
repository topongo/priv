#!/bin/zsh

PREFIX=/usr/lib/priv
source $PREFIX/colors.sh
source $PREFIX/conf.sh
source $PREFIX/kill.sh

if [ $UID != 0 ]; then
  red Root access needed.
  exit 1
fi

[ -f /run/priv.pid ]  && MPID=$(cat /run/priv.pid)
[ -f /run/privu.pid ] && UPID=$(cat /run/privu.pid)

if ! [ -z $MPID ] && kill -0 $MPID 2> /dev/null; then
    if ! [ -z $UPID ] && kill -0 $UPID 2> /dev/null; then
	blue "sending SIGINT to umount daemon..."
	kill -SIGINT $UPID
	blue "waiting it to exit..."
	while kill -0 $UPID 2> /dev/null; do
	    sleep 1
	done
    else
	blue "sending SIGINT to mount daemon..."
	kill -SIGINT $MPID
    fi
    blue "waiting for mount daemon to exit..."
    while kill -0 $MPID 2> /dev/null; do
	sleep 1
    done
fi

if ! [ -z $PRIV_NFS ] && mountpoint -q $PRIV_NFS; then
    blue "killing processes and umounting $PRIV_NFS..."
    kill_processes
    systemctl stop nfs-server
    if ! umount $PRIV_NFS; then
	red "could not umount nfs: $PRIV_NFS"
	systemctl start nfs-server
	exit 1
    else
	green "    --> Ok"
    fi
fi

if mountpoint -q $PRIV_MOUNT; then
    blue "priv is mounted, killing pending processes..."
    kill_processes
    blue "unmounting $PRIV_MOUNT... "
    if ! umount $PRIV_MOUNT; then
	red "    --> FAIL"
	red "could not umount: $PRIV_MOUNT"
	exit 1
    else
	green "    --> OK"
    fi
else
    blue "priv is not mounted"
fi

if dmsetup ls --target crypt | grep -q $PRIV_DEVICE; then
    blue "closing mapping..."
    if ! cryptsetup close $PRIV_DEVICE; then
	red "    --> FAIL"
	red "could not close mapping"
	exit 1
    else
	green "    --> OK"
    fi
else
    blue "mapping isn't open"
fi

blue Done

