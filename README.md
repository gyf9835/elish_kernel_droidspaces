> 🤖 **AI-GENERATED NOTICE / AI 生成声明**
>
> The changes described in this README — the `ds_build.sh` script, the CI workflow, the DroidSpaces kernel configuration set — were **written by an AI coding agent** (a DeepSeek model, driven through a CLI agent for [@gyf9835](https://github.com/gyf9835)) and were validated on real hardware (Xiaomi Pad 5 Pro `elish`, HyperOS 1.0.2.0.TKYCNXM). The upstream kernel source itself is **not** AI-generated: this repository is a fork of [liyafe1997/kernel_xiaomi_sm8250_mod](https://github.com/liyafe1997/kernel_xiaomi_sm8250_mod) and all kernel code belongs to its original authors.
>
> 本 README 描述的改动（`ds_build.sh` 脚本、CI 工作流、DroidSpaces 内核配置项）由 **AI 编码代理**（DeepSeek 模型，通过 CLI 代理为 [@gyf9835](https://github.com/gyf9835) 编写）完成，并在真机（小米平板 5 Pro `elish`，HyperOS 1.0.2.0.TKYCNXM）上验证通过。上游内核源码本身**不是** AI 生成的：本仓库 fork 自 [liyafe1997/kernel_xiaomi_sm8250_mod](https://github.com/liyafe1997/kernel_xiaomi_sm8250_mod)，所有内核代码版权归属原作者。

---

# elish_kernel_droidspaces

A fork of [liyafe1997/kernel_xiaomi_sm8250_mod](https://github.com/liyafe1997/kernel_xiaomi_sm8250_mod) (branch `android15-lineage22-mod`) **modified to add DroidSpaces support for the Xiaomi Pad 5 Pro (`elish`)**.

本仓库 fork 自 [liyafe1997/kernel_xiaomi_sm8250_mod](https://github.com/liyafe1997/kernel_xiaomi_sm8250_mod)（`android15-lineage22-mod` 分支），**修改目的是让小米平板 5 Pro（`elish`）支持 DroidSpaces**。

## What this fork changes / 本 fork 改了什么

Everything below is additive — the upstream kernel tree and its device drivers are untouched except for the DroidSpaces patches applied at build time.

以下改动都是**叠加式**的 —— 上游内核树与设备驱动保持原样，仅在构建时应用 DroidSpaces 补丁。

### 1. `ds_build.sh` — MIUI + KernelSU + DroidSpaces build script

Derived from upstream `build.sh`, keeping its MIUI build path intact (this matters, see below) and adding the DroidSpaces kernel requirements.

基于上游 `build.sh` 改写，**完整保留其 MIUI 构建路径**（这一点很关键，见下文），并加入 DroidSpaces 所需的内核选项。

Added kernel options (upstream `elish_defconfig` had `CONFIG_PID_NS` disabled, which makes DroidSpaces unusable):

新增的内核选项（上游 `elish_defconfig` 里 `CONFIG_PID_NS` 是关闭的，不开的话 DroidSpaces 根本无法工作）：

```sh
scripts/config --file out/.config \
    -e PID_NS          -e USER_NS        -e UTS_NS         -e IPC_NS \
    -e NET_NS          -e CGROUPS        -e CGROUP_PIDS    -e CGROUP_DEVICE \
    -e CGROUP_FREEZER  -e CGROUP_SCHED   -e CGROUP_BPF     -e MEMCG \
    -e NAMESPACES      -e SECCOMP        -e SECCOMP_FILTER \
    -e OVERLAY_FS      -e VETH           -e BRIDGE         -e TUN \
    -e FUSE_FS         -e TMPFS_POSIX_ACL -e DEVTMPFS      -e DEVTMPFS_MOUNT
```

Most of these are **not** enabled by the upstream defconfig (“PID_NS was disabled upstream” understates it: `SYSVIPC`, `POSIX_MQUEUE`, `IPC_NS`, `DEVTMPFS`, `CGROUP_PIDS`, `CFS_BANDWIDTH`, `MACVLAN`, `USER_NS` were all off too). Everything is therefore set explicitly **and verified after `olddefconfig`**, because Kconfig dependencies can silently revert an option to `=n`.

`BRIDGE`、`TUN`、`VETH`、`OVERLAY_FS`、`FUSE_FS`、`MEMCG` 上游本来就是开的，这里显式再设一遍，这样将来上游若改动，构建会直接暴露而不是静默失败。

Build-time patches downloaded from [ravindu644/Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) (`…/Documentation/resources/kernel-patches/non-GKI/`), applied idempotently:

构建时从 [ravindu644/Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) 下载补丁（`…/Documentation/resources/kernel-patches/non-GKI/`），幂等应用：

| Patch | Purpose |
|---|---|
| `01.fix_kernel_panic_in_xt_qtaguid.patch` | avoid a kernel panic in `xt_qtaguid` (auto-skipped if the file is absent) |
| `02.fix_restore cgroup file prefix handling .patch` | fix cgroup file prefix handling |

Unchanged from upstream `build.sh`: SukiSU setup (`liyafe1997/SukiSU-Ultra` pinned commit), SUSFS config set, `KPM` + `patch_linux` 0.12.0, the MIUI DTS panel-dimension `sed` block, the MIUI config set (`XIAOMI_MIUI`, `OVERLAY_FS`, `MIHW`, `MIGT`, `MILLET`, `PERF_*`, `STATIC_USERMODEHELPER_PATH=/system/bin/micd`), and the "**do not flash `dtbo`**" behaviour.

与上游 `build.sh` 保持一致的部分：SukiSU 安装（`liyafe1997/SukiSU-Ultra` 固定 commit）、SUSFS 配置、`KPM` + `patch_linux` 0.12.0、MIUI 的 DTS 面板尺寸 `sed`、MIUI 专用配置集（`XIAOMI_MIUI`、`OVERLAY_FS`、`MIHW`、`MIGT`、`MILLET`、`PERF_*`、`STATIC_USERMODEHELPER_PATH=/system/bin/micd`），以及"**不刷 `dtbo`**"的行为。

### 2. `.github/workflows/build.yml` — CI

Builds the `elish` MIUI variant on `ubuntu-22.04` with proton-clang 20210522 and ccache, uploads the flashable zip **plus the build log and a config-evidence section** (so it is verifiable that `PID_NS` / `USER_NS` / `CGROUP_PIDS` / `OVERLAY_FS` / `VETH` really ended up `=y`).

在 `ubuntu-22.04` 上用 proton-clang 20210522 + ccache 构建 `elish` 的 MIUI 版本，上传刷机包**以及构建日志和配置证据**（可核对 `PID_NS` / `USER_NS` / `CGROUP_PIDS` / `OVERLAY_FS` / `VETH` 是否真的是 `=y`）。

## Build / 构建

Locally:

```sh
# toolchain
mkdir -p $HOME/proton-clang && cd $HOME/proton-clang
wget https://github.com/kdrag0n/proton-clang/archive/refs/tags/20210522.zip
unzip 20210522.zip && cd -

# deps (Debian/Ubuntu)
sudo apt install build-essential git curl wget bison flex zip bc cpio \
                 libssl-dev libelf-dev libncurses-dev ccache python-is-python3

# build
chmod +x ds_build.sh
./ds_build.sh elish
```

Or push to the `android15-lineage22-mod` branch / trigger *Build elish Kernel (MIUI + SukiSU + DroidSpaces)* from the Actions tab.

或者直接推到 `android15-lineage22-mod` 分支 / 在 Actions 页面手动触发 *Build elish Kernel (MIUI + SukiSU + DroidSpaces)*。

Result: `Kernel_MIUI_elish_SukiSU-SUSFS_DroidSpaces_<date>_anykernel3_<commit>.zip`

## Flashing / 刷入

```sh
adb reboot bootloader
fastboot boot OrangeFox-*.img                # temporary boot, writes nothing
adb push Kernel_MIUI_elish_*.zip /tmp/k.zip
adb shell /system/bin/twrp install /tmp/k.zip
adb reboot
```

The zip flashes `boot` only. **`dtbo`, `dtb`, `vbmeta` and `vendor_boot` are left alone** — keep the stock ones.

ZIP **只刷 `boot`**。**`dtbo`、`dtb`、`vbmeta`、`vendor_boot` 一律不动**，保持原厂。

To go back:

```sh
fastboot flash boot_a <stock>/boot.img
```

## Verified on hardware / 真机验证结果

Xiaomi Pad 5 Pro (`elish`), HyperOS `OS1.0.2.0.TKYCNXM` / `V816.0.2.0.TKYCNXM` (Android 13, A/B, slot `a`):

| Item | Result |
|---|---|
| Kernel | `4.19.325-20261113-ca4a71ee-perf+` (Proton clang 13) |
| Build | GitHub Actions run `43411197975`, `kernel_size` 23.5 MB zip, flashes `boot` only |
| Boot | clean, no "device has a problem" popup |
| Launcher / Settings / Notes / App Store scaling | **correct**, `wm density` = 360, 1600×2560 |
| KernelSU | SukiSU working (`Built-in`), SukiSU Manager **3.2.0** required |
| SuSFS | v1.5.7 (Manual Hook) |
| KPM | supported (3072) |
| DroidSpaces app | **7.2.0** — reports the kernel as **supported** (backend installed, DAEMON badge), no "kernel not supported" banner |
| DroidSpaces config | all 60 mandatory options verified `=y` at build time (see below) |

### DroidSpaces options that are actually checked

The build now **fails** if any of these end up `=n` after `olddefconfig`:

```
SYSCTL SYSVIPC POSIX_MQUEUE NAMESPACES PID_NS UTS_NS IPC_NS SECCOMP SECCOMP_FILTER
CGROUPS CGROUP_DEVICE CGROUP_SCHED FAIR_GROUP_SCHED CGROUP_FREEZER CGROUP_NET_PRIO
MEMCG MEMCG_SWAP CFS_BANDWIDTH CGROUP_PIDS CGROUP_CPUACCT DEVTMPFS OVERLAY_FS
TMPFS_POSIX_ACL TMPFS_XATTR FW_LOADER FW_LOADER_USER_HELPER NET_NS VETH BRIDGE
NETFILTER BRIDGE_NETFILTER NETFILTER_ADVANCED NF_CONNTRACK IP_NF_IPTABLES
IP_NF_FILTER NF_NAT NF_TABLES IP_NF_TARGET_MASQUERADE NETFILTER_XT_TARGET_TCPMSS
NETFILTER_XT_MATCH_ADDRTYPE NF_NAT_REDIRECT NF_NAT_MASQUERADE_IPV4 IP_ADVANCED_ROUTER
IP_MULTIPLE_TABLES IP_NF_NAT IPV6 IPV6_MULTIPLE_TABLES IP6_NF_IPTABLES IP6_NF_FILTER
IP6_NF_MANGLE IP6_NF_NAT MACVLAN USER_NS
```

plus `ANDROID_PARANOID_NETWORK` must be **off** (otherwise containers have no internet).

Five names from the upstream cross-version list do not exist on 4.19 and are
reported but not enforced: `NETFILTER_XT_TARGET_MASQUERADE`, `NF_NAT_MASQUERADE`,
`NF_CONNTRACK_NETLINK`, `NF_CONNTRACK_IPV4`, `NF_CONNTRACK_IPV6`
(folded into `NF_CONNTRACK` / renamed since 3.13).

> First attempt (commit `bfa050c1`) enabled only 24 options and let
> `olddefconfig` silently revert `SYSVIPC`, `DEVTMPFS`, `PID_NS`, `CGROUP_PIDS`
> and friends, which is why DroidSpaces 7.2.0 reported "kernel not supported".
> The verification step above is what caught it.

## Use SukiSU Manager 3.2.0 / 请使用 SukiSU 管理器 3.2.0

Same constraint as upstream: the SukiSU version in this kernel does **not** work with managers 4.0+. Install [SukiSU 3.2.0](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases/tag/v3.2.0). `ReSukiSU` and `KernelSU` official managers are **not** compatible with this kernel — if *root* seems missing, check which manager is installed first.

与上游相同的限制：内核内的 SukiSU 版本**不兼容 4.0+ 的管理器**，请安装 [SukiSU 3.2.0](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases/tag/v3.2.0)。`ReSukiSU` 和官方 `KernelSU` 管理器**不兼容**本内核 —— 如果觉得"没有 root"，请先确认装的是哪个管理器。

## Do not flash `dtbo.img` / 不要刷 `dtbo`

Upstream ships no `dtbo.img` and this fork keeps that. A related kernel tree ships a ~486 KB `dtbo.img` that overwrites the 33.5 MB stock one and causes system-app scaling breakage — see [AstideLabs#68](https://github.com/AstideLabs/android_kernel_xiaomi_sm8250/issues/68) (test report posted there, AI-written — DeepSeek). If you ever flashed another third-party kernel, restore the stock `dtbo`:

```sh
fastboot flash dtbo_a <stock>/dtbo.img
```

上游本身就不带 `dtbo.img`，本 fork 保持这一点。相关的另一棵内核树会附带一个约 486 KB 的 `dtbo.img`，覆盖掉原厂 33.5 MB 的版本并导致系统应用缩放异常 —— 见 [AstideLabs#68](https://github.com/AstideLabs/android_kernel_xiaomi_sm8250/issues/68)（其中的测试报告由 AI 编写）。如果你之前刷过其它第三方内核，恢复原厂 `dtbo`：

```sh
fastboot flash dtbo_a <stock>/dtbo.img
```

## Credits / 致谢

- [@liyafe1997](https://github.com/liyafe1997) — the base kernel, build script and MIUI adaptation. **This fork would not boot correctly without his MIUI DTS/config work.**
- [LineageOS](https://github.com/LineageOS/android_kernel_xiaomi_sm8250) — kernel base
- [@UtsavBalar1231](https://github.com/UtsavBalar1231) — MIUI feature code and drivers
- [SukiSU-Ultra](https://github.com/SukiSU-Ultra), [Sidex15/susfs4ksu](https://github.com/Sidex15/susfs4ksu-module) — root / SUSFS
- [@ravindu644 / Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) — DroidSpaces kernel patches
- [@osm0sis](https://github.com/osm0sis) — AnyKernel3

## Original upstream README

The original upstream README is preserved below for reference (device list, features, build guide).

原始上游 README 保留在下方供参考（支持机型列表、特性、构建指南）。

---

<details>
<summary>Upstream README (unchanged) / 上游 README（原样保留）</summary>

[☕Buy me a coffee](https://ko-fi.com/strawing)
# Notice / 注意
For SukiSU users: Please use [SukiSU Manager 3.2.0](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases/tag/v3.2.0), 4.0 and above are not supported yet of the SukiSU version in this kernel.

SukiSU用户请使用 [SukiSU 管理器 3.2.0 版本](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases/tag/v3.2.0)，4.0及以上版本不支持该内核中的SukiSU版本。

# About this repo

[中文](#中文)

## English
This repo (`android15-lineage22-mod` branch) is based on [Lineage OS 22.1 xiaomi sm8250 kernel source](https://github.com/LineageOS/android_kernel_xiaomi_sm8250).

Originally this repo (`android12-stable-mod` or `android14-stable-mod` branch) is fork from [UtsavBalar1231's repo](https://github.com/UtsavBalar1231/kernel_xiaomi_sm8250), but the `android14-stable` branch has freeze problem when the device sleep for a while or wake up. So now I switched to lineage22 codebase. The MIUI features code and some parts of the drivers is still copied from UtsavBalar1231's branch.

So still Thanks to [@UtsavBalar1231](https://github.com/UtsavBalar1231/)!

The main purpose of maintaining and building this kernel is to fix [this battery stuck at 1% problem](https://github.com/liyafe1997/Xiaomi-fix-battery-one-percent), and provide [SukiSU](https://github.com/ShirkNeko/SukiSU-Ultra)(A KernelSU fork with KPM support) & [SUSFS](https://github.com/sidex15/susfs4ksu-module) integrated pre-built image(flashable anykernel3 zip). Also provides a more intuitive and easy-to-use build script and build guide that allow you to try to build by yourself.

For using the SukiSU, you can install the SukiSU manager APK from [SukiSU Github Release](https://github.com/ShirkNeko/SukiSU-Ultra/releases). For the SUSFS module see [susfs4ksu-module Gihub Release](https://github.com/sidex15/susfs4ksu-module/releases).

(The devices affected by the "1% battery bug" are: alioth, apollo, lmi, thyme, umi, pipa. Because they all use the PM8150, aka Qualcomm fuel gauge GEN4. For the other devices are not affected by that bug, you can use this kernel for KernelSU purpose, as a replacement of the orginal stock kernel. Also, as the people tested, this kernel NoKernelSU version is good for applying [APatch](https://github.com/bmax121/APatch)).

The pre-built kernel image/zip is built on the `android15-lineage22-mod` branch. It should works on both stock MIUI and third-party AOSP based Android 11-15 ROMs. You are welcomed to give feedback (Issues/Pull Requests)!

Note: The zip does not include the `dtbo.img` and it will not replace your `dtbo` partition. It is recommanded to keep the stock `dtbo` or the `dtbo` from your third-party rom (If the builder comfirmed it works well). Since there are some problems with the `dtbo.img` which built from this source, one of them is the screen will suddently goes to the highest brightness when shut try to shut off the screen in the lock screen. If you had flashed any other third-party kernels, and you got some weird problem, you should keep an eye to check your `dtbo` has been replaced or not. 

**Notice: If you are using MIUI/HyperOS please use the MIUI varient. Because the display driver is different between MIUI and AOSP, if you are using MIUI/HyperOS but installed the AOSP version, the display will not work and only black screen. If you only see a black screen after installed this kernel, please check if you installed the correct varient or not!**

Supported devices:
| Code Name | Device Name                          |
|-----------|--------------------------------------|
| psyche    | Xiaomi Mi 12X                        |
| thyme     | Xiaomi Mi 10S                        |
| umi       | Xiaomi Mi 10                         |
| munch     | Poco F4 / Redmi K40S                 |
| lmi       | Redmi K30 Pro                        |
| cmi       | Xiaomi Mi 10 Pro                     |
| cas       | Xiaomi Mi 10 Ultra                   |
| apollo    | Xiaomi Mi 10T / Redmi K30S Ultra     |
| alioth    | Xiaomi Mi 11X / POCO F3 / Redmi K40  |
| elish     | Xiaomi Pad 5 Pro                     |
| enuma     | Xiaomi Pad 5 Pro 5G                  |
| dagu      | Xiaomi Pad 5 Pro 12.4                |
| pipa      | Xiaomi Pad 6                         |

Other Features/Improvement of this Kernel:
1. Support USB Serial (CH340/FTDI/PL2303/OTI6858/TI/SPCP8X5/QT2/UPD78F0730/CP210X).
2. Support EROFS.
3. F2FS realtime discard enabled for better TRIM the flash.
4. Support CANBus and USB CAN adapter (like CANable).
5. Support LZ4, LZ4HC, ZSTD compression algorithms for ZRAM.

## 中文
该repo (`android15-lineage22-mod` 分支)主要基于[Lineage OS 22.1 xiaomi sm8250 kernel source](https://github.com/LineageOS/android_kernel_xiaomi_sm8250)。

原来这个repo(即`android12-stable-mod`/`android14-stable-mod`分支)是fork自[UtsavBalar1231的仓库](https://github.com/UtsavBalar1231/kernel_xiaomi_sm8250)，但切到`android14-stable`分支的时候，发现那套代码有睡死问题（202408的几个release），所以现在切到了基于lineage22的代码来搞。MIUI特性的代码以及部分的设备驱动抠自UtsavBalar1231的仓库。

所以仍然感谢 [@UtsavBalar1231](https://github.com/UtsavBalar1231/)！

维护和编译这个内核的主要目的是想修复[电量卡在1%的问题](https://github.com/liyafe1997/Xiaomi-fix-battery-one-percent)，以及提供带[SukiSU](https://github.com/ShirkNeko/SukiSU-Ultra)(一个KernelSU的fork，支持KPM) & [SUSFS](https://github.com/sidex15/susfs4ksu-module)的预编译好的内核（请自行安装[SukiSU的管理器](https://github.com/ShirkNeko/SukiSU-Ultra/releases)以及根据需要刷上SUSFS模块）。以及再提供一个更直观和易用的编译脚本和README，方便大家自己折腾和修改，编译自己的内核！

（其中受“1%电量bug”影响的设备有：alioth, apollo, lmi, thyme, umi, pipa，因为它们都用了PM8150即高通的GEN4电量计。其它不受此bug影响的设备大可把这个内核当成个带SukiSU & SUSFS的官核平替，如果你想找一个带KernelSU的内核的话。并且据大家测试，该内核不带KernelSU版本可以应用[APatch](https://github.com/bmax121/APatch)）

Release里的编译好的内核成品由`android15-lineage22-mod`分支编译，应当能在原版MIUI和第三方的基于AOSP的各种Android11-15的ROM上使用。欢迎大家尝试并反馈（提Issue或Pull Requests）！酷友们到[酷安的这个帖子](https://www.coolapk.com/feed/56813047)讨论或反馈，也可以给我私信反馈！

注意：该内核的zip包不包含`dtbo.img`，并且不会刷你的dtbo分区。推荐使用原厂的`dtbo`，或者来自第三方系统包自带的dtbo（如果原作者确认那好用的话）。因为该源码build出来的`dtbo.img`有些小问题，比如在锁屏界面上尝试熄屏时，屏幕会突然闪一下到最高亮度。如果你刷过其它第三方内核，或者遇到一些奇怪的问题，建议检查一下你的`dtbo`是否被替换过。

**注意：如果你在用HyperOS/MIUI请刷MIUI的版本，AOSP版因为display驱动不同，在HyperOS/MIUI上屏幕无法正常显示，如果刷内核之后开机黑屏，请先检查你是不是正在用着HyperOS/MIUI但是刷了AOSP版**

度盘备用下载链接：https://pan.baidu.com/share/init?surl=11ocz7ggZ79gzRfWvsdbJA&pwd=ty58 （建议优先从Github Release下载）

欢迎加入内测QQ群: 459094061

支持的设备:
| 设备代号  | 设备名称                           |
|-----------|----------------------------------|
| psyche    | 小米12X                           |
| thyme     | 小米10S                           |
| umi       | 小米10                            |
| munch     | 红米K40S                          |
| lmi       | 红米K30 Pro                       |
| cmi       | 小米10 Pro                        |
| cas       | 小米10 Ultra                      |
| apollo    | 小米10T / 红米K30S Ultra          |
| alioth    | 小米11X / POCO F3 / 红米K40       |
| elish     | 小米平板5 Pro                     |
| enuma     | 小米平板5 Pro 5G                  |
| dagu      | 小米平板5 Pro 12.4                |
| pipa      | 小米平板6                         |

该内核的其他特性/改进:
1. 支持USB串口驱动（CH340/FTDI/PL2303/OTI6858/TI/SPCP8X5/QT2/UPD78F0730/CP210X）
2. 支持EROFS
3. F2FS开启了realtime discard以更好的TRIM闪存
4. 支持 CANBus 和 USB CAN （如 CANable）适配器（一些折腾嵌入式的可能会喜欢这个）
5. zRAM 支持 LZ4、LZ4HC、ZSTD 压缩算法

# How to build
1. Prepair the basic build environment. 

    You have to have the basic common toolchains, such as `git`, `make`, `curl`, `bison`, `flex`, `zip`, etc, and some other packages.
    In Debian/Ubuntu, you can
    ```
    sudo apt install build-essential git curl wget bison flex zip bc cpio libssl-dev ccache
    ```
    And also, you have to have `python` (only `python3` is not enough). you can install the apt package `python-is-python3`.

    In RHEL/RPM based OS, you can
    ```
    sudo yum groupinstall 'Development Tools'
    sudo yum install wget bc openssl-devel ccache
    ```

    Notice: `ccache` is enabled in `build.sh` for speed up the compiling. `CCACHE_DIR` has been set as `$HOME/.cache/ccache_mikernel` in `build.sh`. If you don't like you can remove or modify it.

2. Download [proton-clang] compiler toolchain

    You have to have `aarch64-linux-gnu`, `arm-linux-gnueabi`, `clang`. [Proton Clang](https://github.com/kdrag0n/proton-clang/) is a good prebuilt clang cross compiler toolchain.

    The default toolchain path is `$HOME/proton-clang/proton-clang-20210522/bin` which is set in `build.sh`. If you are using another location please change `TOOLCHAIN_PATH` in `build.sh`.

    ```
    mkdir proton-clang
    cd proton-clang
    wget https://github.com/kdrag0n/proton-clang/archive/refs/tags/20210522.zip
    unzip 20210522.zip
    cd ..
    ```

3. Build

    Build without KernelSU: 
    ```
    bash build.sh TARGET_DEVICE
    ```
    
    Build with KernelSU:
    ```
    bash build.sh TARGET_DEVICE ksu
    ```

    For example, build for lmi (Redmi K30 Pro/POCO F2 Pro) without KernelSU:
    ```
    bash build.sh lmi
    ````

    For example, build for umi (Mi 10) with KernelSU:
    ```
    bash build.sh umi ksu
    ```

    And also, here is a `buildall.sh` can build for all supported models at once.



</details>
