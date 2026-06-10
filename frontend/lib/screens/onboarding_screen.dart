import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/theme.dart';

class OnboardingScreen extends StatefulWidget {
  /// Callback kad korisnik završi ili preskoči onboarding.
  /// main.dart ga koristi za pisanje SharedPreferences i prikaz HomeScreen-a.
  final Future<void> Function()? onDone;

  const OnboardingScreen({super.key, this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  bool _finishing = false;

  // Animacijski kontroleri
  late final AnimationController _iconCtrl;
  late final AnimationController _contentCtrl;
  late final AnimationController _btnCtrl;

  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentFade;
  late Animation<double> _btnScale;

  static const _pages = [
    _OnboardingData(
      icon: Icons.eco_rounded,
      iconColor: Color(0xFF2E7D32),
      iconBgColor: Color(0xFFE8F5E9),
      title: 'Dobrodošli v FoodWasteZero',
      description:
          'Skupaj zmanjšujemo količino odpadne hrane v Sloveniji. Povezujemo skupnost ljudi, ki jim je mar za naravo.',
      gradientStart: Color(0xFF1B5E20),
      gradientEnd: Color(0xFF388E3C),
      features: [],
    ),
    _OnboardingData(
      icon: Icons.search_rounded,
      iconColor: Color(0xFF1565C0),
      iconBgColor: Color(0xFFE3F2FD),
      title: 'Brskajte in rezervirajte',
      description:
          'Na domači strani vidite vse razpoložljive oglase. Kliknite oglas za prikaz podrobnosti in ga rezervirajte z enim klikom.',
      gradientStart: Color(0xFF0D47A1),
      gradientEnd: Color(0xFF1976D2),
      features: [
        _FeatureData(Icons.filter_list_rounded, 'Filtri po kategoriji'),
        _FeatureData(Icons.bookmark_add_outlined, 'Hitra rezervacija'),
        _FeatureData(Icons.queue_rounded, 'Čakalna vrsta'),
      ],
    ),
    _OnboardingData(
      icon: Icons.volunteer_activism_rounded,
      iconColor: Color(0xFF6A1B9A),
      iconBgColor: Color(0xFFF3E5F5),
      title: 'Delite odvečno hrano',
      description:
          'Ste organizacija ali oseba ki se zavzema za naravo? Objavite oglas v 30 sekundah — dodajte sliko, opis in lokacijo. Uporabniki vam oglas rezervirajo in prevzamejo odvečno hrano.',
      gradientStart: Color(0xFF4A148C),
      gradientEnd: Color(0xFF7B1FA2),
      features: [
        _FeatureData(Icons.add_photo_alternate_outlined, 'Dodajte fotografijo'),
        _FeatureData(Icons.location_on_outlined, 'Lokacija prevzema'),
        _FeatureData(Icons.event_outlined, 'Datum poteka'),
      ],
    ),
    _OnboardingData(
      icon: Icons.map_rounded,
      iconColor: Color(0xFFE65100),
      iconBgColor: Color(0xFFFFF3E0),
      title: 'Zemljevid in navigacija',
      description:
          'Oglejte si vse oglase na interaktivnem zemljevidu. Kliknite točko in odprite navigacijo do donatorja.',
      gradientStart: Color(0xFFBF360C),
      gradientEnd: Color(0xFFE64A19),
      features: [
        _FeatureData(Icons.grain_rounded, 'Heatmap razpoložljivosti'),
        _FeatureData(Icons.directions_car_outlined, 'Google Maps navigacija'),
        _FeatureData(Icons.my_location_rounded, 'Razdalja od vas'),
      ],
    ),
    _OnboardingData(
      icon: Icons.person_rounded,
      iconColor: Color(0xFF00695C),
      iconBgColor: Color(0xFFE0F2F1),
      title: 'Vaš profil in aktivnost',
      description:
          'Pod profilom najdete rezervacije, prevzete obroke in prihodnje prevzeme za vaše objave. Organizacije vidijo svoje objave',
      gradientStart: Color(0xFF004D40),
      gradientEnd: Color(0xFF00796B),
      features: [
        _FeatureData(Icons.check_circle_outline_rounded, 'Zgodovina prevzemov'),
        _FeatureData(Icons.bookmark_outline_rounded, 'Aktivne rezervacije'),
        _FeatureData(Icons.storefront_rounded, 'Upravljanje objav'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();

    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _iconScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _iconCtrl,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic),
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut),
    );
    _btnScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOutBack),
    );

    _playEntrance();
  }

