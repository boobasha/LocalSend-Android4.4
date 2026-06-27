# LocalSend for Android 4.4

> An unofficial community fork of [**LocalSend**](https://github.com/localsend/localsend) that runs on **old Android** — from **Android 4.4 KitKat (API 19)** all the way to modern Android.

This is a community fork of [localsend/localsend](https://github.com/localsend/localsend) (MIT License, by Tien Do Nam). It exists for one reason: to bring LocalSend back to devices the official app can no longer support. **It is not affiliated with or endorsed by the official LocalSend project.**

---

## What is LocalSend?

LocalSend is an open-source, cross-platform alternative to AirDrop. It lets you send **files, photos, and text** between devices on the **same local network** — no internet, no account, no cloud.

- Transfers go over an **encrypted (TLS) HTTP connection**.
- Devices find each other automatically using **UDP multicast discovery**.
- Nothing leaves your local network.

This fork keeps all of that and makes it work on Android 4.4+.

---

## Download & Install

The app is distributed as a **prebuilt, signed APK** via **GitHub Releases**.

1. Open the **[Releases](../../releases)** page of this repository.
2. Download the latest APK:

   ```
   LocalSend-1.15.1.6fix-android4.4-armeabi-v7a.apk   (~13.9 MB)
   ```

3. Copy it to your device and tap to install. You may need to enable **"Install from unknown sources"** (in **Settings**) to sideload an APK outside the Play Store.

| Item | Value |
|------|-------|
| App version | **1.15.1.6fix** |
| Based on | LocalSend **v1.15.1** |
| ABI | **armeabi-v7a** (32-bit ARM) |
| minSdk | **19** (Android 4.4 KitKat) |
| targetSdk | **34** |
| Runs on | Android **4.4 → modern Android** |

> This APK is for **32-bit ARM (armeabi-v7a)** devices, which covers the old hardware this fork targets.

---

## Features

Everything from upstream LocalSend v1.15.1, plus the changes below:

- 📁 **Send files, photos, and text** between devices on the same network.
- 🔒 **Encrypted (TLS)** transfers — no internet or account required.
- 📡 **Automatic device discovery** via UDP multicast.
- 🌍 **Cross-platform** — talks to LocalSend on Windows, macOS, Linux, iOS, and Android.
- 🎨 **NEW: Custom theme color** (see below).

### Custom theme color (new in this fork)

Android versions **below 12** can't read the system accent color (Material You / dynamic color needs Android 12+), so on KitKat the app was stuck with a fixed teal theme.

This fork adds a **manual color picker**:

- Go to **Settings → Color** to find a row of **12 preset color swatches**: teal (default), blue, indigo, deep purple, pink, red, deep orange, amber, green, cyan, brown, and blue grey.
- Tap one and the whole app **re-themes instantly** (light and dark).
- The chosen color is used as the **Material 3 seed color** and is **saved** (persisted in `SharedPreferences`).

It's implemented with a standalone provider — no changes to the `dart_mappable` model, so no code generation is required.

---

## Why v1.15.1? (the version ceiling)

v1.15.1 is the **highest upstream version that actually runs on Android 4.4**. Here's why nothing newer works:

**v1.16.0 and later are impossible on 4.4:**
- They added a **Rust HTTP client** (`rhttp`); modern Rust/NDK requires **API 21+**.
- They require **Dart ≥ 3.5** (i.e. **Flutter ≥ 3.24**), and **Flutter 3.22+ dropped Android KitKat (API 19/20) support entirely** — the engine itself needs API 21.

**v1.15.2 / v1.15.3 / v1.15.4 crash on 4.4:**
- v1.15.2 moved network discovery into a **background Dart isolate** (the refena isolate framework, PR *"Discover in different thread #1555"*).
- That large body of new Dart code, when **AOT-compiled for armeabi-v7a**, triggers a **Dart AOT compiler bug**: a native **SIGSEGV** in `libflutter.so` (a `memcpy` with a corrupt length) at the first frame — the app crashes on launch.
- This was confirmed by **bisecting all four versions on real hardware**: v1.15.1 runs; v1.15.2 / 3 / 4 all crash. (A debug/JIT build dodges the AOT bug but then hits KitKat's **dexopt size limit**, so it isn't usable either.)

So **v1.15.1 is the definitive working ceiling.** It already includes upstream fixes for the **">2 GB file transfer" crash** and the **Android TV file/folder picker crash**.

Anything newer from 1.16.0+/2.x **cannot be cleanly back-ported**, because it's built on the diverged post-1.16 codebase (Rust/`rhttp`, Flutter 3.24, `HttpServer` instead of `shelf`, the isolate framework, and large refactors).

---

## What works on KitKat

| Capability | Android 4.4 |
|------------|:-----------:|
| Receive files / photos / text | ✅ |
| Send individual files | ✅ |
| Send media (photos/videos) | ✅ |
| Send text | ✅ |
| Device discovery + transfer | ✅ |
| **Send an entire folder** | ❌ (see below) |

### Known limitation: sending a whole folder

Sending an **entire folder** does **not** work on Android 4.4, because the **Storage Access Framework** directory-tree picker (`ACTION_OPEN_DOCUMENT_TREE`) is **API 21+**. This path is **guarded** so it **degrades gracefully** (shows an error) instead of crashing. Everything else — sending individual files/media/text, and **all receiving** — works normally.

---

## Back-ported fixes (the "6fix")

Six small, isolate-independent fixes were cherry-picked onto v1.15.1 (hence **1.15.1.6fix**):

1. **Receive large files without OOM** (upstream PR #1547) — periodically flush received data to disk (every 10 MB) instead of buffering the whole file in RAM. Critical for low-RAM devices.
2. **Send large files without OOM** (upstream PR #1661) — stream the file via a managed `StreamController` instead of `.asBroadcastStream()` (which buffered the whole file).
3. **Treat any absolute URI as a clickable link** (upstream PR #1662) — received `file://`, `obsidian://`, etc. become tappable, not just `http(s)`.
4. **Tooltip on the network "Scan" button** (from v1.15.4).
5. **Path-traversal security fix** (back-ported from v1.17.0) — a malicious sender could use `../` in a file name to write files **outside** the download folder; now rejected with a `p.isWithin` check.
6. **Duplicate text message fix** (upstream PR #2296) — a received text message was shown three times in the history dialog.

---

## Android-compatibility changes (vs stock v1.15.1)

- Lowered **`minSdkVersion` 21 → 19**.
- **Enabled multidex** (`multiDexEnabled true` + `androidx.multidex:2.0.1` + a `MainApplication` that extends `MultiDexApplication`), because below API 21 the ~50 plugins exceed the **64K-method single-dex limit**.
- Set the manifest `application android:name` to **`.MainApplication`**.
- **`MainActivity`:** guarded the SAF "pick a folder" code paths (`ACTION_OPEN_DOCUMENT_TREE` and tree `DocumentsContract` APIs are API 21+) so they **fail gracefully on KitKat** instead of crashing.
- Added **Aliyun maven mirrors** to Gradle (Maven Central / Google are blocked or throttled on the user's China network). *Only needed on that network.*
- **`gradle.properties`:** disabled the Gradle daemon and parallelism for low-RAM build reliability.
- **Plugin audit:** every Android plugin in v1.15.1 supports `minSdk ≤ 19`, so **no plugin overrides were needed**.

---

## Reference / test device

The build is verified to **launch and run on Android 4.4.4 KitKat / armeabi-v7a hardware** — the app launches without crashing, the UI renders, and discovery + transfer work.

| | |
|---|---|
| Device | **Xiaomi Redmi Note** (小米红米Note, Snapdragon 410 / 移动4G 强悍版 / 2GB RAM variant) |
| SoC | Qualcomm **Snapdragon 410 (MSM8916)**, armeabi-v7a (32-bit) |
| RAM | 2 GB |
| OS | Android **4.4.4** KitKat (MIUI 6), shipped 2015 |

---

## Build from source

### Toolchain

| Tool | Version |
|------|---------|
| Flutter | **3.13.9** (pinned in `.fvmrc`) |
| Dart | **3.1.x** |
| JDK | **17** |
| Android SDK | **platform-34** + **build-tools 34.0.0** |
| Android Gradle Plugin | **7.2.0** |
| Gradle | **7.5** |

### Build command

```bash
flutter build apk --release \
  --target-platform android-arm \
  --build-name=1.15.1.6fix \
  --build-number=50
```

This produces the signed `armeabi-v7a` release APK.

---

## Credits & License

This project is a fork of the official **[LocalSend](https://github.com/localsend/localsend)** by **Tien Do Nam** and contributors. All credit for LocalSend goes to the upstream project.

Licensed under the **MIT License** — `Copyright (c) 2022-2024 Tien Do Nam`. This fork keeps the original license and copyright intact. See [`LICENSE`](./LICENSE).

> **Unofficial community build.** Not affiliated with or endorsed by the official LocalSend project. Provided "as is," without warranty.

🌐 简体中文说明请见 **[README_ZH.md](./README_ZH.md)**.
