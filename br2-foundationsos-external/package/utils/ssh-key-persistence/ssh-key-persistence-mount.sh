#!/bin/sh
set -e -x
mkdir -p /mnt/persist/etc/ssh
mount -o bind /mnt/persist/etc/ssh /etc/ssh
