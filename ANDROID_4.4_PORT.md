# LocalSend-Android4.4 — 移植技术文档（ANDROID_4.4_PORT.md）

> 让 LocalSend 重新跑在 **Android 4.4 KitKat（API 19）** 及以上的老设备上。
>
> 本仓库是 [localsend/localsend](https://github.com/localsend/localsend)（作者 Tien Do Nam，MIT 协议）的一个**非官方社区分支（unofficial community fork）**，**与官方项目没有任何隶属关系**。我们完整保留上游的版权与 MIT 协议，并向上游项目致谢。

---

## 目录

- [1. 这是什么](#1-这是什么)
- [2. 版本与构建概览](#2-版本与构建概览)
- [3. 为什么是 v1.15.1：版本天花板与 AOT 崩溃](#3-为什么是-v1151版本天花板与-aot-崩溃)
- [4. Android 兼容性改动](#4-android-兼容性改动)
- [5. 回移植（back-port）的 6 个修复](#5-回移植back-port的-6-个修复)
- [6. 新特性：自定义主题色](#6-新特性自定义主题色)
- [7. 已知限制（KitKat 上不能整文件夹发送）](#7-已知限制kitkat-上不能整文件夹发送)
- [8. 兼容性与验证](#8-兼容性与验证)
- [9. 从源码构建](#9-从源码构建)
- [10. 移植与排错指南](#10-移植与排错指南)
- [11. 许可证与致谢](#11-许可证与致谢)

---

## 1. 这是什么

**LocalSend** 是一个开源、跨平台的 **AirDrop 替代品**：在**同一个局域网**内的设备之间互传文件、照片和文字，全程走**加密的 TLS HTTP 连接**，**不需要互联网、不需要账号**。设备发现使用 **UDP 多播（multicast）** 完成。

官方 LocalSend 较新的版本已经不再支持老旧的 Android。本分支 **LocalSend-Android4.4** 的目标，就是让它在 **Android 4.4.4 KitKat（API 19）这种古董机** 上也能正常启动、渲染界面、发现设备并完成传输，同时向上兼容到现代 Android。

> 一句话总结：**官方版功能 + 让老 Android 能跑** = 本分支。

---

## 2. 版本与构建概览

| 项目 | 取值 |
| --- | --- |
| App 内显示 / APK 版本名 | `1.15.1.6fix` |
| 上游基线版本 | LocalSend **v1.15.1**（能在 Android 4.4 上跑的最高上游版本） |
| `versionCode`（build-number） | `50` |
| ABI | **armeabi-v7a**（32 位 ARM） |
| `minSdkVersion` | **19**（Android 4.4 KitKat） |
| `targetSdkVersion` | **34** |
| 运行范围 | Android 4.4 → 现代 Android |
| APK 文件名 | `LocalSend-1.15.1.6fix-android4.4-armeabi-v7a.apk` |
| APK 体积 | 约 **13.9 MB**（已签名） |

### 工具链（构建本分支所需）

| 组件 | 版本 |
| --- | --- |
| Flutter | **3.13.9**（已在 `.fvmrc` 中锁定） |
| Dart | 3.1.x |
| JDK | 17 |
| Android SDK | platform-34 + build-tools 34.0.0 |
| Android Gradle Plugin (AGP) | 7.2.0 |
| Gradle | 7.5 |

### 构建命令

```bash
flutter build apk --release \
  --target-platform android-arm \
  --build-name=1.15.1.6fix \
  --build-number=50
```

> `--target-platform android-arm` 即只产出 **armeabi-v7a** 的 32 位 ARM APK——这正是老 KitKat 设备所需要的 ABI。

---

## 3. 为什么是 v1.15.1：版本天花板与 AOT 崩溃

很多人会问：为什么不基于最新版？答案是——**更新的版本在 Android 4.4 上根本跑不起来**。我们在真机上逐版本（bisect）验证后，确定 **v1.15.1 是确定无疑的工作天花板**。

### 3.1 v1.16.0+ —— 从架构上不可能

`v1.16.0` 及以后的版本，在 Android 4.4 上**根本无法构建/运行**，原因有三，任何一条都是死结：

- **引入了 Rust HTTP 客户端 `rhttp`**：现代 Rust / NDK 工具链要求 **API 21+**，无法面向 API 19 编译。
- **要求 Dart >= 3.5**，也就是 **Flutter >= 3.24**。
- **Flutter 3.22+ 彻底移除了对 Android KitKat（API 19/20）的支持**——其引擎本身就需要 API 21。

### 3.2 v1.15.2 / v1.15.3 / v1.15.4 —— 在 4.4 上启动即崩

这三个版本在 Android 4.4 上会在**启动的第一帧崩溃**，根因是一个 **Dart AOT 编译器的 bug**：

- `v1.15.2` 把网络发现逻辑**移进了一个后台 Dart isolate**（refena isolate 框架，对应 PR **「Discover in different thread #1555」**）。
- 这一大段新增的 Dart 代码，在面向 **armeabi-v7a** 做 **AOT 编译**时，会触发 Dart AOT 编译器的一个 bug，导致在 `libflutter.so` 中发生 **native SIGSEGV**（一次带有错误长度参数的 `memcpy`），**在第一帧就崩溃**。
- 我们在真机上对四个版本做了对照 bisect 验证：**v1.15.1 能跑，v1.15.2 / v1.15.3 / v1.15.4 全部崩溃**。
- 顺带说明：换成 **debug / JIT 构建**可以绕过这个 AOT bug，但又会撞上 **KitKat 的 dexopt 体积上限**，所以同样不可用。

### 3.3 结论

因此，**v1.15.1 是确定无疑的工作天花板**。而且它本身已经包含了上游的两项重要修复：

- **「>2 GB 大文件传输崩溃」修复**；
- **「Android TV 文件/文件夹选择器崩溃」修复**。

> 换句话说：在「能跑在 4.4 上」的前提下，v1.15.1 已经是功能最完整、最稳的那一版。1.16.0+/2.x 里更新的东西，无法被干净地回移植到 v1.15.1（详见[第 5 节](#5-回移植back-port的-6-个修复)结尾说明）。

---

## 4. Android 兼容性改动

下面是相对**原版 v1.15.1** 为了适配老 Android 所做的改动。

| 改动 | 说明 |
| --- | --- |
| `minSdkVersion` 21 → **19** | 让应用可以安装到 Android 4.4。 |
| **启用 multidex** | `multiDexEnabled true` + `androidx.multidex:2.0.1` + 一个继承 `MultiDexApplication` 的 `MainApplication`。原因：在 API 21 以下，约 **50 个插件**会超过单 dex 的 **64K 方法数上限**。 |
| `AndroidManifest` 设置 `application` 的 `android:name` | 指向 `.MainApplication`，使上面的 multidex 应用类生效。 |
| `MainActivity`：SAF「选文件夹」代码路径加守卫 | `ACTION_OPEN_DOCUMENT_TREE` 以及 tree `DocumentsContract` 相关 API 都是 **API 21+**；在 KitKat 上让它们**优雅失败**（报错）而不是崩溃。 |
| 加入阿里云 Maven 镜像 | 用户所在的中国网络下 Maven Central / Google 被屏蔽或限速。**注意：仅在该网络环境下需要。** |
| `gradle.properties`：关闭 Gradle daemon + 关闭并行 | 为了在低内存机器上更稳地构建。 |
| 插件审计 | 已审计全部插件：v1.15.1 里**每一个** Android 插件都支持 `minSdk <= 19`，因此**无需任何插件覆盖（override）**。 |

> 这些改动都集中在 Android 工程层（Gradle / Manifest / `MainActivity` / `MainApplication`），不触碰跨平台的 Dart 业务逻辑。

---

## 5. 回移植（back-port）的 6 个修复

版本号里的 **`6fix`** 指的就是：我们在 v1.15.1 之上、挑选了 **6 个体积小、且不依赖 isolate 框架** 的提交进行 cherry-pick。

| # | 修复 | 来源 | 作用 |
| --- | --- | --- | --- |
| 1 | **接收大文件不再 OOM** | 上游 PR **#1547** | 接收时**每 10 MB 周期性刷盘**，不再把整个文件缓冲在内存里。对低内存设备至关重要。 |
| 2 | **发送大文件不再 OOM** | 上游 PR **#1661** | 用一个受管的 `StreamController` 来**流式**读取文件，替换掉会把整文件缓冲住的 `.asBroadcastStream()`。 |
| 3 | **任意绝对 URI 都可点击** | 上游 PR **#1662** | 收到的 `file://`、`obsidian://` 等链接变成**可点击**，不再只识别 `http(s)`。 |
| 4 | **网络「扫描（Scan）」按钮的 Tooltip** | 取自 **v1.15.4** | 给扫描按钮补上提示文字。 |
| 5 | **路径穿越安全修复（SECURITY）** | 从 **v1.17.0** 回移植 | 恶意发送方可用文件名里的 `../` 把文件写到**下载目录之外**；现在通过 `p.isWithin` 检查予以拒绝。 |
| 6 | **历史对话里收到的文字消息重复显示三次** | 上游 PR **#2296** | 修复一条收到的文本在历史对话框中被显示三遍的 bug。 |

### 为什么只回移植这 6 个？

`1.16.0+` / `2.x` 里**其它**的改进**无法被干净地回移植**到 v1.15.1，因为它们都构建在 **1.16 之后已经分叉的代码库**之上，依赖了这些底层变更：Rust / `rhttp`、Flutter 3.24、用 `HttpServer` 取代 `shelf`、refena isolate 框架，以及一系列大规模重构。强行回移植只会把那条死结（[第 3 节](#3-为什么是-v1151版本天花板与-aot-崩溃)）重新引入。

---

## 6. 新特性：自定义主题色

这是**本分支新增、上游 v1.15.1 没有**的功能。

**背景**：Android **12 以下读不到系统强调色**（Material You / 动态取色需要 Android 12+）。所以在 KitKat 上，原版主题只能**固定为青色（teal）**，无法跟随系统。

**做法**：我们加了一个**手动取色器**——

- **设置 → 颜色（Settings → Color）** 下新增一排 **12 个预设色块**：
  青色（teal，默认）、蓝、靛蓝、深紫、粉、红、深橙、琥珀、绿、青色（cyan）、棕、蓝灰。
- **点一下立刻重新换肤**（浅色 / 深色主题都变）。
- 所选颜色被用作 **Material 3 的 seed color**（种子色），并持久化保存在 **SharedPreferences**。

**实现要点**：用一个**独立的 provider** 来实现，**没有改动 `dart_mappable` 模型**，因此**不需要代码生成**（codegen）。

---

## 7. 已知限制（KitKat 上不能整文件夹发送）

> **在 Android 4.4 上，「发送整个文件夹」不可用。**

原因：整文件夹发送依赖 **Storage Access Framework 的目录树选择器**，而它是 **API 21+** 才有的能力。该路径已被守卫（参见[第 4 节](#4-android-兼容性改动)），所以它会**优雅降级——弹出一个错误提示，而不是崩溃**。

**在 KitKat 上仍然正常工作的：**

- 发送**单个文件 / 媒体 / 文字**；
- **全部接收功能**（接收文件、媒体、文字都正常）。

| 操作 | Android 4.4 | 现代 Android |
| --- | --- | --- |
| 发送单个文件 / 媒体 / 文字 | ✅ | ✅ |
| 发送整个文件夹 | ⚠️ 不支持（优雅报错） | ✅ |
| 接收（文件 / 媒体 / 文字） | ✅ | ✅ |
| 设备发现 / 传输 | ✅ | ✅ |

---

## 8. 兼容性与验证

**参考目标设备**：**小米红米 Note**（“小米红米Note”，骁龙 410 / 移动 4G 强悍版 / 2GB RAM 版本；ZOL 型号 id 397514）。

| 规格 | 取值 |
| --- | --- |
| SoC | 高通骁龙 410（Qualcomm Snapdragon 410，MSM8916） |
| 架构 | **armeabi-v7a（32 位）** |
| 内存 | 2 GB RAM |
| 出厂系统 | **Android 4.4.4 KitKat**（MIUI 6） |
| 年份 | 2015 |

构建已在 **Android 4.4.4 KitKat / armeabi-v7a 真机**上验证：**可以启动、不崩溃、界面正常渲染，设备发现与文件传输均可正常工作。**

> 说明：本文档只在这个层面陈述兼容性 / 验证情况，**不提供逐设备的详细测试日志**。

---

## 9. 从源码构建

### 9.1 前置条件

按[第 2 节](#2-版本与构建概览)的工具链准备环境：

- **Flutter 3.13.9**（仓库 `.fvmrc` 已锁定；推荐用 [fvm](https://fvm.app) 管理版本，然后用 `fvm flutter` 代替 `flutter`）
- **Dart 3.1.x**（随 Flutter 3.13.9 附带）
- **JDK 17**
- **Android SDK**：platform-34 + build-tools 34.0.0
- 工程已配置 **AGP 7.2.0 / Gradle 7.5**

### 9.2 步骤

```bash
# 1. 克隆本分支仓库
git clone https://github.com/<your-account>/LocalSend-Android4.4.git
cd LocalSend-Android4.4

# 2. 进入 app 目录
cd app

# 3. 拉取依赖
flutter pub get      # 或 fvm flutter pub get

# 4. 构建面向 armeabi-v7a 的 release APK
flutter build apk --release \
  --target-platform android-arm \
  --build-name=1.15.1.6fix \
  --build-number=50
```

产物即 `LocalSend-1.15.1.6fix-android4.4-armeabi-v7a.apk`（约 13.9 MB，已签名）。

### 9.3 中国网络下的额外说明

如果你在中国大陆网络下构建、且遇到 Maven Central / Google 被屏蔽或限速，本工程已经加入了**阿里云 Maven 镜像**；其它网络环境下不需要它。低内存机器上，工程的 `gradle.properties` 已**关闭 Gradle daemon 与并行构建**以提升可靠性。

### 9.4 安装（侧载 sideload）

本分支通过 **GitHub Releases** 以**预编译 APK** 的形式分发。在目标机上安装：

1. 到本仓库的 **GitHub Releases** 页面下载 `LocalSend-1.15.1.6fix-android4.4-armeabi-v7a.apk`（armeabi-v7a 版本）。
2. 在设备上**开启「未知来源 / 允许安装未知应用」**。
3. **侧载（sideload）**该 APK 完成安装。

---

## 10. 移植与排错指南

如果你想把类似思路套到自己的老 Android 移植上，下面是本分支踩过的坑与对应做法。

### 10.1 先定「版本天花板」，别盲目追新

把候选版本在**真机上逐一 bisect**，找出最后一个能跑的版本。对 LocalSend 来说，红线是：

- **Rust / `rhttp` 依赖** → 要求 NDK API 21+，KitKat 出局；
- **Dart >= 3.5 / Flutter >= 3.24** → Flutter 3.22+ 已删除 KitKat 引擎支持；
- **后台 isolate 里的大段新 Dart 代码** → 触发 armeabi-v7a 的 **Dart AOT 编译器 bug**，启动即 `SIGSEGV`。

### 10.2 启动即崩（SIGSEGV in `libflutter.so`）

- **现象**：release 包在 KitKat 第一帧崩溃，native 栈停在 `libflutter.so` 的 `memcpy`（长度参数被破坏）。
- **根因**：Dart AOT 编译器在面向 armeabi-v7a 编译某些新增代码（如 isolate 框架）时的 bug。
- **对策**：**不要**升级到引入该代码的版本；停在干净的版本（这里是 v1.15.1）。注意 debug / JIT 构建虽能绕过 AOT bug，但会撞上 **KitKat dexopt 体积上限**，不可用。

### 10.3 安装/运行报方法数或 dex 相关错误

- **原因**：API 21 以下单 dex 有 **64K 方法数上限**，约 50 个插件会超限。
- **对策**：开启 **multidex**——`multiDexEnabled true` + `androidx.multidex:2.0.1` + 让 `Application` 继承 `MultiDexApplication`，并在 `AndroidManifest` 里把 `application` 的 `android:name` 指向它。

### 10.4 选文件夹一点就崩

- **原因**：`ACTION_OPEN_DOCUMENT_TREE` 与 tree `DocumentsContract` API 是 **API 21+**。
- **对策**：在 `MainActivity` 中给这些路径加**版本守卫**，让它在 KitKat 上**优雅报错**而非崩溃（参见[第 7 节](#7-已知限制kitkat-上不能整文件夹发送)）。

### 10.5 主题色固定、无法跟随系统

- **原因**：动态取色（Material You）需要 **Android 12+**。
- **对策**：提供**手动取色器**——一排预设色块，所选色作为 **Material 3 seed color**，存入 **SharedPreferences**。若用独立 provider 实现、不动 `dart_mappable` 模型，即可**免代码生成**。

### 10.6 国内网络构建拉不到依赖

- **对策**：在 Gradle 里加**阿里云 Maven 镜像**；低内存机器上**关闭 daemon 与并行构建**以提升稳定性。

---

## 11. 许可证与致谢

本分支以 **MIT License** 发布，并**完整保留**上游的版权声明：

```
MIT License
Copyright (c) 2022-2024 Tien Do Nam
```

- **上游项目**：[localsend/localsend](https://github.com/localsend/localsend)，作者 **Tien Do Nam**。本分支的全部核心功能均来自该项目，特此致谢。
- **本分支性质**：**非官方社区构建（unofficial community build）**，与官方 LocalSend 项目**没有任何隶属关系**。请勿就本分支的问题向上游官方寻求支持。
- 保持诚实：这只是一个让 LocalSend 能在 Android 4.4+ 老设备上跑起来的社区分支。

---

> 项目名：**LocalSend-Android4.4** ·  公开仓库 · 通过 GitHub Releases 分发预编译 APK
