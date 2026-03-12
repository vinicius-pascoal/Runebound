import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const RuneboundApp());
}

class RuneboundApp extends StatelessWidget {
  const RuneboundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Runebound',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF090B16),
      ),
      home: const HomeScreen(),
    );
  }
}
