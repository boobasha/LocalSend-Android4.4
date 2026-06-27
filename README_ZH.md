# LocalSend for Android 4.4（安卓 4.4 版）

> 一个非官方的社区分支，基于 [**LocalSend**](https://github.com/localsend/localsend)，可运行在**老旧安卓**设备上 —— 从 **Android 4.4 KitKat（API 19）** 一直到最新的 Android。

本项目是 [localsend/localsend](https://github.com/localsend/localsend)（MIT 许可证，作者 Tien Do Nam）的社区分支。它的存在只有一个目的：让 LocalSend 重新回到官方应用已经无法支持的设备上。**本分支与官方 LocalSend 项目没有任何隶属关系，也未获其认可。**

---

## LocalSend 是什么？

LocalSend 是一个开源、跨平台的 AirDrop 替代方案。它让你在**同一局域网**内的设备之间发送**文件、照片和文本** —— 无需联网、无需账号、无需云端。

- 传输通过**加密（TLS）的 HTTP 连接**进行。
- 设备之间通过 **UDP 组播（multicast）自动发现**彼此。
- 数据不会离开你的局域网。

本分支保留了以上全部能力，并让它能运行在 Android 4.4 及以上的设备上。

---

## 下载与安装

应用以**预编译、已签名的 APK** 形式，通过 **GitHub Releases** 分发。

1. 打开本仓库的 **[Releases](../../releases)** 页面。
2. 下载最新的 APK：

   ```
   LocalSend-1.15.1.6fix-android4.4-armeabi-v7a.apk   （约 13.9 MB）
   ```

3. 将其拷贝到设备上并点击安装。你可能需要在**设置**中开启**“允许安装未知来源应用”**，才能侧载（sideload）来自应用商店之外的 APK。

| 项目 | 数值 |
|------|------|
| 应用版本 | **1.15.1.6fix** |
| 基于 | LocalSend **v1.15.1** |
| ABI | **armeabi-v7a**（32 位 ARM） |
| minSdk | **19**（Android 4.4 KitKat） |
| targetSdk | **34** |
| 运行范围 | Android **4.4 → 最新 Android** |

> 该 APK 面向 **32 位 ARM（armeabi-v7a）** 设备，正好覆盖本分支所针对的老旧硬件。

---

## 功能特性

包含官方 LocalSend v1.15.1 的全部功能，并新增以下内容：

- 📁 在同一网络的设备间**发送文件、照片和文本**。
- 🔒 **加密（TLS）** 传输 —— 无需联网、无需账号。
- 📡 通过 UDP 组播**自动发现设备**。
- 🌍 **跨平台** —— 可与 Windows、macOS、Linux、iOS、Android 上的 LocalSend 互通。
- 🎨 **新增：自定义主题颜色**（见下文）。

### 自定义主题颜色（本分支新增）

**Android 12 以下**的系统无法读取系统强调色（Material You / 动态取色需要 Android 12 及以上），因此在 KitKat 上，应用主题一直被固定为青色（teal）。

本分支新增了一个**手动颜色选择器**：

- 进入 **设置 → 颜色（Color）**，会看到一行 **12 个预设色块**：青色（默认）、蓝色、靛蓝、深紫、粉色、红色、深橙、琥珀、绿色、青蓝（cyan）、棕色、蓝灰。
- 点击其中任意一个，整个应用会**立即重新着色**（浅色与深色主题均生效）。
- 所选颜色会作为 **Material 3 的种子色（seed color）**，并被**持久化保存**（存于 `SharedPreferences`）。

该功能通过一个独立的 provider 实现 —— 未改动 `dart_mappable` 模型，因此无需代码生成。

---

## 为什么是 v1.15.1？（版本天花板）

v1.15.1 是**官方版本中能真正在 Android 4.4 上运行的最高版本**。更新的版本无法工作，原因如下：

**v1.16.0 及更高版本在 4.4 上根本无法实现：**
- 它们引入了 **Rust HTTP 客户端**（`rhttp`），而现代 Rust/NDK 需要 **API 21 及以上**。
- 它们要求 **Dart ≥ 3.5**（即 **Flutter ≥ 3.24**），而 **Flutter 3.22+ 已经完全移除了对 Android KitKat（API 19/20）的支持** —— 引擎本身需要 API 21。

**v1.15.2 / v1.15.3 / v1.15.4 在 4.4 上会崩溃：**
- v1.15.2 将网络发现移到了一个**后台 Dart isolate** 中（refena isolate 框架，PR *“Discover in different thread #1555”*）。
- 这一大段新增的 Dart 代码在**为 armeabi-v7a 进行 AOT 编译**后，会触发一个 **Dart AOT 编译器 bug**：在第一帧就发生原生 **SIGSEGV**（位于 `libflutter.so` 中，一次长度被破坏的 `memcpy`）—— 应用一启动就崩溃。
- 这是通过在**真实硬件上对四个版本逐一二分（bisect）验证**确认的：v1.15.1 可运行；v1.15.2 / 3 / 4 全部崩溃。（debug/JIT 构建能绕过该 AOT bug，但又会撞上 KitKat 的 **dexopt 体积上限**，因此同样不可用。）

所以 **v1.15.1 是确定的、可用的天花板。** 它已经包含了官方对 **“大于 2 GB 文件传输崩溃”** 以及 **Android TV 文件/文件夹选择器崩溃** 的修复。

1.16.0+/2.x 中更新的内容**无法干净地回移植（back-port）**，因为它们都建立在 1.16 之后已经分叉的代码库之上（Rust/`rhttp`、Flutter 3.24、用 `HttpServer` 取代 `shelf`、isolate 框架以及大量重构）。

---

## 在 KitKat 上哪些功能可用

| 能力 | Android 4.4 |
|------|:-----------:|
| 接收文件 / 照片 / 文本 | ✅ |
| 发送单个文件 | ✅ |
| 发送媒体（照片/视频） | ✅ |
| 发送文本 | ✅ |
| 设备发现 + 传输 | ✅ |
| **发送整个文件夹** | ❌（见下文） |

### 已知限制：发送整个文件夹

在 Android 4.4 上，**发送整个文件夹**功能**不可用**，因为**存储访问框架（SAF）**的目录树选择器（`ACTION_OPEN_DOCUMENT_TREE`）属于 **API 21+**。该路径已被**保护处理**，因此会**优雅降级**（弹出错误提示）而不是崩溃。其余功能 —— 发送单个文件/媒体/文本，以及**全部接收功能** —— 均正常工作。

---

## 已回移植的修复（“6fix”）

在 v1.15.1 之上挑选（cherry-pick）了 6 个与 isolate 无关的小修复（因此版本号为 **1.15.1.6fix**）：

1. **接收大文件不再 OOM**（官方 PR #1547）—— 周期性地将已接收数据刷写到磁盘（每 10 MB 一次），而不是把整个文件缓存在内存里。对低内存设备至关重要。
2. **发送大文件不再 OOM**（官方 PR #1661）—— 通过受管理的 `StreamController` 来流式发送文件，取代会缓存整个文件的 `.asBroadcastStream()`。
3. **将任意绝对 URI 视为可点击链接**（官方 PR #1662）—— 接收到的 `file://`、`obsidian://` 等也变得可点击，而不仅限于 `http(s)`。
4. **网络“扫描（Scan）”按钮的提示气泡（Tooltip）**（来自 v1.15.4）。
5. **路径穿越安全修复**（从 v1.17.0 回移植）—— 恶意发送方可能在文件名中使用 `../` 把文件写到下载文件夹**之外**；现在会通过 `p.isWithin` 检查予以拒绝。
6. **文本消息重复显示修复**（官方 PR #2296）—— 接收到的一条文本消息曾在历史记录对话框中被显示三次。

---

## 安卓兼容性改动（相对于原版 v1.15.1）

- 将 **`minSdkVersion` 由 21 降到 19**。
- **启用 multidex**（`multiDexEnabled true` + `androidx.multidex:2.0.1` + 一个继承自 `MultiDexApplication` 的 `MainApplication`），因为在 API 21 以下，约 50 个插件会超出 **64K 方法的单 dex 上限**。
- 将清单文件中的 `application android:name` 设为 **`.MainApplication`**。
- **`MainActivity`：** 对 SAF “选择文件夹”相关代码路径做了保护（`ACTION_OPEN_DOCUMENT_TREE` 及目录 `DocumentsContract` API 均为 API 21+），使其在 KitKat 上**优雅失败**而非崩溃。
- 为 Gradle 添加了**阿里云 Maven 镜像**（在用户所在的中国网络环境下，Maven Central / Google 被屏蔽或限速）。*仅在该网络环境下需要。*
- **`gradle.properties`：** 关闭 Gradle 守护进程（daemon）与并行构建，以提升低内存环境下的构建可靠性。
- **插件审计：** v1.15.1 中的每一个 Android 插件都支持 `minSdk ≤ 19`，因此**无需对任何插件做覆盖处理**。

---

## 参考 / 测试设备

本构建已验证可在 **Android 4.4.4 KitKat / armeabi-v7a 硬件**上**启动并运行** —— 应用启动不崩溃、UI 正常渲染、设备发现与传输均可工作。

| | |
|---|---|
| 设备 | **小米红米 Note**（Snapdragon 410 / 移动 4G 强悍版 / 2GB 内存版本） |
| SoC | 高通 **骁龙 410（MSM8916）**，armeabi-v7a（32 位） |
| 内存 | 2 GB |
| 系统 | Android **4.4.4** KitKat（MIUI 6），2015 年出厂 |

---

## 从源码构建

### 工具链

| 工具 | 版本 |
|------|------|
| Flutter | **3.13.9**（固定于 `.fvmrc`） |
| Dart | **3.1.x** |
| JDK | **17** |
| Android SDK | **platform-34** + **build-tools 34.0.0** |
| Android Gradle 插件 | **7.2.0** |
| Gradle | **7.5** |

### 构建命令

```bash
flutter build apk --release \
  --target-platform android-arm \
  --build-name=1.15.1.6fix \
  --build-number=50
```

该命令会产出已签名的 `armeabi-v7a` 发布版 APK。

---

## 致谢与许可证

本项目是 **[LocalSend](https://github.com/localsend/localsend)** 官方项目（作者 **Tien Do Nam** 及贡献者们）的一个分支。LocalSend 的全部功劳归属于上游官方项目。

采用 **MIT 许可证** —— `Copyright (c) 2022-2024 Tien Do Nam`。本分支完整保留原始许可证与版权声明。详见 [`LICENSE`](./LICENSE)。

> **非官方社区构建。** 与官方 LocalSend 项目没有隶属关系，也未获其认可。按“原样（as is）”提供，不附带任何担保。

🌐 For the English version, see **[README.md](./README.md)**.
