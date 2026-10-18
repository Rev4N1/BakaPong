# Changelog

## Unreleased - BakaSU

## Changes
- Switched root to [BakaSU](https://github.com/Baka-SU/BakaSU) (ReSukiSU was renamed upstream); the build now pulls `setup.sh` from the BakaSU repo
- Renamed build artifacts and zips to `kernel-<type>-NP2-BakaSU.zip`

## Fixed
- Workflow rejected by GitHub (`uses:` can't take an expression); artifact uploads now use `actions/upload-artifact@v5`
- "Test All Builds" no longer fails on duplicate `config`/`rej` artifact names
- Builds work on forks: token permissions reduced to `contents: read`

## New
- `bakasu_ref` input to pin a BakaSU tag or commit (empty = latest `main`)

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