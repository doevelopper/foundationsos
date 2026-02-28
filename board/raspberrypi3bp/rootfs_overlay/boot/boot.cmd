#!/bin/sh
# boot.cmd — U-Boot boot script for FoundationsOS RPi3B+
#
# v0.3.0: Adds TPM 2.0 measured boot.
# U-Boot CONFIG_MEASURED_BOOT automatically extends PCR[0/4/5/7].
# PCR[8] is extended with the active RAUC slot for attestation.
#
# Compile with:
#   mkimage -C none -A arm64 -T script -d boot.cmd boot.scr

# ─── TPM 2.0 startup ─────────────────────────────────────────────────────────
if tpm2 startup TPM2_SU_CLEAR; then
    echo "TPM2: started (clear mode)"
    setenv tpm_started 1
else
    echo "TPM2: already started or no TPM present"
    setenv tpm_started 0
fi

# ─── Default boot arguments ───────────────────────────────────────────────────
setenv bootargs_common "console=serial0,115200 console=tty1 rootfstype=ext4 rootwait ro quiet loglevel=3 panic=5 ima_policy=tcb ima_appraise=enforce apparmor=1 security=apparmor systemd.unified_cgroup_hierarchy=1 cgroup_memory=1 cgroup_enable=memory"

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

# ─── Load kernel and DTB ─────────────────────────────────────────────────────
setenv fdt_addr    0x02600000
setenv kernel_addr 0x00480000

echo "FoundationsOS: booting slot ${rauc_slot} (rootfs p${rootpart})"

fatload mmc 0:1 ${fdt_addr}    bcm2837-rpi-3-b-plus.dtb
fatload mmc 0:1 ${kernel_addr} Image

# ─── Measured boot: extend PCR[8] with active slot name ─────────────────────
if test "${tpm_started}" = "1"; then
    tpm2 pcr_extend 8 sha256 ${rauc_slot}
    echo "TPM2: PCR[8] extended with slot=${rauc_slot}"
fi

booti ${kernel_addr} - ${fdt_addr}
