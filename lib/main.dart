import 'package:flutter/material.dart';

import 'package:emotion_app/core/theme/app_colors.dart';
import 'package:emotion_app/data/notifications/notification_service.dart';
import 'package:emotion_app/data/session/app_session.dart';
import 'package:emotion_app/features/auth/login_page.dart';
import 'package:emotion_app/features/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSession.instance.load();
  await NotificationService.instance.start();
  runApp(const MindBalanceApp());
}

class MindBalanceApp extends StatelessWidget {
  const MindBalanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mind Balance',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.amber,
          primary: AppColors.amber,
          secondary: AppColors.navy,
          surface: AppColors.surface,
        ),
        fontFamily: 'Roboto',
      ),
      home: AppSession.instance.isLoggedIn
          ? const AppShell()
          : const LoginPage(),
    );
  }
}
