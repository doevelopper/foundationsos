#!/bin/sh
# boot.cmd — U-Boot boot script for FoundationsOS RPi3B+
#
# Implements RAUC A/B slot selection using U-Boot environment variables.
# Compile with:
#   mkimage -C none -A arm64 -T script -d boot.cmd boot.scr

setenv bootargs_common "console=serial0,115200 console=tty1 rootfstype=ext4 rootwait ro quiet loglevel=3 ima_policy=tcb ima_appraise=enforce apparmor=1 security=apparmor systemd.unified_cgroup_hierarchy=1 cgroup_memory=1 cgroup_enable=memory"

if test "${rauc_slot}" = "b"; then
    setenv rootpart 3
    setenv slot_bootname "b"
else
    setenv rootpart 2
    setenv slot_bootname "a"
fi

setenv bootargs "${bootargs_common} root=/dev/mmcblk0p${rootpart} rauc.slot=${slot_bootname}"

if test -z "${bootcount}"; then
    setenv bootcount 0
fi
setexpr bootcount ${bootcount} + 1
if test "${bootcount}" -ge "${bootlimit}"; then
    echo "Boot limit reached on slot ${slot_bootname}, switching slot..."
    if test "${rauc_slot}" = "b"; then
        setenv rauc_slot "a"
        setenv rootpart 2
    else
        setenv rauc_slot "b"
        setenv rootpart 3
    fi
    setenv bootcount 0
    saveenv
    setenv bootargs "${bootargs_common} root=/dev/mmcblk0p${rootpart} rauc.slot=${rauc_slot}"
fi
saveenv

setenv fdt_addr    0x02600000
setenv kernel_addr 0x00480000

echo "FoundationsOS: booting slot ${rauc_slot} (rootfs p${rootpart})"

fatload mmc 0:1 ${fdt_addr}    bcm2837-rpi-3-b-plus.dtb
fatload mmc 0:1 ${kernel_addr} Image

booti ${kernel_addr} - ${fdt_addr}
