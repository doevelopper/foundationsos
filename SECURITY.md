# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| main    | ✅ Yes    |
| develop | ✅ Yes    |
| < 1.0   | ⚠️ Best-effort |

## Reporting a Vulnerability

**Please do NOT file public GitHub issues for security vulnerabilities.**

Use [GitHub Security Advisories](https://github.com/doevelopper/foundationsos/security/advisories/new) to report vulnerabilities privately.

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We aim to acknowledge reports within **48 hours** and provide a fix or mitigation within **90 days**.

## Disclosure Policy

We follow [Coordinated Vulnerability Disclosure (CVD)](https://vuls.cert.org/confluence/display/CVD).

## Security Best Practices for Users

1. **Never commit private keys** to the repository — use the scripts in `keys/` to generate them offline.
2. **Verify image signatures** before flashing using RAUC's bundle verification.
3. **Enable TPM measured boot** to detect unauthorized firmware modifications.
4. **Rotate RAUC signing keys** periodically and revoke compromised keys.
5. **Keep components updated** — subscribe to [security advisories](https://github.com/doevelopper/foundationsos/security/advisories) for this repo.
