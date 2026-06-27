# Changelog

All notable changes to **LocalSend-Android4.4** (an unofficial community fork) are documented here.

This fork is based on upstream [LocalSend](https://github.com/localsend/localsend) **v1.15.1** by Tien Do Nam (MIT License). It is **not affiliated** with the official LocalSend project. The goal of this fork is to make LocalSend run on **old Android — specifically Android 4.4 KitKat (API 19) and up**.

## [1.15.1.6fix] - 2026-06-28

Based on upstream LocalSend **v1.15.1**, the highest upstream version that runs on Android 4.4. App version name: `1.15.1.6fix`.

### Why v1.15.1 (version ceiling)

v1.15.1 is the definitive working ceiling for Android 4.4. Newer upstream releases cannot run on KitKat:

- **v1.16.0 and newer are impossible on 4.4.** They added a Rust HTTP client (`rhttp`) — modern Rust/NDK requires API 21 — and require Dart >= 3.5 (i.e. Flutter >= 3.24). Flutter 3.22+ dropped Android KitKat (API 19/20) support entirely, because the engine needs API 21.
- **v1.15.2 / v1.15.3 / v1.15.4 crash on 4.4.** v1.15.2 moved network discovery into a background Dart isolate (the refena isolate framework, PR "Discover in different thread #1555"). That large body of new Dart code, when AOT-compiled for armeabi-v7a, triggers a Dart AOT compiler bug that causes a native `SIGSEGV` (in `libflutter.so`, a `memcpy` with a corrupt length) at the first frame — the app crashes on launch. A debug/JIT build avoids the AOT bug but then hits KitKat's dexopt size limit, so it isn't usable either.

This was confirmed by bisecting all four versions on real hardware: v1.15.1 runs; v1.15.2/3/4 all crash. v1.15.1 already includes upstream fixes for the ">2 GB file transfer crash" and the "Android TV file/folder picker crash".

### Added

- **Custom theme color.** Android < 12 cannot read the system accent color (Material You / dynamic color needs Android 12+), so on KitKat the theme was always a fixed teal. This fork adds a manual color picker: **Settings -> Color** now has a row of 12 preset color swatches (teal = default, blue, indigo, deep purple, pink, red, deep orange, amber, green, cyan, brown, blue grey). Tapping one instantly re-themes the app (light and dark). The chosen color is used as the Material 3 seed color and is persisted in SharedPreferences. Implemented with a standalone provider (no changes to the dart_mappable model, so no code generation needed).

### Back-ported fixes

Six small, isolate-independent cherry-picks onto v1.15.1 (hence the "6fix" suffix):

1. **Receive large files without OOM** (upstream PR #1547): periodically flush received data to disk (every 10 MB) instead of buffering the whole file in RAM. Critical for low-RAM devices.
2. **Send large files without OOM** (upstream PR #1661): stream the file via a managed `StreamController` instead of `.asBroadcastStream()` (which buffered the whole file).
3. **Treat any absolute URI as a clickable link** (upstream PR #1662): received `file://`, `obsidian://`, etc. become tappable, not just `http(s)`.
4. **Tooltip on the network "Scan" button** (from v1.15.4).
5. **Path-traversal security fix** (back-ported from v1.17.0): a malicious sender could use `../` in a file name to write files **outside** the download folder; now rejected with a `p.isWithin` check.
6. **Fixed text shown three times** (upstream PR #2296): a received text message was displayed three times in the history dialog.

Everything else from 1.16.0+ / 2.x cannot be cleanly back-ported because it is built on the diverged post-1.16 codebase (Rust/rhttp, Flutter 3.24, HttpServer instead of shelf, the isolate framework, and large refactors).

### Android compatibility changes (vs stock v1.15.1)

- Lowered `minSdkVersion` from 21 to **19**.
- Enabled **multidex** (`multiDexEnabled true` + `androidx.multidex:2.0.1` + a `MainApplication` that extends `MultiDexApplication`), because below API 21 the ~50 plugins exceed the 64K-method single-dex limit.
- Set the AndroidManifest `application` `android:name` to `.MainApplication`.
- Guarded the SAF "pick a folder" code paths in `MainActivity` (`ACTION_OPEN_DOCUMENT_TREE` and tree `DocumentsContract` APIs are API 21+) so they fail gracefully on KitKat instead of crashing.
- Added Aliyun maven mirrors to Gradle (Maven Central / Google are blocked/throttled on the user's China network) — only needed on that network.
- `gradle.properties`: disabled the Gradle daemon and parallelism for low-RAM build reliability.
- Audited all plugins: every Android plugin in v1.15.1 supports minSdk <= 19, so no plugin overrides were needed.

### Known limitation

- **Sending an entire folder does not work on Android 4.4.** The Storage Access Framework directory-tree picker is API 21+. It is guarded so it degrades gracefully (shows an error) instead of crashing. Sending individual files / media / text, and all receiving, work normally.

### Build

- **ABI:** armeabi-v7a (32-bit ARM). **minSdk** 19 (Android 4.4), **targetSdk** 34. Runs on Android 4.4 through modern Android.
- **APK:** `LocalSend-1.15.1.6fix-android4.4-armeabi-v7a.apk` (~13.9 MB, signed).
- **Toolchain:** Flutter 3.13.9 (pinned in `.fvmrc`), Dart 3.1.x, JDK 17, Android SDK platform-34 + build-tools 34.0.0, AGP 7.2.0, Gradle 7.5.
- **Build command:**
  ```
  flutter build apk --release --target-platform android-arm --build-name=1.15.1.6fix --build-number=50
  ```

### Verified on

- Reference target device: Xiaomi Redmi Note (Snapdragon 410 / 2 GB RAM variant), Qualcomm Snapdragon 410 (MSM8916), armeabi-v7a, shipped Android 4.4.4 KitKat (MIUI 6), 2015. The build is verified to launch and run on Android 4.4.4 KitKat / armeabi-v7a hardware: no crash, UI renders, and discovery + transfer work.

### License

MIT License, Copyright 2022-2024 Tien Do Nam. This fork keeps the upstream license and copyright intact and credits the upstream project.
