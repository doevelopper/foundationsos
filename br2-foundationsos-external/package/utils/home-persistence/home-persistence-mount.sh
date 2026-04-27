#!/bin/sh
set -e -x
mkdir -p /mnt/persist/root
mount -o bind /mnt/persist/root /root
mkdir -p /mnt/persist/home /home
mount -o bind /mnt/persist/home /home
