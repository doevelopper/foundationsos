# ADR-0004: Use systemd as the Init System

## Status
Accepted

## Context
An init system is required to manage the boot sequence and service lifecycle. Candidates are BusyBox init (simple scripts), OpenRC, and systemd.

## Decision
Use **systemd** as the init system.

## Rationale
- **Security hardening**: systemd units support fine-grained sandboxing (`NoNewPrivileges`, `PrivateTmp`, `ProtectSystem`, `CapabilityBoundingSet`, seccomp filters) without external tools.
- **cgroups v2**: Native resource accounting and process tracking simplifies container-like isolation.
- **Socket activation**: Services start on-demand, reducing attack surface and boot time.
- **systemd-resolved / networkd / timesyncd**: Replaces several standalone daemons with well-maintained, hardened implementations.
- **Buildroot support**: `BR2_INIT_SYSTEMD` is a first-class Buildroot option.

## Consequences
- **Positive**: Rich security primitives baked into service units; standard tooling (`journalctl`, `systemctl`); good upstream security track record.
- **Negative**: Larger binary footprint than BusyBox init (~8 MiB on RPi3B+ vs ~1 MiB). Acceptable given the 512 MiB rootfs budget.
