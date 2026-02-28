# ADR-0008: Use hawkBit as the OTA Management Backend

## Status

Accepted

## Context

FoundationsOS uses RAUC for on-device A/B update management. RAUC needs a
cloud connector to receive update notifications, download bundles, and report
installation status back to a fleet management server.

Several OTA connectors are available for RAUC:

| Connector | Protocol | Auth | Buildroot package | Notes |
|-----------|----------|------|-------------------|-------|
| **hawkBit** | HTTP/S REST | Token / TLS client cert | `rauc-hawkbit-updater` | Eclipse IoT project; active; self-hostable |
| SWUpdate suricatta | hawkBit / general | Token | Not in Buildroot | SWUpdate-centric; extra integration effort |
| Custom script | Any | Any | N/A | High maintenance; no standard protocol |
| RAUC D-Bus API (local only) | D-Bus | N/A | N/A | Manual trigger only; no cloud fleet management |

## Decision

Use **Eclipse hawkBit** as the OTA management server and the
**`rauc-hawkbit-updater`** client (`BR2_PACKAGE_RAUC_HAWKBIT_UPDATER=y`) as the
device-side connector.

## Rationale

1. **Eclipse IoT project**: hawkBit is mature, actively maintained, and widely
   used in embedded Linux fleet management.
2. **Self-hostable**: can run on-premises (official Docker image), avoiding
   cloud vendor lock-in.
3. **First-class RAUC support**: `rauc-hawkbit-updater` is the reference RAUC
   connector and is shipped in Buildroot upstream.
4. **Security**: supports TLS with server certificate verification and
   per-device auth tokens. Future v0.5.0 work will seal tokens to the TPM PCR
   policy established in v0.3.0.
5. **Simple auditability**: hawkBit uses a JSON REST API that is easy to audit,
   mock, and test without a live server.

## Update Slot Lifecycle

```
1. STEADY STATE
   BOOT_ORDER="A B"   BOOT_A_LEFT=3   BOOT_B_LEFT=3
   Slot A = booted (good).  Slot B = old.

2. UPDATE ARRIVES
   hawkBit → rauc-hawkbit-updater → rauc install foundationsos-rpi5-v0.4.1.raucb
   RAUC writes new rootfs to slot B.
   RAUC sets: BOOT_ORDER="B A"  BOOT_B_LEFT=3  (slot B = try-first)

3. REBOOT
   U-Boot reads BOOT_ORDER="B A", BOOT_B_LEFT=3
   → boots slot B, decrements BOOT_B_LEFT to 2, saves env.

4. SUCCESSFUL BOOT (slot B)
   rauc-mark-good.service (After=multi-user.target) runs:
     rauc status mark-good
   RAUC resets BOOT_B_LEFT=3 and permanently sets BOOT_ORDER="B A".
   rauc-hawkbit-updater reports status "installed" to hawkBit.

5. FAILED BOOT (slot B crashes 3 times)
   BOOT_B_LEFT reaches 0.
   U-Boot falls back to slot A (BOOT_A_LEFT > 0).
   Device is still operational on the last known-good firmware.
```

```
┌──────────────────┐  poll (60s)   ┌──────────────────────────┐
│  hawkBit Server  │◄──────────────│  rauc-hawkbit-updater    │
│                  │               │  /etc/rauc/hawkbit.conf  │
│  action: install │──────────────►│                          │
│                  │               │  rauc install <bundle>   │
│                  │               │         │                │
│                  │               │         ▼                │
│                  │               │    RAUC daemon           │
│                  │               │    writes slot B         │
│  feedback: ok    │◄──────────────│    sets BOOT_ORDER="B A" │
└──────────────────┘               └──────────────────────────┘
          ▲                                   │
          │  mark-good feedback               │ reboot
          │                                   ▼
          │                       ┌──────────────────────────┐
          │                       │  rauc-mark-good.service  │
          └───────────────────────│  rauc status mark-good   │
                                  └──────────────────────────┘
```

## hawkBit Device Configuration

Each device requires:

- **`target_name`**: unique device identifier (e.g. serial number from
  `/proc/cpuinfo` or TPM EK certificate CN)
- **`auth_token`**: device-specific token provisioned during manufacturing or
  first-boot setup. In v0.5.0+, this token will be unsealed from the TPM
  using the PCR policy established in v0.3.0.

The configuration file `/etc/rauc/hawkbit.conf` ships with placeholder values
and must be customised before deployment:

```ini
[client]
hawkbit_server           = hawkbit.example.com
ssl                      = true
ssl_verify               = true
auth_token               = REPLACE_WITH_DEVICE_TOKEN
target_name              = foundationsos-rpi5-REPLACE_WITH_SERIAL
bundle_download_location = /data/rauc-updates
```

## Security Considerations

- **Bundle verification**: RAUC always verifies the ECDSA-P521 bundle
  signature before applying an update, regardless of the download source.
  A compromised hawkBit server cannot push unsigned firmware.
- **Transport security**: `ssl=true` and `ssl_verify=true` are required in
  production. The device CA bundle must include the hawkBit server's
  certificate chain.
- **Token rotation**: device auth tokens should be rotated periodically.
  v0.5.0 will seal tokens to the TPM PCR[0,4,7,8] policy; a tampered
  firmware will be unable to unseal the token and therefore cannot contact
  the update server.
- **Rollback protection**: the `rauc-mark-good` + RAUC boot-count mechanism
  prevents a bad update from permanently bricking the device.
- **Bundle download location**: `/data/rauc-updates` is on the writable
  `/data` partition (4th partition). The `rauc-hawkbit-updater.service` unit
  is restricted to write only there (`ReadWritePaths=/data/rauc-updates`).

## Consequences

- **Positive**: production-grade OTA pipeline; rollback-safe; self-hostable;
  Buildroot-native package; extensible to TPM-based token sealing in v0.5.0.
- **Negative**: requires a hawkBit server for end-to-end testing;
  `rauc-hawkbit-updater` adds ~500 KiB to the image; device must have
  network access to poll for updates.
