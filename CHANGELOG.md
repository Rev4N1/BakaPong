# Changelog

## Unreleased

## Fixed
- `.config` debug artifact was always empty (hidden files are skipped by default)
- Node 20 deprecation warning: `actions/upload-artifact@v7`
- Runner pinned to `ubuntu-24.04` ahead of the `ubuntu-latest` move to 26.04

## v1.0.0 - BakaPong (Oct.18 2026)

## Changes
- Renamed the project to BakaPong; zips are now `BakaPong-<type>.zip`
- Switched root to [BakaSU](https://github.com/Baka-SU/BakaSU) (ReSukiSU was renamed upstream)
- BakaSU defaults to commit `5b76b88`, the last one that builds with SUSFS (BakaSU `main` blocks SUSFS builds for now)
- LineageOS only: dropped the NothingOSS and arter97 builds

## Fixed
- Workflow rejected by GitHub (`uses:` can't take an expression); artifact uploads now use `actions/upload-artifact@v5`
- Builds work on forks: token permissions reduced to `contents: read`
- A bad `bakasu_ref` now fails the build instead of silently using `main`

## New
- `bakasu_ref` input to choose a BakaSU tag or commit (`main` = latest)

## v3.0.5 - The architecture update (Jul.1 2026)

## New
- Better build all system on the workflow
- Improvements on anykernel3 script

## Changes
- Removed KPM Support (Dropped by ReSukiSU and the patching was tricky)

> Updates not listed here are because there wasn't changes on the workflow, only updated upstream.

## v3.0.4 - The ReSukiSU Improvement (May.1 2026)

### New
- Fully support KPM
- Made the workflow be able to build any GKI-based kernel, feel free to fork it for your own device/kernel. (Supports custom patches too in case your kernel requires themeeeeee, just put them in the `patches/your_device` folder and pass it to the workflow input)
- Added BaseBandGuard support, allowing to have root while preventing apps and modules touch critical files (Think it like an AppArmor for android).

### Fixed
- Root detection on some banking apps (e.g. Revolut) due to some manual hooks and configs.