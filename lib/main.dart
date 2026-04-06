import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const IdeaScoutApp());
}

class IdeaScoutApp extends StatelessWidget {
  const IdeaScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idea Scout',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}
