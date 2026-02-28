#!/bin/sh
# boot.cmd — U-Boot boot script for FoundationsOS RPi3B+
#
# v0.4.0: Standard RAUC U-Boot integration (BOOT_ORDER / BOOT_x_LEFT).
# v0.3.0: TPM 2.0 measured boot.
#
# Compile with:
#   mkimage -C none -A arm64 -T script -d boot.cmd boot.scr

# ─── TPM 2.0 startup ─────────────────────────────────────────────────────────
if tpm2 startup TPM2_SU_CLEAR; then
    setenv tpm_started 1
    echo "TPM2: started (clear mode)"
else
    setenv tpm_started 0
    echo "TPM2: already started or no TPM present"
fi

# ─── RAUC A/B slot selection (standard RAUC U-Boot variables) ────────────────
if test "${BOOT_ORDER}" = ""; then setenv BOOT_ORDER "A B"; fi
if test "${BOOT_A_LEFT}" = ""; then setenv BOOT_A_LEFT 3; fi
if test "${BOOT_B_LEFT}" = ""; then setenv BOOT_B_LEFT 3; fi

setenv rauc_slot ""
setenv rootpart ""

if test "${BOOT_ORDER}" != "B A"; then
    # A-first (normal / stable): try A, fall back to B
    if test ${BOOT_A_LEFT} -gt 0; then
        setexpr BOOT_A_LEFT ${BOOT_A_LEFT} - 1
        setenv rauc_slot a
        setenv rootpart 2
    elif test ${BOOT_B_LEFT} -gt 0; then
        setexpr BOOT_B_LEFT ${BOOT_B_LEFT} - 1
        setenv rauc_slot b
        setenv rootpart 3
    fi
else
    # B-first (post-update): try B, fall back to A
    if test ${BOOT_B_LEFT} -gt 0; then
        setexpr BOOT_B_LEFT ${BOOT_B_LEFT} - 1
        setenv rauc_slot b
        setenv rootpart 3
    elif test ${BOOT_A_LEFT} -gt 0; then
        setexpr BOOT_A_LEFT ${BOOT_A_LEFT} - 1
        setenv rauc_slot a
        setenv rootpart 2
    fi
fi

saveenv

if test "${rauc_slot}" = ""; then
    echo "RAUC: All slots exhausted — system unbootable. Resetting."
    reset
fi

# ─── Boot arguments ───────────────────────────────────────────────────────────
setenv bootargs "console=serial0,115200 console=tty1 rootfstype=ext4 rootwait ro quiet loglevel=1 panic=5 ima_policy=tcb ima_appraise=enforce apparmor=1 security=apparmor systemd.unified_cgroup_hierarchy=1 cgroup_memory=1 cgroup_enable=memory slub_debug=FZP init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 randomize_kstack_offset=on slab_nomerge lockdown=integrity root=/dev/mmcblk0p${rootpart} rauc.slot=${rauc_slot}"

# ─── Load kernel and DTB ─────────────────────────────────────────────────────
setenv fdt_addr    0x02600000
setenv kernel_addr 0x00480000

echo "FoundationsOS: booting slot ${rauc_slot} (rootfs p${rootpart})"
echo "               BOOT_A_LEFT=${BOOT_A_LEFT} BOOT_B_LEFT=${BOOT_B_LEFT}"

fatload mmc 0:1 ${fdt_addr}    bcm2837-rpi-3-b-plus.dtb
fatload mmc 0:1 ${kernel_addr} Image

# ─── Measured boot: extend PCR[8] with active slot name ─────────────────────
if test "${tpm_started}" = "1"; then
    tpm2 pcr_extend 8 sha256 ${rauc_slot}
    echo "TPM2: PCR[8] extended with slot=${rauc_slot}"
fi

booti ${kernel_addr} - ${fdt_addr}
