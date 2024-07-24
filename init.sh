#!/bin/zsh

PREFIX=/usr/lib/priv
source $PREFIX/colors.sh
source $PREFIX/conf.sh

if [ $UID != 0 ]; then
  red Root access needed.
  exit 1
fi

blue Checking cryptsetupt support...
if cryptsetup -v > /dev/null 2>&1; then
  redc "  --> Failed"
  red "No support for luks. Cannot continue"
  exit 1
else
  green "  --> luks is supported"
fi

bluen "Creating mountpoints..."
if mkdir -p $PRIV_MOUNT; then
    greenc " OK"
else
    redc " FAILED"
    exit 1
fi

blue "Checking for key..."
if [ -e $PRIV_KEY_FILE ]; then
    bluen "Key at $PRIV_KEY_FILE already exists. Continue with already existing key? "
    if ! read -q; then
	echo
	red "WARNING: file at $PRIV_KEY_FILE already exists!"
	red "Cowardly refusing to overwrite key file."
	yellow "Please delete $PRIV_KEY_FILE or change PRIV_KEY_FILE options in /etc/priv.conf before continuing"
	exit 1
    else
	echo
    fi
else
    echo
    bluen "Generating key..."
    sudo dd if=/dev/urandom of=$PRIV_KEY_FILE bs=1K count=4 2> /dev/null
    sudo chmod 400 $PRIV_KEY_FILE
    greenc " OK"
fi

if ! mkdir -p "$(dirname $PRIV_STORAGE)"; then
    red "Failed to create $(dirname $PRIV_STORAGE)"
    exit 1
fi

while ! [[ $size =~ ^[0-9]+$ ]]; do 
    bluen "Creating storage image. Insert the size of raw storage (in MBs) "
    read size
done

blue "We are trying to execute this potentially destructive command!"
red    "    sudo truncate --size=${size}M $PRIV_STORAGE"
if [ -e $PRIV_STORAGE ]; then
    yellow "    WARNING: $PRIV_STORAGE already exists!"
fi
bluen "Proceed? (y/N) "
if read -q; then
  echo
  if ! sudo truncate --size=${size}M $PRIV_STORAGE; then
    red "  --> FAILED"
    exit 1
  fi
  sudo chmod 700 $PRIV_STORAGE
else
  red "  --> Aborted"
  exit 1
fi
green "  --> OK"

blue "Formatting $PRIV_STORAGE into luks filesystem..."
if ! sudo cryptsetup luksFormat -q $PRIV_STORAGE $PRIV_KEY_FILE; then
  red "  --> FAILURE"
  exit 1
fi
green "  --> OK"

if [ -e /dev/mapper/$PRIV_DEVICE ]; then
    yellow "/dev/mapper/$PRIV_DEVICE: file exists"
    if dmsetup ls --target crypt | grep -q $PRIV_DEVICE; then
	bluen "mapping is a dm-crypt device, close it? "
	if read -q; then
	    echo
	    cryptsetup close $PRIV_DEVICE 
	else
	    echo
	    red "cannot continue without closing /dev/mapper/$PRIV_DEVICE"
	    exit 1
	fi
    else
	red "mapping is not dm-crypt: cannot continue"
	exit 1
    fi
fi

blue "Opening image..."
if ! sudo cryptsetup open --key-file $PRIV_KEY_FILE $PRIV_STORAGE $PRIV_DEVICE; then
  red "  --> FAILURE"
  exit 1
fi
green "  --> OK"

blue "Formatting image ext4..."
if ! sudo mkfs.ext4 -F /dev/mapper/$PRIV_DEVICE; then
  red "  --> FAILURE"
  exit 1
fi
green "  --> OK"

blue "Setup completed successfully! Closing mapping..."
sudo cryptsetup close $PRIV_DEVICE 
green "  --> OK"

