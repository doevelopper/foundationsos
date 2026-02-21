# OP-TEE Key Infrastructure

This directory contains scripts for managing OP-TEE Trusted Application (TA) signing keys.

> ⚠️ **IMPORTANT**: Private keys MUST **never** be committed to this repository.

---

## TA Signing

OP-TEE Trusted Applications are signed with an RSA-4096 key. The public key is embedded in the OP-TEE OS image at build time.

```bash
# Generate TA signing key
openssl genrsa -out ta-signing.key.pem 4096
openssl rsa -in ta-signing.key.pem -pubout -out ta-signing.pub.pem
```

Set `BR2_TARGET_OPTEE_OS_SIGN_KEY` to the path of the private key during build.

After generation, store `ta-signing.key.pem` in offline / HSM storage.
