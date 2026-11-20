#!/usr/bin/env bash
# Apply Droidspaces support to the kernel (GKI procedure).
#
# Droidspaces (https://github.com/ravindu644/DroidSpaces) runs Linux
# distros directly on Android GKI kernels. Enabling its config options
# (merged by Scripts/build_kernel.sh when DROIDSPACES_SUPPORT=true)
# changes struct layouts, so this script first applies the kABI fixes
# from ravindu644/Droidspaces-OSS: prebuilt vendor modules must still
# load against the rebuilt kernel.
#
# Procedure: ravindu644/Droidspaces-OSS Documentation/Kernel-Configuration.md
# Only the GKI path is implemented, so kernels below 5.4 fail here; set
# droidspaces_support=false on those.
#
# DROIDSPACES_SYSVIPC_PATCH selects the SYSVIPC kABI patch used on kernels
# below 6.12 (file name from .../GKI/below-kernel-6.12/). The default is
# the variant the guide recommends; if the patch fails to apply or the
# phone bootloops afterwards, try another variant from that folder.
set -euo pipefail

: "${KERNEL_DIR:?}"

# Pinned Droidspaces-OSS commit: these patches go into a rooted kernel, so
# never build from a moving branch. Bump on purpose after reviewing the diff.
: "${DROIDSPACES_REF:=cdadb9eb5d0f86aacffff60776333e6f6b73a30a}"
DS_RAW="https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/${DROIDSPACES_REF}/Documentation/resources/kernel-patches/GKI"
: "${DROIDSPACES_SYSVIPC_PATCH:=001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch}"
# A file name from below-kernel-6.12/, nothing else
[[ "$DROIDSPACES_SYSVIPC_PATCH" =~ ^[A-Za-z0-9._-]+\.patch$ ]] || { echo "Invalid droidspaces_sysvipc_patch: $DROIDSPACES_SYSVIPC_PATCH" >&2; exit 1; }

cd "$KERNEL_DIR"

# Read MAJOR.MINOR from the kernel Makefile (KERNEL_VERSION has SUBLEVEL and
# EXTRAVERSION, which we do not need for the patch choice)
kmaj=$(sed -n 's/^VERSION *= *\([0-9]*\).*/\1/p'    Makefile | head -n1)
kmin=$(sed -n 's/^PATCHLEVEL *= *\([0-9]*\).*/\1/p' Makefile | head -n1)
[ -n "$kmaj" ] && [ -n "$kmin" ] \
    || { echo "Cannot read kernel version from $KERNEL_DIR/Makefile" >&2; exit 1; }
echo "Droidspaces: kernel $kmaj.$kmin"

if (( kmaj < 5 || (kmaj == 5 && kmin < 4) )); then
    echo "Kernel $kmaj.$kmin is not GKI; only the GKI procedure is implemented. Use droidspaces_support=false." >&2
    exit 1
fi

if [ "${DROIDSPACES_RESOURCE_LIMITS:-false}" = "true" ]; then
    echo "Droidspaces: CPU/process limits ON: this breaks the GKI kABI. Vendor modules built against a kernel without them will be rejected." >&2
else
    echo "Droidspaces: CPU/process limits are off (kABI-unsafe on GKI); droidspaces_resource_limits=true enables them"
fi

ds_files=()
if (( kmaj > 6 || (kmaj == 6 && kmin >= 12) )); then
    ds_files+=("kernel-6.12/001.GKI-6.12-or-above-fix_sysvipc_kabi.patch")
else
    ds_files+=("below-kernel-6.12/$DROIDSPACES_SYSVIPC_PATCH")
    # POSIX_MQUEUE kABI fix is required for 5.10 and below
    if (( kmaj == 5 && kmin <= 10 )); then
        ds_files+=("below-kernel-6.12/002.5.10_or_lower_use_android_abi_padding_for_posix_mqueue.patch")
    fi
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for f in "${ds_files[@]}"; do
    name=$(basename "$f")
    echo "Fetching $name"
    curl -fsSL "$DS_RAW/$f" -o "$tmp/$name"
    # Already applied (dry-run of the reverse patch succeeds): re-runs on the
    # same tree skip cleanly instead of double-patching
    if patch -p1 -R -f --dry-run -s < "$tmp/$name" > /dev/null 2>&1; then
        echo "$name: already applied, skipping"
        continue
    fi
    echo "Applying $name"
    # A hunk that does not fit exits nonzero (set -e): the build fails here,
    # long before packaging, and the runner's .rej collection still runs
    patch -p1 < "$tmp/$name"
done
echo "Droidspaces kABI patches applied"
