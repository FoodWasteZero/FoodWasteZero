import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'common/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const FoodWasteZeroApp());
}

class FoodWasteZeroApp extends StatelessWidget {
  const FoodWasteZeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodWasteZero',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kGreenMid,
          primary: kGreenMid,
          surface: kSurface,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: kSurface,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: kTextDark,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kGreenMid,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: kRadius12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kGreenMid,
            side: const BorderSide(color: kGreenMid),
            shape: const RoundedRectangleBorder(borderRadius: kRadius12),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
        ),
        tabBarTheme: const TabBarThemeData(
          dividerColor: Colors.transparent,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kGreenMid,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: kRadius12),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

// ── Auth gate — automatski preusmjerava na login ili home ─────────────────────
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF2E7D32),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.eco_rounded, color: Colors.white, size: 56),
                  SizedBox(height: 16),
                  Text('FoodWasteZero',
                    style: TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: Colors.white60, strokeWidth: 2),
                ],
              ),
            ),
          );
        }

        // Prijavljen → HomeScreen
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // Ni prijavljen → AuthScreen
        return const AuthScreen();
      },
    );
  }
}