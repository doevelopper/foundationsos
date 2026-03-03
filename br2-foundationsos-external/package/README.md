# external/package — Custom Buildroot Packages

This directory is an **external Buildroot tree** (`BR2_EXTERNAL`) that extends the standard Buildroot package set with custom packages specific to FoundationsOS.

## Structure

```
external/
├── Config.in              ← Top-level package menu
├── external.mk            ← External tree make include
└── package/
    ├── rpi5-security-init/ ← First-boot TPM provisioning service
    └── rpi5-rauc-hawkbit/  ← RAUC HawkBit update server connector
```

## Adding a Package

1. Create a new subdirectory under `package/`:
   ```
   package/my-package/
   ├── Config.in
   ├── my-package.mk
   └── my-package.hash
   ```

2. Add it to `Config.in`.

3. Enable it in `configs/raspberrypi5_defconfig` with `BR2_PACKAGE_MY_PACKAGE=y`.

See the [Buildroot Manual — Adding New Packages](https://buildroot.org/downloads/manual/manual.html#adding-packages) for details.
