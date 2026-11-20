# BakaPong

Rooted kernel for the **Nothing Phone (2)** (Pong) on **LineageOS**, with [BakaSU](https://github.com/Baka-SU/BakaSU) root and [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) hiding built in. Built entirely by GitHub Actions from the [LineageOS kernel source](https://github.com/LineageOS/android_kernel_nothing_sm8475).

## Features

- **[BakaSU](https://github.com/Baka-SU/BakaSU)**: kernel-level root (formerly ReSukiSU).
- **[SUSFS](https://gitlab.com/simonpunk/susfs4ksu)**: hides root from banking apps, games and integrity checks.
- **[AmneziaWG](https://docs.amnezia.org/documentation/amnezia-wg/)**: WireGuard with disguised packets, built into the kernel next to WireGuard. In the AmneziaWG app, *Settings → Use kernel module* (needs root) then runs tunnels in the kernel instead of userspace. Use [erophey7's fork](https://github.com/erophey7/amneziawg-android/releases/latest) for this: the official app fails with "Required tools unavailable" when a tunnel starts in kernel mode ([amneziawg-android#22](https://github.com/amnezia-vpn/amneziawg-android/issues/22), fixed in [#89](https://github.com/amnezia-vpn/amneziawg-android/pull/89), not merged yet).
- **[Droidspaces](https://github.com/ravindu644/DroidSpaces)**: run Linux distro containers (Ubuntu, Debian, Arch, NixOS…) directly on the phone. Off by default (enable `droidspaces_support`; kernels 5.4+), using the [Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) GKI procedure so prebuilt vendor modules keep loading.
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

The `bakasu_ref` input picks the BakaSU version. Leave it empty for the latest (`main`), or set a tag or commit to pin one, e.g. if a BakaSU update stops building with SUSFS.

`amneziawg_support` (on by default) builds AmneziaWG in, from [amneziawg-linux-kernel-module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module); `amneziawg_ref` picks its version (empty = the pinned commit). `Scripts/add_amneziawg.sh` adds it as `drivers/net/amneziawg` and renames its `wg_*` symbols to `awg_*`, so it links next to the kernel's own WireGuard.

`droidspaces_support` (off by default) enables Droidspaces on kernels 5.4+: `Scripts/add_droidspaces.sh` applies the SYSVIPC/POSIX-MQUEUE kABI fixes, pinned to a reviewed commit (`DROIDSPACES_REF` in the script), from [Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/Kernel-Configuration.md), `Scripts/build_kernel.sh` merges the container config options *last* so they win over the vendor fragments, and the build fails fast if a required option does not survive `olddefconfig`. `droidspaces_sysvipc_patch` selects the SYSVIPC kABI patch used on kernels below 6.12: if applying it fails in CI or the phone bootloops after flashing, try another variant from `.../kernel-patches/GKI/below-kernel-6.12/`. `droidspaces_resource_limits` (off by default, kABI-unsafe) adds the `--cpus` / `--pids-limit` cgroup options: enabling them can make prebuilt vendor modules reject the kernel, so only turn it on if you need CPU/process limits. Set `droidspaces_support=false` for kernels below 5.4 (the GKI procedure does not support them).

## Credits

- [MiguVT](https://github.com/MiguVT/NP2_Kernel): original NP² Kernel workflow this project is based on
- [BakaSU maintainers & contributors](https://github.com/Baka-SU/BakaSU)
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) (SUSFS)
- [osm0sis](https://github.com/osm0sis) (AnyKernel3)
- [vc-teahouse & contributors](https://github.com/vc-teahouse/Baseband-guard) (BaseBandGuard)
- [Amnezia](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module) (AmneziaWG)
- [ravindu644](https://github.com/ravindu644/DroidSpaces) & [Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) (Droidspaces kernel procedure & kABI patches)
