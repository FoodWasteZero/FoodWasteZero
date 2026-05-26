import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/offer_claim_page.dart';
import 'common/theme.dart';
import 'common/auth_helpers.dart';
import 'services/offer_promotion_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kDebugMode) {
    debugPrint('Firebase projectId: ${Firebase.app().options.projectId}');
  }
  await ensureFirestoreAccess();
  // Start client-driven offer promotion service (handles expired 3h offers)
  OfferPromotionService.instance.start();
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

// ── Auth gate ──────────────────────────────────────────────────────────────────
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Key _homeKey = UniqueKey();
  bool _loading = true;
  bool _showOnboarding = false;
  String? _prevUid;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (mounted) {
      setState(() => _showOnboarding = !seen);
    }
  }

  void _onAuthChanged(User? user) {
    if (!mounted) return;
    final newUid = user?.uid;
    final isGuest = user == null || user.isAnonymous;
    if (newUid == _prevUid && !_loading) return;
    setState(() {
      _prevUid = newUid;
      _loading = false;
      _homeKey = UniqueKey();
    });
    if (isGuest && user == null) {
      ensureFirestoreAccess();
    }
  }

  Future<void> _onOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();
    final uri = Uri.base;
    final adId = uri.queryParameters['claim'];
    final uid = uri.queryParameters['uid'];
    final token = uri.queryParameters['token'];
    if (adId != null && uid != null && token != null) {
      return OfferClaimPage(adId: adId, expectedUid: uid, token: token);
    }
    if (_showOnboarding) {
      return OnboardingScreen(onDone: _onOnboardingDone);
    }
    return HomeScreen(key: _homeKey);
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF2E7D32),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_rounded, color: Colors.white, size: 56),
            SizedBox(height: 16),
            Text('FoodWasteZero',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.white60, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}