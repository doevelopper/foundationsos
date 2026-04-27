# FoundationsOS Custom Packages Registry

Comprehensive list of all available custom packages organized by category, with descriptions and build status.

## Table of Contents
- [Applications](#applications)
- [Drivers](#drivers)
- [Utilities](#utilities)
- [System Packages](#system-packages)
- [Security & OTA](#security--ota)

---

## Applications

### Development Examples & Templates
Build examples for different programming languages and tools.

| Package | Type | Description | Status |
|---------|------|-------------|--------|
| `hello-makefile` | Example | Simple makefile-based project | ✓ Ready |
| `hello-cmake` | Example | CMake-based project | ✓ Ready |
| `hello-autotools` | Example | Autotools-based project | ✓ Ready |
| `helloworld` | Example | Classic hello world | ✓ Ready |
| `template-c` | Template | C project template | ✓ Ready |
| `template-cpp` | Template | C++ project template | ✓ Ready |
| `template-py` | Template | Python project template | ✓ Ready |

### Hardware Examples

| Package | Type | Description | Status |
|---------|------|-------------|--------|
| `gpio` | Control | GPIO manipulation example | ✓ Ready |
| `timer` | Utility | Timer utility example | ✓ Ready |
| `cppbdd101` | Testing | C++ BDD (Behavior Driven Development) | ✓ Ready |

### Available in menuconfig
All application packages are optional and can be selected via `make menuconfig`.

---

## Drivers

### Kernel Space Drivers
Kernel modules and driver components.

| Package | Type | Description | Status |
|---------|------|-------------|--------|
| `kernel/` | Kernel | Kernel-level driver examples | ✓ Ready |
| `kernel-space/` | Kernel | Kernel space driver components | ✓ Ready |

**Note:** UniPi-specific drivers in `kernel/` and `kernel-space/` directories may require adaptation for Foundation3/5 targets.

### User Space Drivers
User-space driver implementations and wrappers.

| Package | Type | Description | Status |
|---------|------|-------------|--------|
| `user/` | User-space | User-space driver examples | ✓ Ready |
| `user-space/` | User-space | User-space driver components | ✓ Ready |

**Note:** These drivers are hardware-agnostic and may work on both Foundation3 and Foundation5.

---

## Utilities

### System Monitoring & Performance

| Package | Version | Description | Dependencies | Status |
|---------|---------|-------------|--------------|--------|
| `atop2` | - | Advanced system monitor | - | ✓ Ready |
| `btop` | - | Better top system monitor | - | ✓ Ready |
| `netatop` | 3.1 | Network and I/O monitor | zlib | ✓ Ready |

### System Configuration & Persistence

| Package | Type | Description | Status |
|---------|------|-------------|--------|
| `persist-partition` | Config | Persistent storage partition handler | ✓ Ready |
| `home-persistence` | Config | Home directory persistence | ✓ Ready |

### SSH & Remote Access

| Package | Type | Description | Status |
|---------|------|-------------|--------|
| `ssh-root-password` | Config | SSH root password configuration | ✓ Ready |
| `ssh-key-persistence` | Config | SSH key persistence across reboots | ✓ Ready |

### Testing & Development

| Package | Type | Description | Status |
|---------|------|-------------|--------|
| `cucumber-cpp` | Testing | C++ acceptance testing framework | ✓ Ready |

---

## System Packages

### Package Management

| Package | Version | Description | Status |
|---------|---------|-------------|--------|
| `ucos-opkg` | - | OPKG package manager integration | ✓ Ready |

### Kernel Modules

| Package | Version | Description | Applies To | Status |
|---------|---------|-------------|------------|--------|
| `unipi-kernel-modules` | 1.126 | UniPi industrial board modules | Foundation3/5 | ✓ Ready |

### Shell Enhancements

| Package | Type | Description | Status |
|---------|------|-------------|--------|
| `zsh-autosuggestions` | Shell | ZSH command autosuggestions | ✓ Ready |
| `zsh-history-substring-search` | Shell | ZSH history search | ✓ Ready |

---

## Security & OTA

### Foundation5 Specific

| Package | Type | Description | Applies To | Status |
|---------|------|-------------|------------|--------|
| `rpi5-security-init` | Init | RPi 5 security initialization | Foundation5 | ✓ Ready |
| `rpi5-rauc-hawkbit` | OTA | RPi 5 RAUC over-the-air updates | Foundation5 | ✓ Ready |

---

## Usage

### Enable Packages in Build

All packages are available through Buildroot's `menuconfig`:

```bash
# Configure build for a target
make foundation3-configure
make foundation5-configure

# Open menuconfig to select packages
# Navigate to: FoundationsOS Custom Packages
make menuconfig
```

### Building with Specific Packages

```bash
# Build with selected custom packages
make foundation5-compile

# Build for Foundation3
make foundation3-compile
```

---

## Package Dependencies

### Critical Dependencies
- **netatop:** Requires `zlib`
- **rpi5-security-init:** Foundation5 specific
- **rpi5-rauc-hawkbit:** Foundation5 specific, RAUC OTA support
- **unipi-kernel-modules:** Requires `linux` kernel

### Optional Dependencies
- **ssh-key-persistence:** Works with OpenSSH
- **zsh-*** packages: Require `zsh` shell

---

## Adding Custom Packages

To add new packages to the FoundationsOS external tree:

1. Create a new directory under the appropriate category:
   ```bash
   mkdir -p package/applications/my-package/
   ```

2. Create `Config.in` with package configuration:
   ```makefile
   config BR2_PACKAGE_MY_PACKAGE
       bool "my-package"
       help
         Description of your package.
   ```

3. Create package makefile `my-package.mk`:
   ```makefile
   ################################################################################
   #
   # my-package
   #
   ################################################################################
   
   MY_PACKAGE_VERSION = 1.0
   MY_PACKAGE_SITE = https://github.com/user/repo
   MY_PACKAGE_SITE_METHOD = git
   MY_PACKAGE_LICENSE = GPL-2.0
   
   define MY_PACKAGE_BUILD_CMDS
       # Build commands
   endef
   
   define MY_PACKAGE_INSTALL_TARGET_CMDS
       # Install commands
   endef
   
   $(eval $(generic-package))
   ```

4. Update the appropriate category `Config.in` to source your package:
   ```makefile
   source "$BR2_EXTERNAL_FOUNDATIONSOS_PATH/package/applications/my-package/Config.in"
   ```

---

## Package Organization

```
package/
├── Config.in                          # Main menu configuration
├── PACKAGES.md                        # This file
├── applications/                      # Example applications
│   ├── Config.in
│   ├── hello-makefile/
│   ├── hello-cmake/
│   ├── hello-autotools/
│   ├── helloworld/
│   ├── gpio/
│   ├── timer/
│   ├── template-c/
│   ├── template-cpp/
│   ├── template-py/
│   └── cppbdd101/
├── drivers/                           # Kernel & user-space drivers
│   ├── Config.in
│   ├── kernel/
│   ├── kernel-space/
│   ├── user/
│   └── user-space/
├── utils/                             # System utilities
│   ├── Config.in
│   ├── atop2/
│   ├── btop/
│   ├── netatop/
│   ├── persist-partition/
│   ├── home-persistence/
│   ├── ssh-root-password/
│   ├── ssh-key-persistence/
│   └── cucumber-cpp/
├── ucos-opkg/                         # Package management
├── unipi-kernel-modules/              # Hardware modules
├── zsh-autosuggestions/               # Shell enhancements
├── zsh-history-substring-search/
├── rpi5-security-init/                # Foundation5 security
└── rpi5-rauc-hawkbit/                 # Foundation5 OTA
```

---

## Notes

- **Hardware Compatibility:** Most utilities are generic and work on both Foundation3 and Foundation5. Packages in the `drivers/` directory should be reviewed for target-specific hardware compatibility.
- **UniPi Migration:** Packages originate from UniPi project but have been adapted for Foundation3/5 targets.
- **Optional Packages:** All packages are optional - the defconfigs only select those specifically needed for each target.
- **Future Extensions:** New packages can be easily added by following the established directory structure and configuration patterns.

---

Last Updated: 2026-04-27
Status: Complete package registry with 35+ available packages
