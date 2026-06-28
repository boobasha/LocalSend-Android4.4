import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/init.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/provider/custom_color_provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/theme.dart';
import 'package:localsend_app/util/ui/dynamic_colors.dart';
import 'package:localsend_app/widget/watcher/life_cycle_watcher.dart';
import 'package:localsend_app/widget/watcher/shortcut_watcher.dart';
import 'package:localsend_app/widget/watcher/tray_watcher.dart';
import 'package:localsend_app/widget/watcher/window_watcher.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

Future<void> main(List<String> args) async {
  final container = await preInit(args);

  runApp(RefenaScope.withContainer(
    container: container,
    child: TranslationProvider(
      child: const LocalSendApp(),
    ),
  ));
}

class LocalSendApp extends StatelessWidget {
  const LocalSendApp();

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final (themeMode, colorMode) = ref.watch(settingsProvider
        .select((settings) => (settings.theme, settings.colorMode)));
    final dynamicColors = ref.watch(dynamicColorsProvider);
    final customColor = ref.watch(customColorProvider);
    return TrayWatcher(
      child: WindowWatcher(
        child: LifeCycleWatcher(
          onChangedState: (AppLifecycleState state) {
            if (state == AppLifecycleState.resumed) {
              ref.redux(localIpProvider).dispatch(InitLocalIpAction());
            }
          },
          child: ShortcutWatcher(
            child: MaterialApp(
              title: t.appName,
              locale: TranslationProvider.of(context).flutterLocale,
              supportedLocales: AppLocaleUtils.supportedLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                if (child == null) {
                  return const SizedBox.shrink();
                }
                final mq = MediaQuery.of(context);
                // Tablets only (large screens): scale text up so the UI isn't tiny.
                // Phones are left exactly as-is.
                if (mq.size.shortestSide < 600) {
                  return child;
                }
                return MediaQuery(
                  data: mq.copyWith(
                      textScaleFactor:
                          (mq.textScaleFactor * 1.3).clamp(1.0, 2.0)),
                  child: child,
                );
              },
              theme: getTheme(
                  colorMode, Brightness.light, dynamicColors, customColor),
              darkTheme: getTheme(
                  colorMode, Brightness.dark, dynamicColors, customColor),
              themeMode:
                  colorMode == ColorMode.oled ? ThemeMode.dark : themeMode,
              navigatorKey: Routerino.navigatorKey,
              home: RouterinoHome(
                builder: () => const HomePage(
                  initialTab: HomeTab.receive,
                  appStart: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
