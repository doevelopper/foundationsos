# Contributing to FoundationsOS

Thank you for your interest in contributing! This document outlines the process and conventions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Commit Message Convention](#commit-message-convention)
- [Coding Standards](#coding-standards)
- [Security Contributions](#security-contributions)

---

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). By participating, you agree to uphold this code.

---

## How to Contribute

1. **Fork** the repository and create a branch from `develop`:
   ```bash
   git checkout -b feat/my-feature develop
   ```

2. **Make your changes** following the coding standards below.

3. **Test your changes** on actual hardware (Raspberry Pi 5) when possible.

4. **Commit** using the conventional commit format (see below).

5. **Push** to your fork and open a **Pull Request** against the `develop` branch.

---

## Development Workflow

```
main ←── develop ←── feat/*, fix/*, docs/*, chore/*
```

| Branch      | Purpose |
|-------------|---------|
| `main`      | Stable, tagged releases only |
| `develop`   | Integration branch; all PRs target here |
| `feat/*`    | New features |
| `fix/*`     | Bug fixes |
| `hotfix/*`  | Critical fixes applied directly to `main` |
| `docs/*`    | Documentation-only changes |
| `chore/*`   | CI, build system, tooling changes |

---

## Commit Message Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

[optional body]

[optional footer(s)]
```

**Types:** `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `security`

**Scopes:** `buildroot`, `tfa`, `optee`, `tpm2`, `rauc`, `systemd`, `kernel`, `board`, `ci`, `docs`

**Examples:**
```
feat(rauc): add A/B slot verification via TPM PCR extend
fix(tpm2): correct abrmd socket path in systemd unit
security(optee): enforce TA binary signature verification
docs(architecture): add threat model diagram
```

---

## Coding Standards

### Shell Scripts
- Use `bash` with `set -euo pipefail`
- Pass ShellCheck with zero warnings
- Document all non-obvious commands

### Buildroot Configurations
- Document each non-default option with a comment in the defconfig
- Keep security-relevant options grouped and clearly commented

### systemd Units
- Always include hardening options (`NoNewPrivileges`, `PrivateTmp`, etc.)
- Use `Restart=on-failure` for critical services

---

## Security Contributions

For security-sensitive changes (TPM, OP-TEE, TF-A, key management, RAUC signing):

1. Clearly describe the security implications in your PR.
2. If you discover a vulnerability, **do not** open a public PR — use [Security Advisories](https://github.com/doevelopper/foundationsos/security/advisories/new) instead.
3. Ensure no private keys or secrets are included in commits.

---

## Licensing

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).
