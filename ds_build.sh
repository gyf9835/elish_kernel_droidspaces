#!/bin/bash
# MIUI build for elish (Xiaomi Pad 5 Pro) with KernelSU + DroidSpaces support.
# Based on liyafe1997's build.sh, extended with DroidSpaces kernel requirements.
set -e

TOOLCHAIN_PATH=$HOME/proton-clang/proton-clang-20210522/bin
GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)
TARGET_DEVICE=${1:-elish}

export PATH="$TOOLCHAIN_PATH:$PATH"
for t in aarch64-linux-gnu-ld arm-linux-gnueabi-ld clang; do
    command -v $t >/dev/null 2>&1 || { echo "[!] missing $t"; exit 1; }
done

export CCACHE_DIR="$HOME/.cache/ccache_mikernel"
export CC="ccache gcc"
export CXX="ccache g++"
export PATH="/usr/lib/ccache:$PATH"

MAKE_ARGS="ARCH=arm64 SUBARCH=arm64 O=out CC=clang CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- CLANG_TRIPLE=aarch64-linux-gnu-"

# ---------- KernelSU (SukiSU + SUSFS) ----------
echo "[*] Setting up SukiSU..."
curl -LSs "https://github.com/liyafe1997/SukiSU-Ultra/raw/4ff14cf0051d04209c4abd5027d99d8e7780ef5b/kernel/setup.sh" \
    | bash -s f4863b20cc8dc0f8cc67418980f022e43014b598

# ---------- DroidSpaces kernel patches ----------
echo "[*] Setting up DroidSpaces..."
DS_TMP_DIR=$(mktemp -d)
DS_BASE_URL="https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/main/Documentation/resources/kernel-patches/non-GKI"
wget -q -O "$DS_TMP_DIR/01_fix_xt_qtaguid.patch" \
    "$DS_BASE_URL/01.fix_kernel_panic_in_xt_qtaguid.patch" || true
wget -q -O "$DS_TMP_DIR/02_fix_cgroup_prefix.patch" \
    "$DS_BASE_URL/02.fix_restore%20cgroup%20file%20prefix%20handling%20.patch" || true

apply_patch() {
    local f=$1
    [ -s "$f" ] || { echo "[-] empty patch, skip"; return 0; }
    if patch -p1 --forward --dry-run < "$f" >/dev/null 2>&1; then
        patch -p1 --forward < "$f"
        echo "[+] applied: $(basename "$f")"
    else
        echo "[-] skipped (already applied / n/a): $(basename "$f")"
    fi
}
apply_patch "$DS_TMP_DIR/01_fix_xt_qtaguid.patch"
apply_patch "$DS_TMP_DIR/02_fix_cgroup_prefix.patch"

# ---------- AnyKernel3 ----------
rm -rf out anykernel
git clone https://github.com/liyafe1997/AnyKernel3 -b kona --single-branch --depth=1 anykernel

local_version_str="-perf"
local_version_date_str="-$(date +%Y%m%d)-${GIT_COMMIT_ID}-perf"
sed -i "s/${local_version_str}/${local_version_date_str}/g" arch/arm64/configs/${TARGET_DEVICE}_defconfig

# ---------- MIUI build ----------
echo "[*] Configuring for MIUI..."
dts_source=arch/arm64/boot/dts/vendor/qcom
cp -a ${dts_source} .dts.bak

# Correct panel dimensions on MIUI builds
sed -i 's/<154>/<1537>/g' ${dts_source}/dsi-panel-j1s* 2>/dev/null || true
sed -i 's/<154>/<1537>/g' ${dts_source}/dsi-panel-j2* 2>/dev/null || true
sed -i 's/<155>/<1544>/g' ${dts_source}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi 2>/dev/null || true
sed -i 's/<155>/<1545>/g' ${dts_source}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi 2>/dev/null || true
sed -i 's/<155>/<1546>/g' ${dts_source}/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi 2>/dev/null || true
sed -i 's/<155>/<1546>/g' ${dts_source}/dsi-panel-l11r-38-08-0a-dsc-cmd.dtsi 2>/dev/null || true
sed -i 's/<70>/<695>/g' ${dts_source}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi 2>/dev/null || true
sed -i 's/<70>/<695>/g' ${dts_source}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi 2>/dev/null || true
sed -i 's/<70>/<695>/g' ${dts_source}/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi 2>/dev/null || true
sed -i 's/<70>/<695>/g' ${dts_source}/dsi-panel-l11r-38-08-0a-dsc-cmd.dtsi 2>/dev/null || true
sed -i 's/<71>/<710>/g' ${dts_source}/dsi-panel-j1s* 2>/dev/null || true
sed -i 's/<71>/<710>/g' ${dts_source}/dsi-panel-j2* 2>/dev/null || true

