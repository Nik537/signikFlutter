import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'ui/windows_home.dart';
import 'ui/android_home.dart';

void main() {
  runApp(const SignikApp());
}

class SignikApp extends StatelessWidget {
  const SignikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signik',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Platform.isWindows ? const WindowsHome() : const AndroidHome(),
    );
  }
}
