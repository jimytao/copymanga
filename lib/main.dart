import 'package:flutter/material.dart';

import 'settings.dart';
import 'splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 只做本地设置读取，绝不在 runApp 前做网络测速（那是旧版启动慢的主因）
  await AppSettings.init();
  runApp(const CopyMangaApp());
}

class CopyMangaApp extends StatelessWidget {
  const CopyMangaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.darkMode,
      builder: (context, dark, child) {
        return MaterialApp(
          title: 'CopyManga',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepOrange,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: dark ? ThemeMode.dark : ThemeMode.system,
          home: const SplashPage(),
        );
      },
    );
  }
}
