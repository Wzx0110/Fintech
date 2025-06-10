import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/main_page.dart';
import 'services/auth_service.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthService _authService = AuthService();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color seedColor = Colors.indigo;

    final ColorScheme lightColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    final ColorScheme darkColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: '投資理財 App',
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,

      theme: ThemeData.from(
        colorScheme: lightColorScheme,
        useMaterial3: true,
      ).copyWith(
        scaffoldBackgroundColor: lightColorScheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: lightColorScheme.onPrimary,
          elevation: 2.0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: lightColorScheme.primary,
          unselectedItemColor: lightColorScheme.onSurface.withOpacity(0.6),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightColorScheme.primary,
            foregroundColor: lightColorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: lightColorScheme.outline.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: lightColorScheme.primary, width: 2.0),
            borderRadius: BorderRadius.circular(12.0),
          ),
          filled: true,
          fillColor: lightColorScheme.surfaceVariant.withOpacity(0.5),
        ),
        cardTheme: CardTheme(
          elevation: 1.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          color: Colors.white,
        ),
      ),

      darkTheme: ThemeData.from(
        colorScheme: darkColorScheme,
        useMaterial3: true,
      ).copyWith(
        scaffoldBackgroundColor: darkColorScheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: darkColorScheme.surface,
          foregroundColor: darkColorScheme.onSurface,
          elevation: 1.0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: darkColorScheme.primary,
          unselectedItemColor: darkColorScheme.onSurface.withOpacity(0.6),
          backgroundColor: darkColorScheme.surfaceVariant,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkColorScheme.primary,
            foregroundColor: darkColorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: darkColorScheme.outline.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: darkColorScheme.primary, width: 2.0),
            borderRadius: BorderRadius.circular(12.0),
          ),
          filled: true,
          fillColor: darkColorScheme.surfaceVariant.withOpacity(0.3),
        ),
        cardTheme: CardTheme(
          elevation: 1.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          color: Colors.black,
        ),
      ),

      home: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return MainPage(user: snapshot.data!);
          } else {
            return LoginPage();
          }
        },
      ),
    );
  }
}
