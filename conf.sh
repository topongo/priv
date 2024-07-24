#!/bin/zsh

if ! source /etc/priv.conf; then
    red /etc/priv.conf is malformed
    exit 1
else
    local ERR
    [ -z $PRIV_KEY_FILE ]    && ERR="PRIV_KEY_FILE "
    [ -z $PRIV_STORAGE ]     && ERR="${ERR}PRIV_STORAGE "
    [ -z $PRIV_USER ]        && PRIV_USER=1000
    [ -z $PRIV_MOUNT ]       && ERR="${ERR}PRIV_MOUNT "
    [ -z $PRIV_DEVICE ]      && PRIV_DEVICE=priv
    if [ -z $PRIV_NFS ] || [[ $PRIV_NFS = false ]]; then
	PRIV_NFS=
    fi
    if [ -z $PRIV_SAMBA ] || [[ $PRIV_SAMBA = false ]]; then
	PRIV_SAMBA=
    fi
    if [ -z $PRIV_AUTOSUSPEND ] || [[ $PRIV_AUTOSUSPEND = false ]]; then 
	PRIV_AUTOSUSPEND=
    fi

    if ! [ -z $ERR ]; then
	red Incomplete configuration: this parameter must be set:
	yellow "    $ERR" 
	exit 1
    fi
fi
