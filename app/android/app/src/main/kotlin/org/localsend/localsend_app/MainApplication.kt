package org.localsend.localsend_app

import androidx.multidex.MultiDexApplication

/**
 * Custom Application required for Android 4.4 (API 19/20) support.
 *
 * Below API 21 (Lollipop) the Android runtime (Dalvik) cannot load an app whose
 * methods exceed the 64K limit of a single dex file. LocalSend with its ~50
 * plugins is well above that limit, so we must enable multidex and install the
 * secondary dex files at startup. [MultiDexApplication] does this automatically
 * in attachBaseContext().
 *
 * On API 21+ (ART) multidex is native, so MultiDex.install() is a harmless no-op
 * and this class behaves like a plain Application. Flutter's v2 embedding does not
 * require a FlutterApplication, so extending MultiDexApplication is safe.
 */
class MainApplication : MultiDexApplication()
