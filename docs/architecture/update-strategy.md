# Update Strategy

## Overview

FoundationsOS uses [RAUC](https://rauc.io/) for robust, atomic, cryptographically verified over-the-air (OTA) updates using an **A/B (redundant) slot** strategy.

---

## A/B Slot Strategy

```
┌──────────┬────────────┬────────────┬──────────┐
│  boot    │ rootfs_a   │ rootfs_b   │  data    │
│ (p1)     │ (p2) ACTIVE│ (p3) SPARE │ (p4)     │
└──────────┴────────────┴────────────┴──────────┘
                 ▲                ▼
           Currently         Updated here
           running           while system
                             is running
```

1. Device boots from the **active** slot (A or B).
2. RAUC writes the new bundle to the **inactive** slot.
3. After verification, RAUC marks the inactive slot as the next boot target.
4. On next reboot, U-Boot boots from the new slot.
5. If the new slot boots successfully, it is marked **good**; otherwise U-Boot rolls back.

---

## Bundle Format

RAUC bundles are:
- **Signed** with an offline ECDSA P-521 key
- **Verified** on-device against `/etc/rauc/ca.cert.pem`
- **Verity-protected** (dm-verity hash tree in the bundle)

```
foundationsos-v1.2.0.raucb
├── manifest.raucm   (signed metadata)
├── rootfs.img.verity
└── boot.tar
```

---

## Building and Deploying an Update Bundle

```bash
# 1. Build the bundle
make rauc-bundle

# 2. Transfer to device (example over SCP)
scp output/images/foundationsos-v1.2.0.raucb root@device:/tmp/

# 3. On the device — install the bundle
rauc install /tmp/foundationsos-v1.2.0.raucb

# 4. Reboot to apply
systemctl reboot
```

---

## Rollback

If the new slot fails to boot (e.g., kernel panic, watchdog timeout), U-Boot automatically reverts to the previously good slot. The failed slot is marked `bad` and will not be selected again until explicitly cleared.
