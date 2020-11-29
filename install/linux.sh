#!/bin/sh

set -e
set -x

echo "PSense Linux installer script"
if [ ! -d /opt/psense/bin ]; then
    mkdir -p /opt/psense/bin
fi

if [ ! -d /opt/psense/etc ]; then
    mkdir -p /opt/psense/etc
fi

cp -f ./psense /opt/psense/bin/
cp -f ./psensepkg/cli/psensectl /opt/psense/bin/
cp -f ./config.yaml /opt/psense/etc/
cp -f ./service/systemd/* /etc/systemd/system/

systemctl daemon-reload
systemctl enable psense --now
systemctl enable psense-sleep
