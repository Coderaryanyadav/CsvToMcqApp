import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await StorageService.loadSettings();
  final activeStudent = await StorageService.getActiveStudent();
  runApp(MyApp(hasActiveStudent: activeStudent != null));
}

class MyApp extends StatelessWidget {
  final bool hasActiveStudent;

  const MyApp({super.key, this.hasActiveStudent = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuizPro - MCQ Exam Simulator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: hasActiveStudent ? const HomeScreen() : const WelcomeScreen(),
    );
  }
}

