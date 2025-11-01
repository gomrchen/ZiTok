import 'package:flutter/material.dart';

import 'features/video/presentation/pages/homePage.dart';

void main() {
  runApp(const ZiTokApp());
}

class ZiTokApp extends StatelessWidget {
  const ZiTokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZiTok',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}