# smart fps / qsync
sed -i 's/\/\/ mi,mdss-dsi-pan-enable-smart-fps/mi,mdss-dsi-pan-enable-smart-fps/g' ${dts_source}/dsi-panel* 2>/dev/null || true
sed -i 's/\/\/ mi,mdss-dsi-smart-fps-max_framerate/mi,mdss-dsi-smart-fps-max_framerate/g' ${dts_source}/dsi-panel* 2>/dev/null || true
sed -i 's/\/\/ qcom,mdss-dsi-pan-enable-smart-fps/qcom,mdss-dsi-pan-enable-smart-fps/g' ${dts_source}/dsi-panel* 2>/dev/null || true
sed -i 's/qcom,mdss-dsi-qsync-min-refresh-rate/\/\/qcom,mdss-dsi-qsync-min-refresh-rate/g' ${dts_source}/dsi-panel* 2>/dev/null || true

make $MAKE_ARGS ${TARGET_DEVICE}_defconfig

# KernelSU
scripts/config --file out/.config \
    -e KSU \
    -e KSU_MANUAL_HOOK \
    -e KSU_SUSFS_HAS_MAGIC_MOUNT \
    -d KSU_SUSFS_SUS_PATH \
    -e KSU_SUSFS_SUS_MOUNT \
    -e KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT \
    -e KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT \
    -e KSU_SUSFS_SUS_KSTAT \
    -d KSU_SUSFS_SUS_OVERLAYFS \
    -e KSU_SUSFS_TRY_UMOUNT \
    -e KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT \
    -e KSU_SUSFS_SPOOF_UNAME \
    -e KSU_SUSFS_ENABLE_LOG \
    -e KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
    -e KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
    -d KSU_SUSFS_OPEN_REDIRECT \
    -d KSU_SUSFS_SUS_SU \
    -e KPM

# MIUI-specific options (same as upstream build.sh)
scripts/config --file out/.config \
    --set-str STATIC_USERMODEHELPER_PATH /system/bin/micd \
    -e PERF_CRITICAL_RT_TASK \
    -e SF_BINDER \
    -e OVERLAY_FS \
    -d DEBUG_FS \
    -e MIGT \
    -e MIGT_ENERGY_MODEL \
    -e MIHW \
    -e PACKAGE_RUNTIME_INFO \
    -e BINDER_OPT \
    -e KPERFEVENTS \
    -e MILLET \
    -e PERF_HUMANTASK \
    -d LTO_CLANG \
    -d LOCALVERSION_AUTO \
    -e XIAOMI_MIUI \
    -d MI_MEMORY_SYSFS \
    -e TASK_DELAY_ACCT \
    -e MIUI_ZRAM_MEMORY_TRACKING \
    -d CONFIG_MODULE_SIG_SHA512 \
    -d CONFIG_MODULE_SIG_HASH \
    -e MI_FRAGMENTION \
    -e PERF_HELPER \
    -e BOOTUP_RECLAIM \
    -e MI_RECLAIM \
    -e RTMM

# ---------- DroidSpaces kernel requirements ----------
# Full list from ravindu644/Droidspaces-OSS Documentation/Kernel-Configuration.md
# (non-GKI 3.18-4.19 section). Order matters: dependencies are resolved by
# olddefconfig afterwards, so we verify the RESULT and fail loudly if an
# option silently fell back to =n.
echo "[*] Enabling DroidSpaces kernel features..."

