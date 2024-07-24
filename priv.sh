#!/bin/zsh

source /usr/lib/priv/colors.sh

PREFIX=/usr/lib/priv
OPERAND=$1

function usage() {
    echo "Usage: priv [OPTIONS] COMMAND"
    echo
    echo "Available commands:"
    echo "	init	initializes a new private space"
    echo "	grow	grows the current private space"
    echo "	mount	mounts the private space (unmanaged)"
    echo "	spawn	spawns the private space (managed, interactive)"
    echo
    echo "Available options:"
    echo
}

if [[ -z $OPERAND ]]; then
    echo_ -o 31 missing command
    usage
    exit 1
fi

case $OPERAND in
    init)
	$PREFIX/init.sh ${@:2}
	;;
    grow)
	$PREFIX/grow.sh ${@:2}
	;;
    mount)
	$PREFIX/mount.sh ${@:2}
	;;
    spawn)
	if screen -list | grep -E '.priv\s' > /dev/null 2>&1; then
	    echo Instance already runnig, reattaching...
	    screen -r priv
	else
	    screen -S priv sudo -E priv mount
	fi
	;;
    *)
	echo_ -o 31 invalid argument: $OPERAND
	usage
	;;
esac

