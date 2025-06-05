import 'package:flutter/material.dart';
import 'dart:io';
import 'ui/windows/home.dart';
import 'ui/android/home.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Platform.isWindows ? const WindowsHome() : const AndroidHome(),
    );
  }
}ean up -