# IPC mechanisms
scripts/config --file out/.config -e SYSCTL -e SYSVIPC -e POSIX_MQUEUE
# Core namespace support
scripts/config --file out/.config -e NAMESPACES -e PID_NS -e UTS_NS -e IPC_NS
# Seccomp
scripts/config --file out/.config -e SECCOMP -e SECCOMP_FILTER
# Control groups
scripts/config --file out/.config -e CGROUPS -e CGROUP_DEVICE -e CGROUP_SCHED \
    -e FAIR_GROUP_SCHED -e CGROUP_FREEZER -e CGROUP_NET_PRIO -e MEMCG -e MEMCG_SWAP \
    -e CFS_BANDWIDTH -e CGROUP_PIDS -e CGROUP_CPUACCT
# Filesystems / device nodes
scripts/config --file out/.config -e DEVTMPFS -e DEVTMPFS_MOUNT -e OVERLAY_FS \
    -e TMPFS_POSIX_ACL -e TMPFS_XATTR
# Firmware loading
scripts/config --file out/.config -e FW_LOADER -e FW_LOADER_USER_HELPER
# DroidSpaces networking (NAT/none modes)
scripts/config --file out/.config -e NET_NS -e VETH -e BRIDGE -e NETFILTER \
    -e BRIDGE_NETFILTER -e NETFILTER_ADVANCED -e NF_CONNTRACK \
    -e IP_NF_IPTABLES -e IP_NF_FILTER -e NF_NAT -e NF_TABLES \
    -e IP_NF_TARGET_MASQUERADE -e NETFILTER_XT_TARGET_MASQUERADE \
    -e NETFILTER_XT_TARGET_TCPMSS -e NETFILTER_XT_MATCH_ADDRTYPE \
    -e NF_CONNTRACK_NETLINK -e NF_NAT_REDIRECT -e IP_ADVANCED_ROUTER \
    -e NF_NAT_MASQUERADE_IPV4 \
    -e IP_MULTIPLE_TABLES
# legacy compat
scripts/config --file out/.config -e NF_CONNTRACK_IPV4 -e NF_NAT_IPV4 -e IP_NF_NAT
# IPv6 NAT (NAT66)
scripts/config --file out/.config -e IPV6 -e IPV6_MULTIPLE_TABLES -e IP6_NF_IPTABLES \
    -e IP6_NF_FILTER -e IP6_NF_MANGLE -e IP6_NF_NAT -e IP6_NF_TARGET_MASQUERADE \
    -e NF_CONNTRACK_IPV6 -e NF_NAT_IPV6
# Macvlan mode
scripts/config --file out/.config -e MACVLAN
# USER_NS: docker "unsafe procfs" fix
scripts/config --file out/.config -e USER_NS
# Must be OFF on older kernels or containers have no internet
scripts/config --file out/.config -d ANDROID_PARANOID_NETWORK

make $MAKE_ARGS olddefconfig >/dev/null

echo "[*] Verifying DroidSpaces requirements against the RESULTING config..."
REQ="SYSCTL SYSVIPC POSIX_MQUEUE NAMESPACES PID_NS UTS_NS IPC_NS SECCOMP SECCOMP_FILTER"
REQ="$REQ CGROUPS CGROUP_DEVICE CGROUP_SCHED FAIR_GROUP_SCHED CGROUP_FREEZER"
REQ="$REQ CGROUP_NET_PRIO MEMCG MEMCG_SWAP CFS_BANDWIDTH CGROUP_PIDS CGROUP_CPUACCT"
REQ="$REQ DEVTMPFS OVERLAY_FS TMPFS_POSIX_ACL TMPFS_XATTR FW_LOADER FW_LOADER_USER_HELPER"
REQ="$REQ NET_NS VETH BRIDGE NETFILTER BRIDGE_NETFILTER NETFILTER_ADVANCED NF_CONNTRACK"
REQ="$REQ IP_NF_IPTABLES IP_NF_FILTER NF_NAT NF_TABLES IP_NF_TARGET_MASQUERADE"
REQ="$REQ NETFILTER_XT_TARGET_TCPMSS NETFILTER_XT_MATCH_ADDRTYPE NF_NAT_REDIRECT NF_NAT_MASQUERADE_IPV4"
REQ="$REQ IP_ADVANCED_ROUTER IP_MULTIPLE_TABLES IP_NF_NAT"
REQ="$REQ IPV6 IPV6_MULTIPLE_TABLES IP6_NF_IPTABLES IP6_NF_FILTER IP6_NF_MANGLE"
REQ="$REQ IP6_NF_NAT"
REQ="$REQ MACVLAN USER_NS"