  void _playEntrance() {
    _iconCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 150),
        () => _contentCtrl.forward(from: 0));
    Future.delayed(const Duration(milliseconds: 300),
        () => _btnCtrl.forward(from: 0));
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    HapticFeedback.selectionClick();
    _iconCtrl.forward(from: 0);
    _contentCtrl.forward(from: 0);
    _btnCtrl.forward(from: 0);
  }

  Future<void> _next() async {
    if (_finishing) return;
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    HapticFeedback.mediumImpact();
    await widget.onDone?.call();
    // Ako je onDone null (npr. otvoren iz drawera), samo pop
    if (mounted && widget.onDone == null) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    _contentCtrl.dispose();
    _btnCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // ── Animirani gradijent pozadina ─────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOut,
              width: double.infinity,
              height: size.height * 0.44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [page.gradientStart, page.gradientEnd],
                ),
              ),
            ),

            // ── Dekorativni krugovi ───────────────────────────────────────
            Positioned(
              top: -40,
              right: -40,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              top: size.height * 0.15,
              left: -60,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),

            // ── Glavni sadržaj ────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        if (widget.onDone == null)
                          IconButton(
                            onPressed: _finish,
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white70, size: 24),
                          )
                        else
                          const SizedBox(width: 48),
                        const Spacer(),
                        if (!isLast)
                          TextButton(
                            onPressed: _finish,
                            child: const Text(
                              'Preskoči',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // PageView
                  Expanded(
                    child: PageView.builder(
                      controller: _pageCtrl,
                      onPageChanged: _onPageChanged,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        return _PageContent(
                          page: _pages[index],
                          iconScaleAnim: _iconScale,
                          iconFadeAnim: _iconFade,
                          contentSlideAnim: _contentSlide,
                          contentFadeAnim: _contentFade,
                        );
                      },
                    ),
                  ),

                  // Bottom: dots + button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                    child: Column(
                      children: [
                        // Dot indikatori
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_pages.length, (i) {
                            final active = i == _currentPage;
                            return GestureDetector(
                              onTap: () => _pageCtrl.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: active ? 28 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: active
                                      ? kGreenMid
                                      : kGreenMid.withOpacity(0.22),
                                  borderRadius: kRadiusFull,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),

                        // CTA gumb
                        ScaleTransition(
                          scale: _btnScale,
                          child: SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    page.gradientStart,
                                    page.gradientEnd,
                                  ],
                                ),
                                borderRadius: kRadius16,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        page.gradientEnd.withOpacity(0.38),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: kRadius16,
                                child: InkWell(
                                  borderRadius: kRadius16,
                                  onTap: _finishing ? null : _next,
                                  child: Center(
                                    child: _finishing
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                isLast
                                                    ? 'Začni zdaj'
                                                    : 'Naprej',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                isLast
                                                    ? Icons
                                                        .rocket_launch_rounded
                                                    : Icons
                                                        .arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sadržaj jedne stranice
// ─────────────────────────────────────────────────────────────────────────────
class _PageContent extends StatelessWidget {
  final _OnboardingData page;
  final Animation<double> iconScaleAnim;
  final Animation<double> iconFadeAnim;
  final Animation<Offset> contentSlideAnim;
  final Animation<double> contentFadeAnim;

  const _PageContent({
    required this.page,
    required this.iconScaleAnim,
    required this.iconFadeAnim,
    required this.contentSlideAnim,
    required this.contentFadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Animirani ikona hero
          ScaleTransition(
            scale: iconScaleAnim,
            child: FadeTransition(
              opacity: iconFadeAnim,
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.35), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(page.icon, color: Colors.white, size: 52),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Kartica s tekstom i featurima
          SlideTransition(
            position: contentSlideAnim,
            child: FadeTransition(
              opacity: contentFadeAnim,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: kRadius24,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Mini ikona chip
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: page.iconBgColor,
                        borderRadius: kRadius12,
                      ),
                      child: Icon(page.icon, color: page.iconColor, size: 24),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      page.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: kTextDark,
                        letterSpacing: -0.4,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      page.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: kTextMid,
                        height: 1.6,
                      ),
                    ),

                    if (page.features.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Divider(color: kBorder.withOpacity(0.5), height: 1),
                      const SizedBox(height: 14),
                      ...page.features.map((f) => _FeatureRow(
                            feature: f,
                            color: page.iconColor,
                            bgColor: page.iconBgColor,
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final _FeatureData feature;
  final Color color;
  final Color bgColor;

  const _FeatureRow({
    required this.feature,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: bgColor, borderRadius: kRadius8),
            child: Icon(feature.icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature.label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: kTextDark,
              ),
            ),
          ),
          Icon(Icons.check_rounded, color: color, size: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data modeli
// ─────────────────────────────────────────────────────────────────────────────
class _FeatureData {
  final IconData icon;
  final String label;
  const _FeatureData(this.icon, this.label);
}

class _OnboardingData {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String description;
  final Color gradientStart;
  final Color gradientEnd;
  final List<_FeatureData> features;

  const _OnboardingData({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.description,
    required this.gradientStart,
    required this.gradientEnd,
    required this.features,
  });
}