#!/bin/sh

set -e
set -x

echo "PSense Linux uninstaller script"
systemctl stop psense
systemctl disable psense
systemctl disable psense-sleep
rm -f /etc/systemd/system/psense*

if [ -d /opt/psense ]; then
    rm -rf /opt/psense
fi

systemctl daemon-reload
