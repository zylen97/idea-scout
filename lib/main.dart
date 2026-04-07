import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const IdeaScoutApp());
}

class IdeaScoutApp extends StatelessWidget {
  const IdeaScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    );

    return MaterialApp(
      title: 'Idea Scout',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B7355), // warm brown
          brightness: Brightness.light,
        ),
        textTheme: textTheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFE8E6DC),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF0EEE6),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF6B6560),
            fontWeight: FontWeight.w500,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFD8D4CA)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF0EEE6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF8B7355), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
