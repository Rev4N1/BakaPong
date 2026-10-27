#!/usr/bin/env bash
# Build AmneziaWG into the kernel, next to the stock WireGuard.
#
# The source comes from amnezia-vpn/amneziawg-linux-kernel-module (an
# out-of-tree module) and goes in as drivers/net/amneziawg. It is a
# WireGuard fork that keeps WireGuard's global names (wg_*), and GKI
# builds WireGuard in, so those are renamed to awg_* here; with LTO the
# objects are bitcode, so this has to happen in the source.
#
# Built in (CONFIG_AMNEZIAWG=y) it shows up as /sys/module/amneziawg,
# which is what the AmneziaWG app checks before it offers its kernel
# backend (Settings > Use kernel module, needs root).
set -euo pipefail

: "${KERNEL_DIR:?}" "${AMNEZIAWG_REF:?}"
AWG_REPO=https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git
DEST="${KERNEL_DIR}/drivers/net/amneziawg"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone -q "$AWG_REPO" "$tmp/awg"
git -C "$tmp/awg" checkout -q "$AMNEZIAWG_REF"
echo "AmneziaWG at $(git -C "$tmp/awg" rev-parse HEAD)"

rm -rf "$DEST"
cp -r "$tmp/awg/src" "$DEST"
# Out-of-tree leftovers: the external-module Makefile, DKMS and the test
# harness. Kbuild is what an in-tree build reads.
rm -rf "$DEST/Makefile" "$DEST/dkms.conf" "$DEST/tests"

# Rename every global that can clash with the built-in WireGuard (or
# anything else in vmlinux). The bogus_endpoints* module parameters keep
# their names on the command line (amneziawg.bogus_endpoints=...).
find "$DEST" -type f \( -name '*.c' -o -name '*.h' \) -exec sed -i \
    -e 's/\bwg_/awg_/g' \
    -e 's/\bjp_/awg_jp_/g' \
    -e 's/\bbogus_endpoints/awg_bogus_endpoints/g' \
    -e 's/module_param(awg_bogus_endpoints\([a-z0-9_]*\),/module_param_named(bogus_endpoints\1, awg_bogus_endpoints\1,/' \
    {} +
sed -i 's/^struct genl_ops genl_ops\[\] = {/static struct genl_ops genl_ops[] = {/' "$DEST/netlink.c"
# 32-bit ARM selects; these symbols don't exist on arm64.
sed -i -E '/^\s*select (VFP|VFPv3|NEON|KERNEL_MODE_NEON)\b/d' "$DEST/Kconfig"

# compat.h decides by version that 5.10.163+ has DEV_STATS_INC/ADD and
# 5.10.215+ has timer_delete_sync: stable backports that Android's 5.10
# skipped. Check this kernel's headers instead, and add what is missing.
compat="$DEST/compat/compat.h"
grep -q '^#endif /\* _WG_COMPAT_H \*/$' "$compat" \
    || { echo "AmneziaWG compat.h changed: no end marker" >&2; exit 1; }
: > "$tmp/fallbacks"
if ! grep -q 'define DEV_STATS_INC' "$KERNEL_DIR/include/linux/netdevice.h"; then
    cat >> "$tmp/fallbacks" <<'EOF'
#undef DEV_STATS_INC
#define DEV_STATS_INC(DEV, FIELD) ++DEV->stats.FIELD
#undef DEV_STATS_ADD
#define DEV_STATS_ADD(DEV, FIELD, VAL) DEV->stats.FIELD += VAL
EOF
fi
if ! grep -q 'timer_delete_sync' "$KERNEL_DIR/include/linux/timer.h"; then
    echo '#define timer_delete_sync(timer) del_timer_sync(timer)' >> "$tmp/fallbacks"
fi
if [ -s "$tmp/fallbacks" ]; then
    awk 'FNR == NR { add = add $0 "\n"; next }
         /^#endif \/\* _WG_COMPAT_H \*\/$/ { printf "/* BakaPong: backports this kernel lacks */\n%s\n", add }
         { print }' "$tmp/fallbacks" "$compat" > "$tmp/compat.h"
    mv "$tmp/compat.h" "$compat"
    echo "compat.h: added $(grep -c '^#define' "$tmp/fallbacks") fallback(s) this kernel lacks"
fi

# Fail here, not halfway through a two-hour build, if a rename missed.
if grep -rqE '^[a-z][^(;]*[ *]wg_[a-z0-9_]+\(' --include='*.c' "$DEST"; then
    echo "AmneziaWG still defines wg_* functions after the rename" >&2
    exit 1
fi
grep -q '^static struct genl_ops genl_ops\[\]' "$DEST/netlink.c" \
    || { echo "AmneziaWG netlink.c changed: genl_ops is not static" >&2; exit 1; }

# Hook it into drivers/net, right after WireGuard.
cd "$KERNEL_DIR"
grep -q 'amneziawg/' drivers/net/Makefile \
    || sed -i '/^obj-\$(CONFIG_WIREGUARD) += wireguard\//a obj-$(CONFIG_AMNEZIAWG) += amneziawg/' drivers/net/Makefile
grep -q 'drivers/net/amneziawg/Kconfig' drivers/net/Kconfig \
    || sed -i '/^config EQUALIZER$/i source "drivers/net/amneziawg/Kconfig"\n' drivers/net/Kconfig
grep -q 'amneziawg/' drivers/net/Makefile \
    && grep -q 'drivers/net/amneziawg/Kconfig' drivers/net/Kconfig \
    || { echo "could not hook AmneziaWG into drivers/net" >&2; exit 1; }
echo "AmneziaWG added as drivers/net/amneziawg"
