import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await MobileAds.instance.initialize();
  }
  await StorageService.init();
  final settings = await StorageService.loadSettings();
  final themeModeSetting = settings['themeMode']?.toString() ?? 'system';
  AppTheme.setThemeMode(themeModeSetting);

  final activeStudent = await StorageService.getActiveStudent();
  runApp(MyApp(hasActiveStudent: activeStudent != null));
}

class MyApp extends StatelessWidget {
  final bool hasActiveStudent;

  const MyApp({super.key, this.hasActiveStudent = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'QuizPro - MCQ Exam Simulator',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: hasActiveStudent ? const HomeScreen() : const WelcomeScreen(),
        );
      },
    );
  }
}
