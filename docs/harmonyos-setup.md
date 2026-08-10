# HarmonyOS 构建环境搭建指南

本文档是 `FlClash-HarmonyOS` fork 的鸿蒙构建上手指南。鸿蒙适配的实现细节与排障记录见
[harmonyos.md](harmonyos.md)，真机验证结果见
[ohos-real-device-test-report.md](ohos-real-device-test-report.md)。

## 硬件与系统要求

- **开发机：macOS 或 Windows**。DevEco Studio 没有 Linux 版本，HAP 构建、签名、模拟器、
  真机调试都无法在 Linux 上完成。
- **验证设备：鸿蒙真机**（已在华为 Mate 80 Pro / OpenHarmony 6.1.1 上验证通过）。
  模拟器只能验证应用启动与核心 FFI 调用，**不支持系统 VPN 授权**，也不支持部分实验性
  运行时路径依赖的子进程 API。

## 软件准备

### 1. DevEco Studio + OpenHarmony SDK

安装 DevEco Studio，并通过其 SDK Manager 安装 OpenHarmony SDK（已验证组合：
OpenHarmony 6.0.2(22) 及 6.1.1）。确认以下工具可用：

- `hvigor`（构建）
- `ohpm`（包管理）
- `hdc`（设备调试）

配置环境变量（`flutter pub get` 之前必须设置，OHOS 构建插件在依赖解析阶段就会检查）：

```bash
export OHOS_SDK_HOME=/path/to/sdk/default/openharmony
export OHOS_BASE_SDK_HOME=$OHOS_SDK_HOME
```

如果 DevEco Studio 同步时报缺少 `toolchains:24` / `ArkTS:24` / `js:24` / `native:24` /
`previewer:24`，运行 `scripts/ohos/prepare_deveco_sdk_link.sh` 创建 IDE 期望的
版本化 SDK 链接（如 `~/Library/OpenHarmony/Sdk/24`）。

### 2. OpenHarmony Flutter SDK

本仓库要求 Dart `>=3.8.0`，已验证**唯一可用**的是 `oh-3.35.7-release` 分支
（内置 Dart 3.9.2）。更旧的 `3.7.12-ohos-1.0.4`（Dart 2.19.6）和
`3.22.1-ohos-1.1.x`（Dart 3.4.0）均不满足要求。

```bash
git clone -b oh-3.35.7-release https://gitee.com/openharmony-sig/flutter_flutter.git
export PATH="$PWD/flutter_flutter/bin:$PATH"
flutter config --enable-ohos
flutter config --ohos-sdk <OpenHarmony SDK 路径>
```

注意：该分支快照在部分环境下 `flutter --version` 会显示 `0.0.0-unknown`，属已知现象，
不影响构建。

## 获取代码

```bash
git clone --recurse-submodules https://github.com/shenyingjun5/FlClash-HarmonyOS.git
cd FlClash-HarmonyOS
```

子模块 URL 已全部改为 HTTPS。已知偏差：`core/Clash.Meta` 指向的是上游 `FlClash` 分支
HEAD（`80362fc`）——原移植作者（phenix3443）本地的一个提交（`3e933a6d`）从未推送、
已丢失。OHOS 的关键改造（sing-tun 替换、gVisor 补丁、TUN 强制 gVisor 栈）都在主仓库侧，
预期不受影响；若编译报 mihomo API 相关错误，需要到上游 PR #2120 请作者补推该提交。

## 构建

```bash
flutter pub get        # 确认 OHOS_SDK_HOME 已设置
dart setup.dart ohos   # 完整 release 流程
```

`dart setup.dart ohos` 会在首次运行时自动准备打过补丁的 Go 工具链
（`.ohos_toolchain/go-nonglibc`，`R_AARCH64_TLSDESC` TLS 模型，使 `libclash.so`
能被 OHOS musl 加载器接受），并通过 `scripts/ohos/patch_gvisor_tun_fd.sh` 给 Go module
缓存中的 gVisor `fdbased` 打补丁（OHOS 沙箱里 tun fd 无法 `Fstat`）。

也可以用鸿蒙 Flutter SDK 直接构建调试包：

```bash
flutter build hap --debug --target-platform ohos-arm64
```

产物路径：

- hvigor 原始产物：`ohos/entry/build/default/outputs/default/entry-default-signed.hap`
- `setup.dart` 拷贝的发布产物：`dist/FlClash-<version>-ohos-arm64.hap`

## 签名

- **调试/自测**：hvigor wrapper 会自动用 OpenHarmony SDK 自带的 demo keystore 完成签名，
  无需额外配置。
- **正式发布**：需要注册华为开发者账号，申请发布证书与 profile，替换签名配置。

## 安装与真机验证

```bash
# 保持设备唤醒（测试结束后用 power-shell timeout -r 恢复）
hdc shell "power-shell wakeup"
hdc shell "power-shell timeout -o 1800000"

# 安装并启动
scripts/ohos/install_and_launch.sh

# 一键回归（22 项，覆盖 VPN、浏览器代理、连接统计等）
scripts/ohos/verify_all.sh
```

`hdc list targets` 应只显示一个目标；多设备时用 `hdc -t <target>` 指定。

## 已知限制

- **非浏览器类 Web 容器应用 DNS 不经过 VPN**：OpenHarmony 的 UID 级 socket 重绑定
  （`EnableVnicNetwork` / `CloseSocketsUid`）被 `ohos.permission.CONNECTIVITY_INTERNAL`
  保护，该权限仅系统应用可用。华为浏览器、Chrome 等已验证正常，个别 Web 容器应用
  会报 `dnsServerReturnNothing`。这是平台限制，非代码缺陷。
- **模拟器**：不支持系统 VPN 授权，不支持部分子进程 API，只能做启动冒烟测试。
- **`core/Clash.Meta` 子模块指针**：见上文「获取代码」，首次完整编译时留意。

## 参考

- 移植工作日志与排障记录：[harmonyos.md](harmonyos.md)
- 真机测试报告：[ohos-real-device-test-report.md](ohos-real-device-test-report.md)
- 上游移植 PR：[chen08209/FlClash#2120](https://github.com/chen08209/FlClash/pull/2120)
