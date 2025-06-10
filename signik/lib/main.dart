import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'services/connection_manager.dart';
import 'ui/windows/home.dart';
import 'ui/android/home.dart';

void main() {
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: Platform.isWindows ? const WindowsHome() : const AndroidHome(),
      ),
    );
  }
}
