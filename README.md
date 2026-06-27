# LocalSend for Android 4.4 · 安卓 4.4 版

> An unofficial community fork of [**LocalSend**](https://github.com/localsend/localsend) that runs on **old Android** — from **Android 4.4 KitKat (API 19)** all the way to modern Android.
>
> 一个非官方社区分支,让 [**LocalSend**](https://github.com/localsend/localsend) 重新运行在**老旧安卓**上 —— 从 **Android 4.4 KitKat(API 19)** 一直到最新 Android。

**🌐 [English](#english) ｜ [中文](#中文)**

---

## 📥 Download / 下载

Click a file to download directly · 点击文件名即可直接下载:

| APK | minSdk | For / 适用设备 |
|---|---|---|
| [**LocalSend-1.15.1.6fix-android-arm64-v8a.apk**](https://github.com/boobasha/LocalSend-Android4.4/releases/download/v1.15.1.6fix/LocalSend-1.15.1.6fix-android-arm64-v8a.apk) | **21** | 64-bit phones, Android 5.0+ · 64 位手机(安卓 5.0+),不确定就选它 |
| [**LocalSend-1.15.1.6fix-android4.4-armeabi-v7a.apk**](https://github.com/boobasha/LocalSend-Android4.4/releases/download/v1.15.1.6fix/LocalSend-1.15.1.6fix-android4.4-armeabi-v7a.apk) | **19** | 32-bit / old devices incl. Android 4.4 · 32 位 / 老设备,含安卓 4.4 KitKat |

Both are version `1.15.1.6fix`. Package `org.localsend.localsend_app.android44` — installs **alongside** the official LocalSend. To sideload, enable *"Install unknown apps"* in Settings. See all files on the **[Releases](../../releases)** page.

> 两个包都是 `1.15.1.6fix`,包名为 `org.localsend.localsend_app.android44`,可与官方版**共存**。侧载需在系统设置里允许「安装未知应用」。全部文件见 **[Releases](../../releases)** 页面。

---

<a name="english"></a>
# English

## What is LocalSend?

LocalSend is an open-source, cross-platform alternative to AirDrop. It lets you send **files, photos, and text** between devices on the **same local network** — no internet, no account, no cloud.

- Transfers go over an **encrypted (TLS) HTTP connection**.
- Devices find each other automatically using **UDP multicast discovery**.
- Nothing leaves your local network.

This fork keeps all of that and makes it work on Android 4.4+.

## Features

Everything from upstream LocalSend v1.15.1, plus:

- 📁 **Send files, photos, and text** between devices on the same network.
- 🔒 **Encrypted (TLS)** transfers — no internet or account required.
- 📡 **Automatic device discovery** via UDP multicast.
- 🌍 **Cross-platform** — interoperates with LocalSend on Windows, macOS, Linux, iOS, and Android (incl. the **official** desktop apps).
- 🎨 **NEW: Custom theme color.**

### Custom theme color (new in this fork)

Android **below 12** can't read the system accent color (Material You / dynamic color needs Android 12+), so on KitKat the app was stuck with a fixed teal theme. This fork adds a **manual color picker**:

- **Settings → Color** shows a row of **12 preset swatches**: teal (default), blue, indigo, deep purple, pink, red, deep orange, amber, green, cyan, brown, blue grey.
- Tap one and the whole app **re-themes instantly** (light & dark).
- The color is used as the **Material 3 seed color** and is **saved** (in `SharedPreferences`).

## Why v1.15.1? (the version ceiling)

v1.15.1 is the **highest upstream version that actually runs on Android 4.4**:

- **v1.16.0+ is impossible on 4.4** — it added a **Rust HTTP client** (`rhttp`, needs API 21+) and requires **Dart ≥ 3.5 / Flutter ≥ 3.24**, but **Flutter 3.22+ dropped KitKat (API 19/20)** entirely.
- **v1.15.2 / 1.15.3 / 1.15.4 crash on 4.4** — v1.15.2 moved discovery into a **background Dart isolate** (PR *"Discover in different thread #1555"*). That code, AOT-compiled for armeabi-v7a, triggers a **Dart AOT compiler bug** → native **SIGSEGV** in `libflutter.so` at the first frame. Confirmed by bisecting all four versions on real hardware: v1.15.1 runs; 1.15.2/3/4 all crash.

So **v1.15.1 is the definitive working ceiling** (it already includes upstream fixes for the ">2 GB transfer" crash and the Android TV picker crash). Newer 1.16.0+/2.x code can't be cleanly back-ported (it's built on the diverged Rust/`rhttp` + Flutter 3.24 + `HttpServer` + isolate codebase).

## What works on KitKat

| Capability | Android 4.4 |
|------------|:-----------:|
| Receive files / photos / text | ✅ |
| Send individual files / media / text | ✅ |
| Device discovery + transfer | ✅ |
| **Send an entire folder** | ❌ |

**Known limitation:** sending an **entire folder** doesn't work on Android 4.4 — the Storage Access Framework directory picker (`ACTION_OPEN_DOCUMENT_TREE`) is API 21+. It's guarded to **degrade gracefully** (shows an error) instead of crashing. Everything else, incl. **all receiving**, works.

## Back-ported fixes (the "6fix")

Six small, isolate-independent fixes cherry-picked onto v1.15.1:

1. **Receive large files without OOM** (PR #1547) — flush to disk every 10 MB instead of buffering the whole file in RAM.
2. **Send large files without OOM** (PR #1661) — stream via a managed `StreamController` instead of `.asBroadcastStream()`.
3. **Any absolute URI is clickable** (PR #1662) — `file://`, `obsidian://`, etc., not just `http(s)`.
4. **Tooltip on the "Scan" button** (from v1.15.4).
5. **Path-traversal security fix** (from v1.17.0) — rejects `../` in a file name that would write outside the download folder (`p.isWithin` check).
6. **Duplicate text-message fix** (PR #2296) — a received text was shown three times in the history dialog.

## Android-compatibility changes (vs stock v1.15.1)

- `minSdkVersion` 21 → **19** (the arm64-v8a build uses 21).
- **Multidex** enabled (`MultiDexApplication`) — below API 21 the ~50 plugins exceed the 64K-method single-dex limit.
- `MainActivity`: SAF "pick a folder" paths guarded (API 21+) to fail gracefully on KitKat.
- Distinct **`applicationId`** (`org.localsend.localsend_app.android44`) so it coexists with the official app.
- Aliyun maven mirrors for Gradle (China network only); Gradle daemon/parallelism disabled for low-RAM builds.

## Reference / test device

Verified to launch and run on a **Xiaomi Redmi Note 1** — **Android 4.4.4 KitKat**, **armeabi-v7a** (32-bit): the app launches, the UI renders, and discovery + transfer work.

## Build from source

Toolchain: **Flutter 3.13.9** (pinned in `.fvmrc`), Dart 3.1.x, **JDK 17**, Android **platform-34 + build-tools 34.0.0**, AGP 7.2.0, Gradle 7.5.

```bash
# armeabi-v7a (Android 4.4+), minSdk 19
flutter build apk --release --target-platform android-arm   --build-name=1.15.1.6fix --build-number=50

# arm64-v8a (Android 5.0+): set minSdkVersion 21 in app/android/app/build.gradle first
flutter build apk --release --target-platform android-arm64 --build-name=1.15.1.6fix --build-number=50
```

## Credits & License

A fork of the official **[LocalSend](https://github.com/localsend/localsend)** by **Tien Do Nam** and contributors — all credit for LocalSend goes to the upstream project. Licensed under the **MIT License**, `Copyright (c) 2022-2024 Tien Do Nam`; this fork keeps the original license and copyright (see [`LICENSE`](./LICENSE)).

> **Unofficial community build.** Not affiliated with or endorsed by the official LocalSend project. Provided "as is," without warranty.

---

<a name="中文"></a>
# 中文

## LocalSend 是什么?

LocalSend 是一个开源、跨平台的 AirDrop 替代方案,让你在**同一局域网**内的设备之间发送**文件、照片和文本** —— 无需联网、无需账号、无需云端。

- 传输通过**加密(TLS)的 HTTP 连接**进行。
- 设备之间通过 **UDP 组播(multicast)自动发现**。
- 数据不会离开你的局域网。

本分支保留了以上全部能力,并让它能运行在 Android 4.4 及以上的设备上。

## 功能特性

包含官方 LocalSend v1.15.1 的全部功能,并新增:

- 📁 在同一网络的设备间**发送文件、照片和文本**。
- 🔒 **加密(TLS)** 传输 —— 无需联网、无需账号。
- 📡 通过 UDP 组播**自动发现设备**。
- 🌍 **跨平台** —— 可与 Windows、macOS、Linux、iOS、Android 上的 LocalSend(含**官方**桌面版)互通。
- 🎨 **新增:自定义主题颜色。**

### 自定义主题颜色(本分支新增)

**Android 12 以下**读不到系统强调色(Material You / 动态取色需要 Android 12+),所以 KitKat 上主题一直被固定为青色。本分支新增了一个**手动取色器**:

- 进入 **设置 → 颜色**,会看到一行 **12 个预设色块**:青色(默认)、蓝、靛蓝、深紫、粉、红、深橙、琥珀、绿、青蓝、棕、蓝灰。
- 点任意一个,整个应用**立即重新着色**(浅色 / 深色都生效)。
- 所选颜色作为 **Material 3 的种子色**,并**持久化保存**(存于 `SharedPreferences`)。

## 为什么是 v1.15.1?(版本天花板)

v1.15.1 是**官方版本中能真正在 Android 4.4 上运行的最高版本**:

- **v1.16.0+ 在 4.4 上根本不可能** —— 引入了 **Rust HTTP 客户端**(`rhttp`,需 API 21+),并要求 **Dart ≥ 3.5 / Flutter ≥ 3.24**,而 **Flutter 3.22+ 已完全移除对 KitKat(API 19/20)的支持**。
- **v1.15.2 / 1.15.3 / 1.15.4 在 4.4 上崩溃** —— v1.15.2 把网络发现移进了**后台 Dart isolate**(PR *"Discover in different thread #1555"*)。这段代码为 armeabi-v7a 做 AOT 编译后,会触发 **Dart AOT 编译器 bug** → `libflutter.so` 内在第一帧发生原生 **SIGSEGV**。已在真机上对四个版本逐一二分验证:v1.15.1 可运行,1.15.2/3/4 全崩。

所以 **v1.15.1 是确定的可用天花板**(它已包含官方对 ">2 GB 文件传输崩溃" 和 Android TV 选择器崩溃的修复)。1.16.0+/2.x 的更新内容无法干净回移植(都建立在分叉后的 Rust/`rhttp` + Flutter 3.24 + `HttpServer` + isolate 代码库之上)。

## KitKat 上哪些功能可用

| 能力 | Android 4.4 |
|------|:-----------:|
| 接收文件 / 照片 / 文本 | ✅ |
| 发送单个文件 / 媒体 / 文本 | ✅ |
| 设备发现 + 传输 | ✅ |
| **发送整个文件夹** | ❌ |

**已知限制:** 在 Android 4.4 上**发送整个文件夹**不可用 —— SAF 目录树选择器(`ACTION_OPEN_DOCUMENT_TREE`)属于 API 21+。该路径已做保护,会**优雅降级**(弹错误提示)而不是崩溃。其余功能,包括**全部接收**,均正常。

## 已回移植的修复("6fix")

在 v1.15.1 之上挑选了 6 个与 isolate 无关的小修复:

1. **接收大文件不再 OOM**(官方 PR #1547)—— 每 10 MB 周期性刷盘,不再把整个文件缓存在内存。
2. **发送大文件不再 OOM**(官方 PR #1661)—— 用受管理的 `StreamController` 流式发送,取代会缓存整文件的 `.asBroadcastStream()`。
3. **任意绝对 URI 可点击**(官方 PR #1662)—— `file://`、`obsidian://` 等也可点,不只 `http(s)`。
4. **"扫描"按钮的提示气泡**(取自 v1.15.4)。
5. **路径穿越安全修复**(从 v1.17.0 回移植)—— 拒绝文件名里用 `../` 把文件写到下载目录之外(`p.isWithin` 检查)。
6. **文本消息重复显示修复**(官方 PR #2296)—— 收到的一条文本曾在历史对话框里显示三次。

## 安卓兼容性改动(相对原版 v1.15.1)

- `minSdkVersion` 由 21 降到 **19**(arm64-v8a 包用 21)。
- **启用 multidex**(`MultiDexApplication`)—— API 21 以下约 50 个插件会超出 64K 方法的单 dex 上限。
- `MainActivity`:对 SAF "选文件夹" 路径(API 21+)加保护,使其在 KitKat 上优雅失败。
- 使用**独立包名** `org.localsend.localsend_app.android44`,可与官方版共存。
- 为 Gradle 加阿里云 Maven 镜像(仅中国网络需要);关闭 Gradle daemon / 并行以适配低内存构建。

## 参考 / 测试设备

已在 **红米 Note 1**(**Android 4.4.4 KitKat**、**armeabi-v7a** 32 位)真机上验证:可正常启动、界面渲染、设备发现与传输。

## 从源码构建

工具链:**Flutter 3.13.9**(锁定于 `.fvmrc`)、Dart 3.1.x、**JDK 17**、Android **platform-34 + build-tools 34.0.0**、AGP 7.2.0、Gradle 7.5。

```bash
# armeabi-v7a(安卓 4.4+),minSdk 19
flutter build apk --release --target-platform android-arm   --build-name=1.15.1.6fix --build-number=50

# arm64-v8a(安卓 5.0+):先把 app/android/app/build.gradle 里的 minSdkVersion 改成 21
flutter build apk --release --target-platform android-arm64 --build-name=1.15.1.6fix --build-number=50
```

## 致谢与许可证

本项目是官方 **[LocalSend](https://github.com/localsend/localsend)**(作者 **Tien Do Nam** 及贡献者)的一个分支,LocalSend 的全部功劳归属上游官方项目。采用 **MIT 许可证**,`Copyright (c) 2022-2024 Tien Do Nam`,本分支完整保留原始许可证与版权(见 [`LICENSE`](./LICENSE))。

> **非官方社区构建。** 与官方 LocalSend 项目无隶属关系,也未获其认可。按"原样"提供,不附带任何担保。
