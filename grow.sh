#!/bin/zsh

PREFIX=/usr/lib/priv
source $PREFIX/colors.sh
source $PREFIX/conf.sh

if mountpoint -q $PRIV_MOUNT || [[ -b /dev/mapper/$PRIV_DEVICE ]]; then
    red "Please unmount storage and close mapping before using this script!"
    exit 1
fi

if [[ $UID -ne 0 ]]; then
    red "Root access is needed"
    exit -1
fi

function usage() {
    echo "Usage: priv grow SIZE"
    echo "  SIZE      blocks of 1 MB"
}

if [[ -z $1 ]]; then
    red "missing size argument"
    usage
    exit 1
elif [[ $size =~ ^[0-9]+$ ]]; then
    red "invalid size argument: must be a valid positive integer"
    usage
    exit 1
else
    size=$1
fi

blue "We are trying to execute this possibly destructive command!"
red "    dd if=/dev/zero bs=1M count=$size >> $PRIV_STORAGE"
bluen "Proceed? (y/N) "
if read -q; then
    echo
    blue "  --> Appending zeros to image file..."
    if ! dd if=/dev/zero bs=1M count=$size status=progress >> $PRIV_STORAGE; then
        red "  --> dd failed, exiting."
	exit 3
    fi
else
    echo
    red "  --> Aborted."
    exit 4
fi

blue "Opening private space..."

if ! [[ -b /dev/mapper/$PRIV_DEVICE ]]; then
  if ! cryptsetup open --key-file $PRIV_KEY_FILE $PRIV_STORAGE $PRIV_DEVICE; then
    red "  --> Failed to open /dev/mapper/$PRIV_DEVICE!"
  	exit 2
  fi
else
    blue "  --> /dev/mapper/$PRIV_DEVICE already open"
fi

blue "Checking filesystem..."

if e2fsck -f /dev/mapper/$PRIV_DEVICE; then
    green "  --> Done"
else
    red "  --> Filesystem checking failed."
    exit 5
fi

blue "Actual resize..."

if resize2fs /dev/mapper/$PRIV_DEVICE; then
    green "  --> Done"
else
    red "  --> Failed!"
fi

bluen "Closing mapping..."
cryptsetup close $PRIV_DEVICE 
greenc " Done"
