#!/bin/sh
# boot.cmd — U-Boot boot script for FoundationsOS RPi5
#
# v0.3.0: Adds TPM 2.0 measured boot.
# - TPM is started in clear mode (if not already started by TF-A/OP-TEE).
# - U-Boot CONFIG_MEASURED_BOOT automatically extends PCR[0/4/5/7] for each
#   loaded image via the TCG2 event log interface.
# - Additional explicit PCR[8] extension records the active RAUC slot choice
#   so attestation can bind to the exact rootfs that was booted.
#
# Compile with:
#   mkimage -C none -A arm64 -T script -d boot.cmd boot.scr

# ─── TPM 2.0 startup ─────────────────────────────────────────────────────────
# TF-A/OP-TEE may have already called TPM2_CC_Startup. If so, tpm2 startup
# returns an error which we silently ignore; PCR state is preserved.
if tpm2 startup TPM2_SU_CLEAR; then
    echo "TPM2: started (clear mode)"
else
    echo "TPM2: already started or no TPM present"
fi

# ─── Default boot arguments ───────────────────────────────────────────────────
setenv bootargs_common "console=ttyAMA10,115200 console=tty1 rootfstype=ext4 rootwait ro quiet loglevel=3 panic=5 ima_policy=tcb ima_appraise=enforce apparmor=1 security=apparmor systemd.unified_cgroup_hierarchy=1 cgroup_memory=1 cgroup_enable=memory"

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

fatload mmc 0:1 ${fdt_addr}    bcm2712-rpi-5-b.dtb
fatload mmc 0:1 ${kernel_addr} Image

# ─── Measured boot: extend PCR[8] with active slot name ─────────────────────
# PCR[8] is reserved for boot-time platform firmware data.  We record the
# RAUC slot name so a TPM quote can prove which rootfs image was booted.
# U-Boot CONFIG_MEASURED_BOOT already handles PCR[4]=kernel PCR[7]=dtb.
if test "${tpm_started}" = "1"; then
    tpm2 pcr_extend 8 sha256 ${rauc_slot}
    echo "TPM2: PCR[8] extended with slot=${rauc_slot}"
fi

booti ${kernel_addr} - ${fdt_addr}
