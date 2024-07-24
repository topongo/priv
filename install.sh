#!/bin/zsh

source colors.sh

if [ $UID != 0 ]; then
  echo_ -o 31 Root access needed.
  exit 1
fi

PREFIX=/usr/lib/priv

install -dm 755 $PREFIX
install -m 755 init.sh grow.sh mount.sh umount.sh colors.sh conf.sh --target-directory $PREFIX
install -m 755 priv.sh /usr/bin/priv

if ! [[ -e /etc/priv.conf ]]; then
    install -m 755 priv.conf /etc/priv.conf
fi
