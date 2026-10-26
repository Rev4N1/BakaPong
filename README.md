# BakaPong

Rooted kernel for the **Nothing Phone (2)** (Pong) on **LineageOS**, with [BakaSU](https://github.com/Baka-SU/BakaSU) root and [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) hiding built in. Built entirely by GitHub Actions from the [LineageOS kernel source](https://github.com/LineageOS/android_kernel_nothing_sm8475).

## Features

- **[BakaSU](https://github.com/Baka-SU/BakaSU)**: kernel-level root (formerly ReSukiSU).
- **[SUSFS](https://gitlab.com/simonpunk/susfs4ksu)**: hides root from banking apps, games and integrity checks.
- **[BaseBandGuard](https://github.com/vc-teahouse/Baseband-guard)** (optional, off by default): stops apps and modules from touching critical partitions. It may bootloop together with BakaSU/SUSFS.

## Install

1. Download `BakaPong-LineageOS.zip` from [Releases](../../releases).
2. Boot into recovery (TWRP / OrangeFox).
3. Flash the zip and reboot.
4. Install the [BakaSU Manager](https://bakasu.org) to manage root.

> **Warning:** Back up your boot image first. The bootloader must be unlocked. Use at your own risk.

## Build it yourself

1. Fork this repo.
2. Go to **Actions** → **Test All Builds** (or **Build BakaPong Kernel** for custom inputs) → **Run workflow**.
3. Download the zip from the finished run.

The `bakasu_ref` input picks the BakaSU version. Leave it empty to use the last BakaSU commit tested with SUSFS, or set it to `main`, a tag or a commit.

## Credits

- [MiguVT](https://github.com/MiguVT/NP2_Kernel): original NP² Kernel workflow this project is based on
- [BakaSU maintainers & contributors](https://github.com/Baka-SU/BakaSU)
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) (SUSFS)
- [osm0sis](https://github.com/osm0sis) (AnyKernel3)
- [vc-teahouse & contributors](https://github.com/vc-teahouse/Baseband-guard) (BaseBandGuard)