# These names are from older/newer kernel generations than 4.19 and may not
# exist in this tree at all. The upstream list is a cross-version superset:
# NF_CONNTRACK_{IPV4,IPV6} were folded into NF_CONNTRACK back in 3.13, and
# NETFILTER_XT_TARGET_MASQUERADE was renamed NF_NAT_MASQUERADE. Treat them as
# optional -- report, do not fail -- but fail if they exist and are off.
OPTIONAL="IP6_NF_TARGET_MASQUERADE NETFILTER_XT_TARGET_MASQUERADE NF_NAT_MASQUERADE NF_CONNTRACK_NETLINK NF_CONNTRACK_IPV4 NF_CONNTRACK_IPV6 NF_NAT_IPV6"

FAILED=""
for opt in $REQ; do
    if grep -q "^CONFIG_${opt}=y" out/.config; then
        echo "  [ok] CONFIG_${opt}=y"
    else
        echo "  [!!] CONFIG_${opt} NOT enabled"
        FAILED="$FAILED $opt"
    fi
done

for opt in $OPTIONAL; do
    if grep -q "^CONFIG_${opt}=y" out/.config; then
        echo "  [ok] CONFIG_${opt}=y"
    elif grep -q "CONFIG_${opt}" out/.config; then
        echo "  [!!] CONFIG_${opt} exists but is not =y"
        FAILED="$FAILED $opt"
    else
        echo "  [--] CONFIG_${opt} does not exist in 4.19 (renamed/folded upstream, skipped)"
    fi
done

if grep -q "^CONFIG_ANDROID_PARANOID_NETWORK=y" out/.config; then
    echo "  [!!] CONFIG_ANDROID_PARANOID_NETWORK still =y (containers lose internet)"
    FAILED="$FAILED ANDROID_PARANOID_NETWORK"
else
    echo "  [ok] CONFIG_ANDROID_PARANOID_NETWORK disabled"
fi

# FM_LOADER_COMPRESS: only exists on newer kernels, report but do not fail
grep -q "^CONFIG_FW_LOADER_COMPRESS=y" out/.config \
    && echo "  [ok] CONFIG_FW_LOADER_COMPRESS=y" \
    || echo "  [--] CONFIG_FW_LOADER_COMPRESS unavailable (optional on 4.19)"

if [ -n "$FAILED" ]; then
    echo "[!] DroidSpaces MISSING:$FAILED"
    echo "[!] Refusing to ship a kernel that cannot run containers."
    exit 1
fi
echo "[+] All mandatory DroidSpaces options are enabled."

echo "[*] Building kernel..."
make $MAKE_ARGS -j$(nproc)

[ -f out/arch/arm64/boot/Image ] || { echo "[!] build failed"; exit 1; }

echo "[*] Generating dtb..."
find out/arch/arm64/boot/dts -name '*.dtb' -exec cat {} + > out/arch/arm64/boot/dtb

rm -rf ${dts_source}
mv .dts.bak ${dts_source}

rm -rf anykernel/kernels
mkdir -p anykernel/kernels

# SukiSU KPM patch
cd out/arch/arm64/boot/
wget -q https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/0.12.0/patch_linux
chmod +x patch_linux
./patch_linux
rm -f Image
mv oImage Image
cd -

cp out/arch/arm64/boot/Image anykernel/kernels/
cp out/arch/arm64/boot/dtb anykernel/kernels/

sed -i "s/${local_version_date_str}/${local_version_str}/g" arch/arm64/configs/${TARGET_DEVICE}_defconfig

cd anykernel
ZIP_FILENAME=Kernel_MIUI_${TARGET_DEVICE}_SukiSU-SUSFS_DroidSpaces_$(date +'%Y%m%d_%H%M%S')_anykernel3_${GIT_COMMIT_ID}.zip
zip -r9 $ZIP_FILENAME ./* -x .git .gitignore out/ ./*.zip
mv $ZIP_FILENAME ../
cd ..

echo "[+] Done: ./$ZIP_FILENAME"
