import 'dart:ui';
import 'dart:async';
import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/routes/getx_router_observer.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/download_service.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/eh_setting.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/security_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/tab_bar_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';

import 'config/theme_config.dart';

void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    Log.error(details.exception, null, details.stack);
    FlutterError.presentError(details);
  };

  runZonedGuarded(() async {
    await init();
    runApp(const MyApp());
  }, (Object error, StackTrace stack) {
    Log.error(error, null, stack);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'JHenTai',
      theme: ThemeConfig.light,
      darkTheme: ThemeConfig.dark,
      themeMode: StyleSetting.themeMode.value,
      locale: window.locale,
      fallbackLocale: const Locale('en', 'US'),
      translations: LocaleText(),

      getPages: Routes.pages,
      initialRoute: SecuritySetting.enableFingerPrintLock.isTrue ? Routes.lock : Routes.start,
      navigatorObservers: [GetXRouterObserver()],
      builder: (context, child) => AppListener(child: child!),

      /// enable swipe back feature
      popGesture: true,
      onReady: onReady,
    );
  }
}

Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PathSetting.init();

  await GetStorage.init();
  StorageService.init();

  await AdvancedSetting.init();
  await SecuritySetting.init();
  await Log.init();
  UserSetting.init();
  TagTranslationService.init();
  StyleSetting.init();
  TabBarSetting.init();

  SiteSetting.init();
  FavoriteSetting.init();

  EHSetting.init();

  DownloadSetting.init();
  await EHRequest.init();

  await DownloadService.init();
}

Future<void> onReady() async {
  FavoriteSetting.refresh();
  SiteSetting.refresh();
  EHSetting.refresh();

  ReadSetting.init();
}

class AppListener extends StatefulWidget {
  final Widget child;

  const AppListener({Key? key, required this.child}) : super(key: key);

  @override
  State<AppListener> createState() => _AppListenerState();
}

class _AppListenerState extends State<AppListener> with WidgetsBindingObserver {
  AppLifecycleState state = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (StyleSetting.themeMode.value != ThemeMode.system) {
      return;
    }
    Get.changeThemeMode(
      WidgetsBinding.instance?.window.platformBrightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
    );
    super.didChangePlatformBrightness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (SecuritySetting.enableBlur.isFalse) {
      return;
    }

    /// for Android, blur is invalid when switch app to background(app is still clearly visible in switcher),
    /// so i choose to set FLAG_SECURE to do the same effect.
    if (state == AppLifecycleState.inactive) {
      if (GetPlatform.isAndroid) {
        FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        setState(() {
          this.state = state;
        });
      }
    }
    if (state == AppLifecycleState.resumed) {
      if (GetPlatform.isAndroid) {
        FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
        /// resume appbar color
        SystemChrome.setSystemUIOverlayStyle(Get.theme.appBarTheme.systemOverlayStyle!.copyWith(systemStatusBarContrastEnforced: true));
      } else {
        setState(() {
          this.state = state;
        });
      }
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    if (GetPlatform.isAndroid || state == AppLifecycleState.resumed) {
      return widget.child;
    }

    return Blur(
      blur: 100,
      child: widget.child,
    );
  }
}
