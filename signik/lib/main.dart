import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'services/connection_manager.dart';
import 'services/app_config.dart';
import 'ui/windows/home.dart';
import 'ui/android/home.dart';
import 'core/theme/app_theme.dart';
import 'core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load saved settings for Android
  if (Platform.isAndroid) {
    await AppConfig.loadFromPreferences();
  }
  
  runApp(const SignikApp());
}

class SignikApp extends StatelessWidget {
  const SignikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConnectionManager(),
      child: MaterialApp(
        title: 'Signik',
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: Platform.isWindows ? const WindowsHome() : const AndroidHome(),
      ),
    );
  }
}
