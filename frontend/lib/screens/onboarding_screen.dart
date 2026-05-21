import 'package:flutter/material.dart';
import '../common/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.eco_rounded,
      iconColor: Color(0xFF2E7D32),
      iconBgColor: Color(0xFFE8F5E9),
      title: 'Dobrodošli v FoodWasteZero',
      description:
          'Skupaj zmanjšujemo odpadanje hrane v Mariboru. Povežemo tiste, ki imajo odvečno hrano, s tistimi, ki jo potrebujejo — brezplačno in preprosto.',
      gradient: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
      features: [],
    ),
    _OnboardingPage(
      icon: Icons.search_rounded,
      iconColor: Color(0xFF1565C0),
      iconBgColor: Color(0xFFE3F2FD),
      title: 'Brskajte in rezervirajte',
      description:
          'Na domači strani vidite vse razpoložljive oglase v vaši bližini. Tapnite oglas za podrobnosti in ga rezervirajte z enim klikom.',
      gradient: [Color(0xFF0D47A1), Color(0xFF1565C0)],
      features: [
        _Feature(Icons.filter_list_rounded, 'Filtri', 'Filtrirajte po kategoriji (Kuhano, Peka, Sadje...), razdalji ali datumu poteka.'),
        _Feature(Icons.bookmark_add_outlined, 'Rezervacija', 'Ko rezervirate oglas, je shranjen pod vašim profilom v zavihku "Rezervirano".'),
        _Feature(Icons.queue_rounded, 'Čakalna vrsta', 'Če je oglas že rezerviran, se postavite v čakalno vrsto — obveščeni boste samodejno.'),
      ],
    ),
    _OnboardingPage(
      icon: Icons.volunteer_activism_rounded,
      iconColor: Color(0xFF6A1B9A),
      iconBgColor: Color(0xFFF3E5F5),
      title: 'Delite odvečno hrano',
      description:
          'Ste davatelj? Objavite oglas v 30 sekundah — dodajte sliko, opis, lokacijo in datum poteka. Vaše objave so vidne vsem v okolici.',
      gradient: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
      features: [
        _Feature(Icons.add_photo_alternate_outlined, 'Dodajte sliko', 'Fotografija poveča zanimanje za vaš oglas.'),
        _Feature(Icons.location_on_outlined, 'Lokacija', 'Določite točno lokacijo prevzema — prikazana bo na zemljevidu.'),
        _Feature(Icons.event_outlined, 'Datum poteka', 'Nastavite rok — aplikacija samodejno označi oglase, ki kmalu potečejo.'),
      ],
    ),
    _OnboardingPage(
      icon: Icons.map_rounded,
      iconColor: Color(0xFFE65100),
      iconBgColor: Color(0xFFFFF3E0),
      title: 'Zemljevid in navigacija',
      description:
          'Oglejte si vse oglase na interaktivnem zemljevidu. Tapnite točko in s klikom odprite navigacijo — Google Maps vas popelje do donatorja.',
      gradient: [Color(0xFFBF360C), Color(0xFFE65100)],
      features: [
        _Feature(Icons.grain_rounded, 'Toplotna karta', 'Heatmap na domači strani prikazuje, kje v mestu je največ razpoložljive hrane.'),
        _Feature(Icons.directions_car_outlined, 'Navigacija', 'Gumb "Pelji me tja" v vsakem oglasu odpre Google Maps z usmeritvami.'),
        _Feature(Icons.my_location_rounded, 'Vaša lokacija', 'Razdalja do oglasa se izračuna glede na vaše trenutno mesto.'),
      ],
    ),
    _OnboardingPage(
      icon: Icons.person_rounded,
      iconColor: Color(0xFF00695C),
      iconBgColor: Color(0xFFE0F2F1),
      title: 'Vaš profil in aktivnost',
      description:
          'Pod profilom najdete vse svoje rezervacije in prevzete obroke. Davatelji vidijo svoje objave in arhiv. Vsak lahko uredi svoje podatke.',
      gradient: [Color(0xFF004D40), Color(0xFF00695C)],
      features: [
        _Feature(Icons.check_circle_outline_rounded, 'Prevzeto', 'Zgodovina vseh obrokov, ki ste jih uspešno prevzeli.'),
        _Feature(Icons.bookmark_outline_rounded, 'Rezervirano', 'Aktivne rezervacije — oglas čaka na vas, da ga prevzamete.'),
        _Feature(Icons.storefront_rounded, 'Moje objave', 'Davatelji imajo pregled nad vsemi svojimi aktivnimi in arhiviranimi oglasi.'),
      ],
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: page.gradient,
              ),
            ),
            height: MediaQuery.of(context).size.height * 0.42,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 24),
                      ),
                      const Spacer(),
                      if (!isLast)
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Preskoči',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) =>
                        _buildPageContent(_pages[index]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final active = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? kGreenMid
                                  : kGreenMid.withOpacity(0.25),
                              borderRadius: kRadiusFull,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreenMid,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: const RoundedRectangleBorder(
                                borderRadius: kRadius16),
                            elevation: 0,
                          ),
                          child: Text(
                            isLast ? 'Začni zdaj' : 'Naprej',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
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
    );
  }

  Widget _buildPageContent(_OnboardingPage page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: kRadiusFull,
              border:
                  Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            ),
            child: Icon(page.icon, color: Colors.white, size: 54),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: kRadius24,
              boxShadow: kElevatedShadow,
            ),
            child: Column(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                      color: page.iconBgColor, borderRadius: kRadius12),
                  child: Icon(page.icon, color: page.iconColor, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kTextDark,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  page.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: kTextMid, height: 1.6),
                ),
                if (page.features.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(color: kBorder, height: 1),
                  const SizedBox(height: 16),
                  ...page.features.map((f) => _FeatureTile(feature: f)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final _Feature feature;
  const _FeatureTile({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: kGreenPale,
              borderRadius: kRadius8,
            ),
            child: Icon(feature.icon, color: kGreenMid, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextDark)),
                const SizedBox(height: 2),
                Text(feature.description,
                    style: const TextStyle(
                        fontSize: 12, color: kTextMid, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String description;
  const _Feature(this.icon, this.title, this.description);
}

class _OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String description;
  final List<Color> gradient;
  final List<_Feature> features;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.description,
    required this.gradient,
    required this.features,
  });
}