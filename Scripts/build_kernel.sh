#!/usr/bin/env bash
set -euo pipefail

cd "${KERNEL_DIR}"

defconfig_targets=()
defconfig_paths=()
if [ -n "${DEFCONFIG:-}" ]; then
  for def in ${DEFCONFIG}; do
    if echo "${def}" | grep -q '^/'; then
      def_path="${def#/}"
    else
      def_path="arch/arm64/configs/${def}"
    fi

    if [ ! -f "${def_path}" ]; then
      echo "Defconfig path not found: ${def_path}" >&2
      exit 1
    fi

    def_target="$(basename "${def_path}")"
    if [ "${def_path}" != "arch/arm64/configs/${def_target}" ]; then
      cp "${def_path}" "arch/arm64/configs/${def_target}"
    fi

    defconfig_targets+=("${def_target}")
    defconfig_paths+=("arch/arm64/configs/${def_target}")
  done
fi

if [ "${#defconfig_targets[@]}" -lt 1 ]; then
  echo "No defconfig provided" >&2
  exit 1
fi

frags=()
if [ -n "${DEFCONFIG_FRAGS:-}" ]; then
  for frag in ${DEFCONFIG_FRAGS}; do
    if [ -f "${frag}" ]; then
      frags+=("${frag}")
    elif [ -f "arch/arm64/configs/${frag}" ]; then
      frags+=("arch/arm64/configs/${frag}")
    else
      echo "Skipping missing defconfig fragment: ${frag}"
    fi
  done
fi

make ${MAKE_ARGS} "${defconfig_targets[0]}"

# Droidspaces (https://github.com/ravindu644/DroidSpaces): config side of
# support. The kABI patch fixes are applied earlier by add_droidspaces.sh;
# these options follow ravindu644/Droidspaces-OSS
# Documentation/Kernel-Configuration.md and are merged last so they win
# over the vendor fragments above.
if [ "${DROIDSPACES_SUPPORT:-false}" = "true" ]; then
  cat > out/droidspaces_gki.config <<'EOF'
# Kernel configurations for full DroidSpaces support for GKI
# Source: ravindu644/Droidspaces-OSS Documentation/Kernel-Configuration.md

# IPC
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y

# Namespaces
CONFIG_IPC_NS=y
CONFIG_PID_NS=y

# HW Access Support
CONFIG_DEVTMPFS=y

# Networking (Enhanced NAT support)
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y

# macvlan network mode (--net=macvlan)
CONFIG_MACVLAN=y

# IPv6 in NAT mode (NAT66)
CONFIG_IP6_NF_NAT=y
CONFIG_IP6_NF_TARGET_MASQUERADE=y

# --- optional but recommended ---

# Fix for docker unsafe procfs error
CONFIG_USER_NS=y

# UFW support
CONFIG_NETFILTER_XT_TARGET_REJECT=y
CONFIG_NETFILTER_XT_TARGET_LOG=y
CONFIG_NETFILTER_XT_MATCH_RECENT=y

# Fail2ban support
CONFIG_IP_SET=y
CONFIG_IP_SET_HASH_IP=y
CONFIG_IP_SET_HASH_NET=y
CONFIG_NETFILTER_XT_SET=y

# xattr + posix acl on tmpfs (NixOS support)
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y
EOF
  # Off by default: enabling these after boot breaks the prebuilt GKI vendor
  # modules (kABI), so opt in consciously (droidspaces_resource_limits input)
  if [ "${DROIDSPACES_RESOURCE_LIMITS:-false}" = "true" ]; then
    cat >> out/droidspaces_gki.config <<'EOF'

# CPU limit (--cpus) and process limit (--pids-limit)
CONFIG_CGROUP_SCHED=y
CONFIG_FAIR_GROUP_SCHED=y
CONFIG_CFS_BANDWIDTH=y
CONFIG_CGROUP_PIDS=y
EOF
  fi
fi

merge_frags=()
if [ "${#defconfig_paths[@]}" -gt 1 ]; then
  merge_frags+=("${defconfig_paths[@]:1}")
fi
if [ "${#frags[@]}" -gt 0 ]; then
  merge_frags+=("${frags[@]}")
fi
if [ "${DROIDSPACES_SUPPORT:-false}" = "true" ]; then
  # last = wins over earlier fragments
  merge_frags+=("out/droidspaces_gki.config")
fi

if [ "${#merge_frags[@]}" -gt 0 ]; then
  if [ -x "scripts/kconfig/merge_config.sh" ]; then
    scripts/kconfig/merge_config.sh -m -O out out/.config "${merge_frags[@]}"
  else
    echo "merge_config.sh not found; cannot apply defconfig fragments" >&2
    exit 1
  fi
fi

EXTRA_CFG="out/ci-extra.config"
: > "${EXTRA_CFG}"
echo "CONFIG_KSU=y" >> "${EXTRA_CFG}"

if [ "${SUSFS_SUPPORT}" = "true" ]; then
  echo "CONFIG_KSU_SUSFS=y" >> "${EXTRA_CFG}"
fi

if [ "${BBG_SUPPORT}" = "true" ]; then
  echo "CONFIG_BBG=y" >> "${EXTRA_CFG}"
fi

if [ "${AMNEZIAWG_SUPPORT:-false}" = "true" ]; then
  echo "CONFIG_AMNEZIAWG=y" >> "${EXTRA_CFG}"
fi

cat "${EXTRA_CFG}" >> out/.config
make ${MAKE_ARGS} olddefconfig

# olddefconfig silently drops a symbol whose dependencies aren't met
if [ "${AMNEZIAWG_SUPPORT:-false}" = "true" ] && ! grep -q '^CONFIG_AMNEZIAWG=y' out/.config; then
  echo "CONFIG_AMNEZIAWG=y did not survive olddefconfig" >&2
  exit 1
fi

# Same rule for the merged Droidspaces fragment: required symbols fail the
# build, optional ones only warn (mirrors Volcanic-Kernel build_bakapong.sh)
if [ "${DROIDSPACES_SUPPORT:-false}" = "true" ]; then
  DROIDSPACES_REQUIRED="SYSVIPC POSIX_MQUEUE IPC_NS PID_NS DEVTMPFS NETFILTER_XT_MATCH_ADDRTYPE"
  missing_req=0
  while IFS='=' read -r sym _; do
    grep -q "^${sym}=y" out/.config && continue
    if [[ " $DROIDSPACES_REQUIRED " == *" ${sym#CONFIG_} "* ]]; then
      echo "Droidspaces: required ${sym}=y did not survive olddefconfig" >&2
      missing_req=1
    else
      echo "Droidspaces: optional ${sym}=y did not survive olddefconfig (continuing)"
    fi
  done < <(grep '^CONFIG_' out/droidspaces_gki.config)
  if [ "$missing_req" -ne 0 ]; then
    echo "Fix: the kernel is missing Kconfig dependencies for those options." >&2
    echo "If SYSVIPC/POSIX_MQUEUE drop, check that add_droidspaces.sh ran" >&2
    echo "(droidspaces_support=true) before this build." >&2
    exit 1
  fi
fi
[ -f scripts/setlocalversion ] && sed -i 's/-dirty//g' scripts/setlocalversion || true

JOBS=$(( $(nproc) / 2 ))
[ "${JOBS}" -lt 1 ] && JOBS=1
make -j"${JOBS}" ${MAKE_ARGS} Image KCFLAGS="-Wno-error"
