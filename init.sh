#!/bin/zsh

PRIVATE_SPACE_PATH=$(realpath $(dirname $0))
cd $PRIVATE_SPACE_PATH

if ! [ -f configs.sh ]; then
  cat configs.sh.default > configs.sh
  echo "PRIVATE_SPACE_PATH=$PRIVATE_SPACE_PATH" >> configs.sh
  echo "PRIVATE_SPACE_USER=$USER" >> configs.sh
fi

source configs.sh
source colors.sh

echo_ Checking cryptsetupt support...
if cryptsetup -v > /dev/null 2>&1; then
  echo_ -co 31 "  --> Failed"
  echo_ -o 31 "No support for luks. Cannot continue"
  exit 1
else
  echo_ -o 32 "  --> luks is supported"
fi

if ! systemctl list-unit-files | grep -q nfs-server; then
  echo_ -o 31 "  --> No support for nfs"
else
  echo_ -o 32 "  --> nfs is supported"
  echo_ -o 32 "  --> creating nfs mountpoint"
  sudo mkdir -p /srv/nfs/private
  echo "PRIVATE_SPACE_NFS=true" >> configs.sh
fi

if [ -d /var/auto_suspend ]; then
  echo "PRIVATE_SPACE_AUTO_SUSPEND=true" >> configs.sh
else
  echo_ -o 31 "  --> No support for auto_suspend"
fi

if ! systemctl list-unit-files | grep -q smb; then
  echo_ -o 31 "  --> No support for samba"
else
  echo_ -o 32 "  --> samba is supported"
  echo "PRIVATE_SPACE_SAMBA=true" >> configs.sh
fi

echo_ -n "Creating mountpoints..."
mkdir -p mount
echo_ -co 32 " OK"

echo_ -n "Creating storage image. Insert the size of raw storage (in MBs) "
read size
echo_ "We are trying to execute this potentially destructive command!"
echo_ -o 31 "     sudo truncate --size=$size storage.img"
echo_ -n "Proceed? (y/N) "
if read -q; then
  echo
  if ! sudo truncate --size=${size}MB storage.img; then
    echo_ -o 31 "  --> FAILED"
    exit 1
  fi
  sudo chmod 700 storage.img
else
  echo_ -o 31 "  --> Aborted"
  exit 1
fi
echo_ -o 32 " --> OK"

echo_ -n "Generating key-file..."
sudo dd if=/dev/urandom of=$PRIVATE_SPACE_KEY bs=1K count=4 2> /dev/null
sudo chmod 400 $PRIVATE_SPACE_KEY
echo_ -co 32 " OK"

echo_ "Formatting storage.img into luks filesystem..."
if ! sudo cryptsetup luksFormat -q storage.img $PRIVATE_SPACE_KEY; then
  echo_ -o 31 "  --> FAILURE"
  exit 1
fi
echo_ -o 32 "  --> OK"

echo_ "Opening image..."
if ! sudo cryptsetup open --key-file $PRIVATE_SPACE_KEY storage.img private_space; then
  echo_ -o 31 "  --> FAILURE"
  exit 1
fi
echo_ -o 32 "  --> OK"

echo_ "Formatting image ext4..."
if ! sudo mkfs.ext4 /dev/mapper/private_space; then
  echo_ -o 31 "  --> FAILURE"
  exit 1
fi
echo_ -o 32 "  --> OK"

echo_ -n "Creating spawn script..."
mkdir -p $(dirname $PRIVATE_SPACE_SPAWN)
cat spawn-private-partial > $PRIVATE_SPACE_SPAWN
echo -e "$PRIVATE_SPACE_PATH/mount.sh\nfi" >> $PRIVATE_SPACE_SPAWN
chmod +x $PRIVATE_SPACE_SPAWN
echo_ -co 32 " OK"

echo_ "Setup completed successfully! Closing..."
sudo cryptsetup close private_space
echo_ -o 32 "  --> OK"

