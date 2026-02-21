#!/usr/bin/env bash
# setup-env.sh — Install all host build dependencies for FoundationsOS
# Supports: Ubuntu 22.04, Debian 12

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

echo "========================================"
echo " FoundationsOS — Host Environment Setup"
echo "========================================"

# Detect OS
if ! grep -qE '(Ubuntu|Debian)' /etc/os-release 2>/dev/null; then
    echo "WARNING: This script is designed for Ubuntu 22.04 / Debian 12."
    echo "Your OS may require manual dependency installation."
fi

echo "[setup] Installing host packages..."
sudo apt-get update -qq
sudo apt-get install -y \
    build-essential git wget cpio unzip rsync bc \
    python3 python3-pip python3-setuptools python3-dev \
    libssl-dev libncurses-dev file \
    device-tree-compiler bison flex \
    gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    parted dosfstools e2fsprogs mtools genimage \
    rauc || {
        echo "[setup] NOTE: 'rauc' not available via apt; will use Buildroot host-rauc package."
    }

echo "[setup] Installing Python tools..."
pip3 install --quiet detect-secrets

echo ""
echo "[setup] ✅ Host environment ready."
echo "  Next step: make configure"
echo ""
