#!/bin/sh

set -e
set -x

echo "PSense Linux installer script"

short=0
if [ ! -f "./configs/$1" ]; then
    if [ ! -f "./configs/$1" ]; then
        echo "Error: neither $1 or $1.yaml were fond in ./configs folder"
        exit 1
    else
        short=1
    fi
fi

if [ ! -d /opt/psense/bin ]; then
    mkdir -p /opt/psense/bin
fi

if [ ! -d /opt/psense/etc ]; then
    mkdir -p /opt/psense/etc
fi

if systemctl status psense 2>&1 1>/dev/null; then
    systemctl stop psense
fi

cp -f ./psense /opt/psense/bin/
cp -f ./psensepkg/cli/psensectl /opt/psense/bin/
if $short; then
    cp -f "./configs/$1.yaml" /opt/psense/etc/config.yaml
else
    cp -f "./configs/$1" /opt/psense/etc/config.yaml
fi

cp -f ./res/service/systemd/* /etc/systemd/system/

systemctl daemon-reload
systemctl enable psense --now
systemctl enable psense-sleep
