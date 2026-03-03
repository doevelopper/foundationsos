# RAUC Key Infrastructure

This directory contains **scripts and templates** for managing RAUC signing keys.

> ⚠️ **IMPORTANT**: Private keys (`*.key.pem`, `*.p12`) MUST **never** be committed to this repository.
> Only the public certificate (`ca.cert.pem`) is safe to commit.

---

## Directory Layout

```
keys/rauc/
├── README.md          ← This file
├── gen-keys.sh        ← Script to generate CA + signing key/cert
└── (generated files — NOT committed)
    ├── ca.key.pem     ← CA private key (OFFLINE — never expose)
    ├── ca.cert.pem    ← CA certificate (copy to rootfs_overlay/etc/rauc/)
    ├── signing.key.pem ← Bundle signing private key (OFFLINE)
    └── signing.cert.pem ← Bundle signing certificate
```

---

## Generating Keys

Run once on a trusted, air-gapped machine:

```bash
./keys/rauc/gen-keys.sh
```

After generation:
1. Copy `keys/rauc/ca.cert.pem` to `board/raspberrypi5/rootfs_overlay/etc/rauc/ca.cert.pem`
2. Store `ca.key.pem` and `signing.key.pem` in an HSM or encrypted offline storage
3. Use `signing.key.pem` + `signing.cert.pem` only when building RAUC bundles (set `RAUC_KEY_FILE` / `RAUC_CERT_FILE`)
