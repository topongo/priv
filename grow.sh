#!/bin/zsh

cd $(dirname $0)

source configs.sh
source colors.sh

if mountpoint -q mount || [[ -b /dev/mapper/private_space ]]; then
    echo_ -31 "Please unmount storage and close mapping before using this script!"
    exit 1
fi

if [[ $UID -ne 0 ]]; then
    echo_ -31 "Root access is needed"
    exit -1
fi

function usage() {
    echo "Usage: grow.sh SIZE"
    echo
    echo "  SIZE      blocks of 1 MB"
}

if [[ -z $1 ]]; then
    echo_ -o 31 "Missing [size] argument!"
    usage
    exit 1
else
    size=$1
fi

echo_ "We are trying to execute this possibly destructive command!"
echo_ -o 31 "    dd if=/dev/zero bs=1M count=$size >> storage.img"
echo_ -n "Proceed? (y/N) "
if read -q; then
    echo
    echo_ "  --> Appending zeros to image file..."
    if ! dd if=/dev/zero bs=1M count=$size status=progress >> storage.img; then
        echo_ -o 31 "  --> dd failed, exiting."
	exit 3
    fi
else
    echo
    echo_ -o 31 "  --> Aborted."
    exit 4
fi

echo_ "Opening private space..."

if ! [[ -b /dev/mapper/private_space ]]; then
  if ! cryptsetup open --key-file $PRIVATE_SPACE_KEY storage.img private_space; then
    echo_ -o 31 "  --> Failed to open private space!"
  	exit 2
  fi
else
    echo_ "  --> Private space already open"
fi

echo_ "Checking filesystem..."

if e2fsck -f /dev/mapper/private_space; then
    echo_ -o 32 "  --> Done"
else
    echo_ -o 31 "  --> Filesystem checking failed."
    exit 5
fi

echo_ "Actual resize..."

if resize2fs /dev/mapper/private_space; then
    echo_ -o 32 "  --> Done"
else
    echo_ -o 31 "  --> Failed!"
fi

echo_ "Closing mapping..."
cryptsetup close private_space
echo_ -o 32 "Done"
