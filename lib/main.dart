// =========================
// lib/main.dart
// =========================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DORKWalletApp());
}

class DORKWalletApp extends StatelessWidget {
  const DORKWalletApp({super.key});

  Widget build(BuildContext context) {
    const dorkBg = Color(0xFF1A1A1A); // Dark background
    const dorkSurface = Color(0xFF242424);
    const dorkAccent = Color(0xFFFFD700); // Gold/Yellow accent
    const dorkAccentDark = Color(0xFFCCAC00);
    const dorkTextMain = Color(0xFFFFFFFF);
    const dorkTextMuted = Color(0xFFAAAAAA);
    const dorkDanger = Color(0xFFFF4444);

    final colorScheme = ColorScheme.dark(
      primary: dorkAccent,
      secondary: dorkAccentDark,
      surface: dorkSurface,
      error: dorkDanger,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
      onSurface: dorkTextMain,
      onError: Colors.white,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        title: 'Dorkcoin Wallet',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: dorkBg,
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: dorkTextMain),
            bodyMedium: TextStyle(color: dorkTextMain),
            bodySmall: TextStyle(color: dorkTextMuted),
            titleLarge: TextStyle(
              color: dorkTextMain,
              fontWeight: FontWeight.w700,
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: dorkBg,
            foregroundColor: dorkAccent,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: dorkAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: dorkAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        builder: (context, child) {
          return child!;
        },
        home: const HomeScreen(),
      ),
    );
  }
}