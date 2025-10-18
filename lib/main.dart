import 'package:flutter/material.dart';

import 'pages/home/page.dart';

void main() {
  runApp(const PowerTimeApp());
}

class PowerTimeApp extends StatelessWidget {
  const PowerTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PowerTime',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC107),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
