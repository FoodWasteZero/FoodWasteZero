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
import 'screens/pickup_confirm_page.dart';
import 'common/theme.dart';
import 'common/auth_helpers.dart';
import 'services/offer_promotion_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/locale_service.dart';
import 'services/theme_service.dart';

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
  await LocaleService.instance.load();
  await ThemeService.instance.load();
  OfferPromotionService.instance.start();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const FoodWasteZeroApp());
}

class FoodWasteZeroApp extends StatefulWidget {
  const FoodWasteZeroApp({super.key});

  @override
  State<FoodWasteZeroApp> createState() => _FoodWasteZeroAppState();
}

class _FoodWasteZeroAppState extends State<FoodWasteZeroApp> {
  @override
  void initState() {
    super.initState();
    LocaleService.instance.addListener(_onServiceChanged);
    ThemeService.instance.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    LocaleService.instance.removeListener(_onServiceChanged);
    ThemeService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodWasteZero',
      debugShowCheckedModeBanner: false,
      locale: LocaleService.instance.locale,
      supportedLocales: const [
        Locale('sl'),
        Locale('bs'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeService.instance.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const _AuthGate(),
    );
  }
}

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
    if (newUid == _prevUid && !_loading) return;
    final bool isInitialLoad = _loading;
    setState(() {
      _prevUid = newUid;
      _loading = false;
    });
    // ensureFirestoreAccess samo ob odjavi ali pri prvem zagonu brez prijave
    if (user == null || (user.isAnonymous && isInitialLoad)) {
      ensureFirestoreAccess();
    }
      _homeKey = UniqueKey();
    });
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
    final rezId = uri.queryParameters['rez'];
    final uid = uri.queryParameters['uid'];
    final token = uri.queryParameters['token'];
    final pickupAdId = uri.queryParameters['pickup'];
    final pickupRezId = uri.queryParameters['rez'];
    final pickupToken = uri.queryParameters['token'];
    if (adId != null && rezId != null && uid != null && token != null) {
      return OfferClaimPage(
        adId: adId,
        rezervacijaId: rezId,
        expectedUid: uid,
        token: token,
      );
    }
    if (pickupAdId != null && pickupRezId != null && pickupToken != null) {
      return PickupConfirmPage(
        adId: pickupAdId,
        rezervacijaId: pickupRezId,
        token: pickupToken,
      );
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