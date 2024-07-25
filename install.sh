#!/bin/zsh

source colors.sh

if [ $UID != 0 ]; then
  echo_ -o 31 Root access needed.
  exit 1
fi


[[ -z $PREFIX ]] && PREFIX=/usr

install -Dm 644 colors.sh conf.sh kill.sh --target-directory $PREFIX/lib/priv
install -Dm 755 init.sh grow.sh mount.sh umount.sh close.sh --target-directory $PREFIX/lib/priv
install -Dm 755 priv.sh $PREFIX/bin/priv

if [ -z PRIV_INSTALL_SKIP_CONF ] && ! [[ -e /etc/priv.conf ]]; then
    install -m 755 priv.conf /etc/priv.conf
fi
