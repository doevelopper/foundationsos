#!/bin/sh
# boot.cmd — U-Boot boot script for FoundationsOS RPi5
#
# Implements RAUC A/B slot selection using U-Boot environment variables.
# Compile with:
#   mkimage -C none -A arm64 -T script -d boot.cmd boot.scr
#
# RAUC sets rauc_slot_a / rauc_slot_b boot order and boot counts.
# U-Boot decrements the boot count; if it reaches 0 the slot is marked bad
# and the other slot is tried. On successful boot RAUC marks the slot good.

# ─── Default boot arguments ───────────────────────────────────────────────────
setenv bootargs_common "console=ttyAMA10,115200 console=tty1 rootfstype=ext4 rootwait ro quiet loglevel=3 ima_policy=tcb ima_appraise=enforce apparmor=1 security=apparmor systemd.unified_cgroup_hierarchy=1 cgroup_memory=1 cgroup_enable=memory"

# ─── Slot selection ───────────────────────────────────────────────────────────
if test "${rauc_slot}" = "b"; then
    setenv rootpart 3
    setenv slot_bootname "b"
else
    setenv rootpart 2
    setenv slot_bootname "a"
fi

setenv bootargs "${bootargs_common} root=/dev/mmcblk0p${rootpart} rauc.slot=${slot_bootname}"

# ─── Boot counter (rollback safety) ───────────────────────────────────────────
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

# ─── Load and boot kernel ─────────────────────────────────────────────────────
setenv fdt_addr    0x02600000
setenv kernel_addr 0x00480000

echo "FoundationsOS: booting slot ${rauc_slot} (rootfs p${rootpart})"

# Load DTB and kernel Image from FAT boot partition (mmcblk0p1)
fatload mmc 0:1 ${fdt_addr}    bcm2712-rpi-5-b.dtb
fatload mmc 0:1 ${kernel_addr} Image

booti ${kernel_addr} - ${fdt_addr}
