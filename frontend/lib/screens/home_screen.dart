import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../cards/org_stat_sheet.dart';
import '../common/theme.dart';
import '../common/firestore_error.dart';
import '../common/auth_helpers.dart';
import '../models/models.dart';
import '../cards/food_card.dart';
import '../cards/food_detail_sheet.dart';
import 'offer_claim_page.dart';
import 'profile_page.dart';
import 'mine_screen.dart';
import 'auth_screen.dart';
import 'recipe_page.dart';
import '../widgets/app_drawer.dart';
import '../services/ui_state_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper: Firestore doc → FoodOglas
// ─────────────────────────────────────────────────────────────────────────────
FoodOglas _docToOglas(DocumentSnapshot doc) {
  final d = doc.data() as Map<String, dynamic>;
  final statusStr = d['status'] as String? ?? 'naRazpolago';
  final status = statusStr == 'rezervirano'
      ? OglasStatus.rezervirano
      : statusStr == 'prevzeto'
          ? OglasStatus.prevzeto
          : OglasStatus.naRazpolago;

  final category = d['category'] as String? ?? 'Sestavine';
  final IconData icon;
  final Color color;
  switch (category) {
    case 'Kuhano':
      icon = Icons.soup_kitchen_rounded; color = const Color(0xFFFFE0B2); break;
    case 'Peka':
      icon = Icons.bakery_dining_rounded; color = const Color(0xFFEFEBE9); break;
    case 'Sadje & zelenjava':
      icon = Icons.apple_rounded; color = const Color(0xFFE8F5E9); break;
    case 'Ostalo':
      icon = Icons.more_horiz_rounded; color = const Color(0xFFE8EAF6); break;
    default:
      icon = Icons.grass_rounded; color = const Color(0xFFF1F8E9);
  }

  double distKm = 0.0; // Razdalja se preračuna v _applyFilters glede na pravo GPS lokacijo
  final lat = (d['lat'] as num?)?.toDouble();
  final lng = (d['lng'] as num?)?.toDouble();

  final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
  final expiryDate = (d['expiryDate'] as Timestamp?)?.toDate();

  bool expiringSoon = d['expiringSoon'] as bool? ?? false;
  if (expiryDate != null) {
    final hoursLeft = expiryDate.difference(DateTime.now()).inHours;
    if (hoursLeft <= 24 && hoursLeft >= 0) expiringSoon = true;
  }

  final waitlistRaw = d['waitlist'];
  final waitlist = (waitlistRaw is List)
      ? waitlistRaw.map((e) => e.toString()).toList()
      : <String>[];

  return FoodOglas(
    id: doc.id,
    uid: d['uid'] as String?,
    title: d['title'] as String? ?? '',
    description: d['description'] as String? ?? '',
    location: d['location'] as String? ?? '',
    time: _timeAgo(createdAt),
    status: status,
    username: d['username'] as String?,
    imageColor: color,
    category: category,
    isFree: d['isFree'] as bool? ?? true,
    isExpiringSoon: expiringSoon,
    distanceKm: distKm,
    icon: icon,
    latLng: (lat != null && lng != null) ? LatLng(lat, lng) : null,
    imageBase64: d['imageBase64'] as String?,
    reservedByUid: d['reservedByUid'] as String?,
    expiryDate: expiryDate,
    termin1: (d['termin1'] as Timestamp?)?.toDate(),
    termin2: (d['termin2'] as Timestamp?)?.toDate(),
    termin3: (d['termin3'] as Timestamp?)?.toDate(),
    termin4: (d['termin4'] as Timestamp?)?.toDate(),
    chosenTermin: (d['chosenTermin'] as Timestamp?)?.toDate(),
    offerPending: d['offerPending'] as bool? ?? false,
    offerExpiresAt: (d['offerExpiresAt'] as Timestamp?)?.toDate(),
    offerToken: d['offerToken'] as String?,
    waitlist: waitlist,
    portions: (d['portions'] as num?)?.toInt(),
    remainingPortions: (d['remainingPortions'] as num?)?.toInt(),
    reservedPortions: (d['reservedPortions'] as num?)?.toInt(),
    price: (d['price'] as num?)?.toDouble(),
    isDavatelj: d['isDavatelj'] as bool? ?? false,
  );
}

String _timeAgo(DateTime? dt) {
  if (dt == null) return 'Pravkar';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Pravkar';
  if (diff.inMinutes < 60) return 'Pred ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Pred ${diff.inHours} ur';
  return 'Pred ${diff.inDays} dni';
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isDavatelj = false;
  int _selectedTab = 0;
  int _navIndex = 0;
  String _searchQuery = '';
  String? _activeFilter;
  String _mesto = 'Lokacija...';
  final TextEditingController _searchCtrl = TextEditingController();
  StreamSubscription<User?>? _authSub;

  // Za scroll-to-oglas iz heatmape
  final ScrollController _listScrollCtrl = ScrollController();
  // Mapa id → pozicija u filtered listi (osvježi se pri svakom buildu)
  final Map<String, int> _oglasIndexMap = {};

  // Prava lokacija korisnika
  double? _userLat;
  double? _userLng;
  bool _locationLoading = false;
  String? _locationError;

  // Animacija za inverzijo barv (uporabnik=0.0 → organizacija=1.0)
  late AnimationController _themeAnim;
  late Animation<double> _themeProgress;

  static const _tabs = ['Vse', 'Kuhano', 'Sestavine', 'Peka', 'Sadje & zelenjava'];

  @override
  void initState() {
    super.initState();
    _themeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _themeProgress = CurvedAnimation(parent: _themeAnim, curve: Curves.easeInOut);
    _loadUserType();
    // Takoj ob zagonu zahtevaj lokacijo — tiho v ozadju, brez forsiranja filtra
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLocationSilent();
    });
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user == null) {
        _themeAnim.reverse();
        setState(() { _isDavatelj = false; _navIndex = 0; });
      } else {
        _loadUserType();
      }
    });
  }

  // ── Tiho pridobi lokacijo ob zagonu (samo prosi za dovoljenje + GPS) ─────
  Future<void> _fetchLocationSilent() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Pokaži sistemski dialog za dovoljenje — to je tisto "kot ostale aplikacije"
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      // Najprej poskusi hitro zadnjo znano lokacijo (takojšen odziv)
      Position? lastKnown;
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      if (lastKnown != null && mounted) {
        setState(() {
          _userLat = lastKnown!.latitude;
          _userLng = lastKnown!.longitude;
        });
        _reverseGeocode(lastKnown.latitude, lastKnown.longitude);
      }

      // Potem pridobi natančno lokacijo
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
        });
        _reverseGeocode(pos.latitude, pos.longitude);
      }
    } catch (_) {
      // Tiho spregledaj napake pri zagonu — uporabnik ni kliknil ničesar
    }
  }

  // ── Prava GPS lokacija korisnika ──────────────────────────────────────────
  Future<void> _fetchLocation() async {
    if (_locationLoading) return;
    setState(() { _locationLoading = true; _locationError = null; });

    try {
      // 1. Provjeri je li servis uključen
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() {
          _locationLoading = false;
          _locationError = 'Lokacijska storitev je izklopljena.';
        });
        return;
      }

      // 2. Provjeri/zatraži dozvolu
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() {
            _locationLoading = false;
            _locationError = 'Dostop do lokacije zavrnjen.';
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() {
          _locationLoading = false;
          _locationError = 'Lokacija trajno blokirana. Omogočite jo v nastavitvah.';
        });
        await Geolocator.openAppSettings();
        return;
      }

      // 3. Dohvati lokaciju
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );

      if (mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
          _locationLoading = false;
          _locationError = null;
          _activeFilter = 'nearest';
        });

        // 4. Reverse geocoding — prikaži pravo ime mesta u app baru
        _reverseGeocode(pos.latitude, pos.longitude);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: const [
              Icon(Icons.my_location_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Lokacija pridobljena — razvrščam po razdalji'),
            ]),
            backgroundColor: kGreenMid,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: kRadius12),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() {
        _locationLoading = false;
        _locationError = 'Napaka pri pridobivanju lokacije.';
      });
    }
  }

  // ── Reverse geocoding: koordinate → ime grada ────────────────────────────
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'format': 'json',
        'zoom': '10', // nivo grada
        'addressdetails': '1',
      });
      final resp = await http.get(uri, headers: {
        'User-Agent': 'PraktikumApp/1.0 (flutter)',
        'Accept-Language': 'sl,en',
      }).timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) return;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null || !mounted) return;

      // Prioritet: city → town → village → municipality → county
      final label =
          (address['city'] as String?) ??
          (address['town'] as String?) ??
          (address['village'] as String?) ??
          (address['municipality'] as String?) ??
          (address['county'] as String?) ??
          _mesto;

      if (mounted) setState(() => _mesto = label);
    } catch (_) {
      // Ako geocoding ne uspije, ostavi staro ime mjesta
    }
  }

  Future<void> _loadUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      final isDav = doc.data()?['userType'] == 'davatelj';
      setState(() {
        _isDavatelj = isDav;
        if (isDav && _navIndex == 1) _navIndex = 0;
      });
      if (isDav) {
        _themeAnim.forward();
      } else {
        _themeAnim.reverse();
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _searchCtrl.dispose();
    _themeAnim.dispose();
    _listScrollCtrl.dispose();
    super.dispose();
  }

  void _showMestoDialog() {
    final ctrl = TextEditingController(text: _mesto);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: kRadius16),
        title: const Row(children: [
          Icon(Icons.location_on_rounded, color: kGreenMid, size: 20),
          SizedBox(width: 8),
          Text('Spremeni lokacijo', style: kHeading3),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Vnesite mesto...',
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                borderRadius: kRadius12,
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in ['Maribor', 'Ljubljana', 'Celje', 'Kranj', 'Koper'])
              GestureDetector(
                onTap: () { ctrl.text = m; },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kGreenPale,
                    borderRadius: kRadiusFull,
                    border: Border.all(color: kGreenMid.withOpacity(0.3)),
                  ),
                  child: Text(m,
                      style: const TextStyle(fontSize: 14, color: kGreenMid, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Prekliči', style: TextStyle(color: kTextLight)),
          ),
          ElevatedButton(
            onPressed: () {
              final novo = ctrl.text.trim();
              if (novo.isNotEmpty) setState(() => _mesto = novo);
              Navigator.pop(ctx);
            },
            child: const Text('Potrdi'),
          ),
        ],
      ),
    );
  }

  List<FoodOglas> _applyFilters(List<FoodOglas> all) {
    var list = List<FoodOglas>.from(all);

    // Vedno preračunaj razdaljo — od prave GPS lokacije ali Maribora kot fallback
    final refLat = _userLat ?? 46.5547;
    final refLng = _userLng ?? 15.6459;
    list = list.map((o) {
      if (o.latLng == null) return o;
      final dLat = (o.latLng!.lat - refLat) * 111.0;
      final dLng = (o.latLng!.lng - refLng) * 111.0 * cos(refLat * pi / 180);
      return o.copyWithDistance(sqrt(dLat * dLat + dLng * dLng));
    }).toList();

    if (_selectedTab != 0) {
      list = list.where((o) => o.category == _tabs[_selectedTab]).toList();
    }
    switch (_activeFilter) {
      case 'available':
        list = list.where((o) => o.status == OglasStatus.naRazpolago).toList();
        break;
      case 'expiring':
        list = list.where((o) => o.isExpiringSoon).toList();
        break;
      case 'reserved':
        list = list.where((o) => o.status == OglasStatus.rezervirano).toList();
        break;
      case 'nearest':
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((o) =>
        o.title.toLowerCase().contains(q) ||
        o.location.toLowerCase().contains(q) ||
        o.category.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _setFilter(String? f) {
    final newFilter = (_activeFilter == f) ? null : f;
    setState(() => _activeFilter = newFilter);
    // Kad aktiviramo "nearest" filter, takoj zahtevamo pravo lokacijo
    if (newFilter == 'nearest') {
      _fetchLocation();
    }
  }

  void _showAuthPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AuthScreen(isModal: true),
    );
  }

  bool get _isGuest => isAppGuest(FirebaseAuth.instance.currentUser);

  /// Zavihki, ki zahtevajo prijavo (indeksi v spodnji navigaciji).
  List<int> _authRequiredNavIndices() {
    if (_isDavatelj) return [1, 2];
    return [1, 2, 3];
  }

  void _goToProfile() => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const ProfilePage()));

  void _showAddOglas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true, 
      builder: (_) => AddOglasSheet(
        showPriceField: true,
        onSaved: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oglas uspešno objavljen! 🎉')));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeProgress,
      builder: (context, _) {
        // t=0 → uporabnik (zeleni app bar, beli nav)
        // t=1 → organizacija (beli app bar, zeleni nav)
        final t = _themeProgress.value;
        final navBg = Color.lerp(Colors.white, kGreenMid, t)!;
        final navIndicator = Color.lerp(kGreenPale, Colors.white.withOpacity(0.25), t)!;
        final navSelectedIcon = Color.lerp(kGreenMid, Colors.white, t)!;
        final navUnselectedIcon = Color.lerp(Colors.grey, Colors.white.withOpacity(0.6), t)!;

        return Scaffold(
          backgroundColor: Color.lerp(kSurface, const Color(0xFFE8F5E9), t * 0.5)!,
          body: _buildBody(),
          floatingActionButton: null,
          bottomNavigationBar: _buildBottomNav(
            navBg: navBg,
            navIndicator: navIndicator,
            navSelectedIcon: navSelectedIcon,
            navUnselectedIcon: navUnselectedIcon,
          ),
        );
      },
    );
  }

  List<Widget> get _pages => _isDavatelj
      ? [_buildHomeWithStream(), const MineScreen(), const ProfilePage()]
      : [_buildHomeWithStream(), const RecipePage(), const MineScreen(), const ProfilePage()];

  Widget _buildBody() {
    final pages = _pages;
    final idx = _navIndex.clamp(0, pages.length - 1);
    return pages[idx];
  }

  Widget _buildHomeWithStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('oglasi').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreenMid));
        }
        if (snap.hasError) {
          final projectId = FirebaseFirestore.instance.app.options.projectId;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Napaka pri nalaganju oglasov.\n\n'
                '${firestoreErrorMessage(snap.error)}\n\n'
                'Projekt aplikacije: $projectId',
                style: kBody,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final rawDocs = snap.hasData ? snap.data!.docs.toList() : <QueryDocumentSnapshot>[];
        rawDocs.sort((a, b) {
          final da = a.data() as Map<String, dynamic>;
          final db = b.data() as Map<String, dynamic>;
          return createdAtMillis(db).compareTo(createdAtMillis(da));
        });
        final oglasi = rawDocs.map(_docToOglas).toList();

        final filtered = _applyFilters(oglasi);
        final availableCount = oglasi.where((o) => o.status == OglasStatus.naRazpolago).length;
        final expiringCount  = oglasi.where((o) => o.isExpiringSoon).length;
        final reservedCount  = oglasi.where((o) => o.status == OglasStatus.rezervirano).length;

        return _buildHomeContent(filtered, oglasi, availableCount, expiringCount, reservedCount);
      },
    );
  }

  Widget _buildHomeContent(
    List<FoodOglas> filtered,
    List<FoodOglas> all,
    int availableCount,
    int expiringCount,
    int reservedCount,
  ) {
    // Build lookup map so heatmap can scroll to correct item
    _oglasIndexMap.clear();
    for (int i = 0; i < filtered.length; i++) {
      _oglasIndexMap[filtered[i].id] = i;
    }

    if (_isDavatelj) {
      return _buildOrgHomeContent(filtered, availableCount, expiringCount, reservedCount);
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final pendingOffers = currentUser == null
        ? <FoodOglas>[]
        : all.where((o) => o.reservedByUid == currentUser.uid && o.offerPending).toList();

    return CustomScrollView(controller: _listScrollCtrl, slivers: [
      _buildSliverAppBar(),
      if (_isGuest) SliverToBoxAdapter(child: _buildGuestBanner()),
      if (pendingOffers.isNotEmpty)
        SliverToBoxAdapter(
          child: ValueListenableBuilder<bool>(
            valueListenable: UIStateService.instance.isDetailOpen,
            builder: (_, isDetailOpen, __) {
              return isDetailOpen ? const SizedBox.shrink() : _buildPendingOfferBanner(pendingOffers.first);
            },
          ),
        ),
      SliverToBoxAdapter(child: _buildSearchBar()),
      SliverToBoxAdapter(child: _buildQuickActionsRow()),
      SliverToBoxAdapter(child: _buildHeatmapSection(filtered)),
      SliverToBoxAdapter(child: _buildListingsHeader(filtered.length)),
      SliverToBoxAdapter(child: _buildTabRow()),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        sliver: filtered.isEmpty
            ? const SliverToBoxAdapter(child: _EmptyState())
            : SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => FoodCard(
                  oglas: filtered[i],
                  onTap: () => FoodDetailSheet.show(context, filtered[i]),
                ),
                childCount: filtered.length,
              )),
      ),
    ]);
  }

  Widget _buildPendingOfferBanner(FoodOglas oglas) {
    final expiresAt = oglas.offerExpiresAt;
    final remaining = expiresAt == null ? null : expiresAt.difference(DateTime.now());
    final remainingText = remaining == null
        ? 'Rok potrditve ni znan'
        : remaining.isNegative
            ? 'Potrditev je potekla'
            : 'Še ${remaining.inHours} h ${remaining.inMinutes.remainder(60)} min';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: kRadius16,
          border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mark_email_read_rounded, color: Color(0xFFE65100)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rezervacija čaka na potrditev',
                    style: kHeading3.copyWith(color: kTextDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${oglas.title}\n$remainingText',
              style: const TextStyle(fontSize: 13.5, height: 1.35, color: kTextDark),
            ),
            if (oglas.chosenTermin != null) ...[
              const SizedBox(height: 8),
              Text(
                'Izbran termin: ${_formatTerm(oglas.chosenTermin!)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kGreenMid),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: oglas.offerToken == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OfferClaimPage(
                                adId: oglas.id,
                                expectedUid: oglas.reservedByUid ?? '',
                                token: oglas.offerToken!,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Odpri potrditev'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreenMid,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Povezava iz e-pošte odpre isto potrditveno stran v aplikaciji ali spletnem brskalniku.',
              style: TextStyle(fontSize: 11.5, color: kTextLight, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTerm(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.${dt.year} $hour:$minute';
  }

  Widget _buildOrgHomeContent(
    List<FoodOglas> filtered, int available, int expiring, int reserved) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return CustomScrollView(slivers: [
      _buildOrgSliverAppBar(),

      // ── Zgornji del: današnje statistike ──────────────────────────────────
      SliverToBoxAdapter(child: _buildDavateljTodayStats(currentUser?.uid)),

      // ── Sredina: prihodnji prevzemi + gumb ────────────────────────────────
      SliverToBoxAdapter(child: _buildUpcomingPickups(filtered, currentUser?.uid)),

      // ── Spodnji del: 7-dnevni graf ────────────────────────────────────────
      SliverToBoxAdapter(child: _buildWeeklyChart(currentUser?.uid)),

      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ]);
  }

  // ── Današnje statistike (prihodki, prevzemi, rešeni obroki) ───────────────
  Widget _buildDavateljTodayStats(String? uid) {
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final docs = snap.data?.docs ?? [];

        // Filtriraj samo današnje prevzete oglase
        final todayPrevzeti = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          if (data['status'] != 'prevzeto') return false;
          final ts = data['chosenTermin'] as Timestamp? ??
              data['updatedAt'] as Timestamp? ??
              data['createdAt'] as Timestamp?;
          if (ts == null) return false;
          return ts.toDate().isAfter(todayStart);
        }).toList();

        // Prihodki danes (seštej cene prevzetih)
        double todayRevenue = 0;
        for (final d in todayPrevzeti) {
          final data = d.data() as Map<String, dynamic>;
          final price = (data['price'] as num?)?.toDouble() ?? 0.0;
          final portions = (data['reservedPortions'] as num?)?.toInt() ?? 1;
          todayRevenue += price * portions;
        }

        // Prevzemi danes
        final todayPrevzemiCount = todayPrevzeti.length;

        // Rešeni obroki danes (remainingPortions, ki so bile rezervirane)
        int reseniObroki = 0;
        for (final d in todayPrevzeti) {
          final data = d.data() as Map<String, dynamic>;
          reseniObroki += (data['reservedPortions'] as num?)?.toInt() ?? 1;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.today_rounded, size: 17, color: kGreenMid),
                const SizedBox(width: 6),
                Text(
                  'Danes, ${_formatDate(now)}',
                  style: kHeading3.copyWith(fontSize: 15),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _DavateljStatCard(
                  icon: Icons.euro_rounded,
                  value: todayRevenue == 0
                      ? '—'
                      : '${todayRevenue.toStringAsFixed(2)} €',
                  label: 'Današnji prihodki',
                  color: const Color(0xFF00897B),
                  bgColor: const Color(0xFFE0F2F1),
                )),
                const SizedBox(width: 10),
                Expanded(child: _DavateljStatCard(
                  icon: Icons.shopping_bag_rounded,
                  value: '$todayPrevzemiCount',
                  label: 'Današnji prevzemi',
                  color: const Color(0xFF1E88E5),
                  bgColor: const Color(0xFFE3F2FD),
                )),
                const SizedBox(width: 10),
                Expanded(child: _DavateljStatCard(
                  icon: Icons.volunteer_activism_rounded,
                  value: '$reseniObroki',
                  label: 'Rešeni obroki',
                  color: kGreenMid,
                  bgColor: kGreenPale,
                )),
              ]),
            ],
          ),
        );
      },
    );
  }

  // ── Prihodnji prevzemi ─────────────────────────────
  Widget _buildUpcomingPickups(List<FoodOglas> allOglasi, String? uid) {
    final now = DateTime.now();

    // Filtriraj oglase tega davatelja z bodočimi termini
    final myOglasi = uid == null
        ? allOglasi
        : allOglasi.where((o) => o.uid == uid).toList();

    // Zgradi seznam prihodnjih prevzemov iz terminov
    final List<_UpcomingPickup> upcoming = [];
    for (final oglas in myOglasi) {
      if (oglas.status == OglasStatus.prevzeto) continue;
      final termini = [oglas.termin1, oglas.termin2, oglas.termin3, oglas.termin4]
          .where((t) => t != null && t.isAfter(now))
          .cast<DateTime>()
          .toList()
        ..sort();
      for (final t in termini) {
        upcoming.add(_UpcomingPickup(oglas: oglas, termin: t));
        break; // samo najbližji termin za vsak oglas
      }
    }
    upcoming.sort((a, b) => a.termin.compareTo(b.termin));
    final show = upcoming.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 17, color: kGreenMid),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Prihodnji prevzemi', style: kHeading3.copyWith(fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (show.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: kRadius12,
                border: Border.all(color: kBorder),
              ),
              child: const Center(
                child: Column(children: [
                  Icon(Icons.event_available_rounded, color: kTextLight, size: 32),
                  SizedBox(height: 8),
                  Text('Ni prihodnjih prevzemov',
                      style: TextStyle(color: kTextLight, fontSize: 14)),
                ]),
              ),
            )
          else
            ...show.map((p) => _UpcomingPickupTile(
              pickup: p,
              onTap: () => OrgStatSheet.show(context, p.oglas),
            )),
        ],
      ),
    );
  }

  // ── 7-dnevni graf uspešnosti ───────────────────────────────────────────────
  Widget _buildWeeklyChart(String? uid) {
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'prevzeto')
          .snapshots(),
      builder: (context, snap) {
        final now = DateTime.now();
        // Zadnjih 7 dni (vključno z danes)
        final days = List.generate(7, (i) {
          final d = now.subtract(Duration(days: 6 - i));
          return DateTime(d.year, d.month, d.day);
        });

        // Štej prevzeme po dnevu
        final Map<DateTime, int> counts = {for (final d in days) d: 0};
        final Map<DateTime, double> revenues = {for (final d in days) d: 0.0};

        for (final doc in snap.data?.docs ?? []) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['chosenTermin'] as Timestamp? ??
              data['updatedAt'] as Timestamp? ??
              data['createdAt'] as Timestamp?;
          if (ts == null) continue;
          final dt = ts.toDate();
          final key = DateTime(dt.year, dt.month, dt.day);
          if (counts.containsKey(key)) {
            counts[key] = (counts[key] ?? 0) + 1;
            final price = (data['price'] as num?)?.toDouble() ?? 0.0;
            final portions = (data['reservedPortions'] as num?)?.toInt() ?? 1;
            revenues[key] = (revenues[key] ?? 0) + price * portions;
          }
        }

        final maxCount = counts.values.fold(0, max).toDouble();
        final dayLabels = ['Pon', 'Tor', 'Sre', 'Čet', 'Pet', 'Sob', 'Ned'];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.bar_chart_rounded, size: 17, color: kGreenMid),
                const SizedBox(width: 6),
                Text('7-dnevna uspešnost', style: kHeading3.copyWith(fontSize: 15)),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: kRadius16,
                  border: Border.all(color: kBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Graf stolpcev
                    SizedBox(
                      height: 110,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (i) {
                          final day = days[i];
                          final count = counts[day] ?? 0;
                          final rev = revenues[day] ?? 0.0;
                          final isToday = day == DateTime(now.year, now.month, now.day);
                          final frac = maxCount == 0 ? 0.0 : count / maxCount;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (count > 0)
                                    Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isToday ? kGreenMid : kTextMid,
                                      ),
                                    ),
                                  const SizedBox(height: 3),
                                  Tooltip(
                                    message: count == 0
                                        ? 'Ni prevzemov'
                                        : '$count prevzem${count == 1 ? '' : 'ov'}'
                                            '${rev > 0 ? '\n${rev.toStringAsFixed(2)} €' : ''}',
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeOut,
                                      height: frac == 0 ? 4 : (frac * 85).clamp(8, 85),
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? kGreenMid
                                            : count == 0
                                                ? kBorder
                                                : kGreenMid.withOpacity(0.4),
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Oznake dni
                    Row(
                      children: List.generate(7, (i) {
                        final day = days[i];
                        final isToday = day == DateTime(now.year, now.month, now.day);
                        final weekday = day.weekday - 1; // 0=pon
                        return Expanded(
                          child: Text(
                            dayLabels[weekday],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                              color: isToday ? kGreenMid : kTextLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    // Skupaj v 7 dneh
                    const Divider(height: 1, color: kBorder),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _WeekSummaryItem(
                          icon: Icons.shopping_bag_outlined,
                          value: '${counts.values.fold(0, (a, b) => a + b)}',
                          label: 'Prevzemi',
                          color: const Color(0xFF1E88E5),
                        ),
                        Container(width: 1, height: 32, color: kBorder),
                        _WeekSummaryItem(
                          icon: Icons.euro_rounded,
                          value: () {
                            final total = revenues.values.fold(0.0, (a, b) => a + b);
                            return total == 0 ? '—' : '${total.toStringAsFixed(2)} €';
                          }(),
                          label: 'Prihodki',
                          color: const Color(0xFF00897B),
                        ),
                        Container(width: 1, height: 32, color: kBorder),
                        _WeekSummaryItem(
                          icon: Icons.volunteer_activism_rounded,
                          value: () {
                            int total = 0;
                            for (final doc in snap.data?.docs ?? []) {
                              final data = doc.data() as Map<String, dynamic>;
                              total += (data['reservedPortions'] as num?)?.toInt() ?? 1;
                            }
                            return '$total';
                          }(),
                          label: 'Rešeni obroki',
                          color: kGreenMid,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day. $month. ${dt.year}';
  }

  Widget _buildOrgSliverAppBar() {
    // Organizacija: uvijek zeleni app bar s bijelim tekstom (kao normalni user ali bez gradienta)
    // Animacija se vidi pri prelasku, ali finalno stanje je jasno zeleno/bijelo
    const appBarBg = kGreenMid;
    const titleColor = Colors.white;
    const subtitleColor = Colors.white70;

    return SliverAppBar(
      expandedHeight: 110, pinned: true, elevation: 2,
      backgroundColor: appBarBg,
      foregroundColor: titleColor,
      shadowColor: Colors.black.withOpacity(0.2),
      surfaceTintColor: Colors.transparent, forceElevated: true,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
            ),
          ),
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Column(mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 6),
              const Text('Dobrodošli nazaj',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: titleColor, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              const Text('Upravljajte vaše oglase in doseg.',
                style: TextStyle(fontSize: 14, color: subtitleColor)),
            ]),
          )),
        ),
      ),
      title: Row(children: [
        Container(width: 26, height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), borderRadius: kRadius8),
          child: const Icon(Icons.eco, color: Colors.white, size: 15)),
        const SizedBox(width: 8),
        const Text('FoodWasteZero',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
            color: titleColor, letterSpacing: -0.2)),
        const SizedBox(width: 8),
        Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal:6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: kRadiusFull,
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.store_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text('Organizacija', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ]),
      ]),
      centerTitle: false,
      actions: [
        Padding(padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ni novih obvestil'))),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: kRadius12,
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
            ),
          )),
        Padding(padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => showAppDrawer(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: kRadius12,
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
            ),
          )),
      ],
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 110, pinned: true, elevation: 2,
      backgroundColor: const Color(0xFF2E7D32),
      shadowColor: Colors.black.withOpacity(0.2),
      surfaceTintColor: Colors.transparent, forceElevated: true,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
          )),
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Column(mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Reši hrano. Pomagaj skupnosti.',
                style: TextStyle(fontSize: 15, color: Colors.white70)),
            ]),
          )),
        ),
      ),
      title: Row(children: [
        Container(width: 26, height: 26,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2), borderRadius: kRadius8),
          child: const Icon(Icons.eco, color: Colors.white, size: 15)),
        const SizedBox(width: 8),
        const Text('FoodWasteZero',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: Colors.white, letterSpacing: -0.2)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showMestoDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: kRadiusFull,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_locationLoading)
                const SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Colors.white70),
                )
              else
                Icon(
                  _userLat != null ? Icons.my_location_rounded : Icons.location_on,
                  size: 11,
                  color: _userLat != null ? Colors.white : Colors.white70,
                ),
              const SizedBox(width: 3),
              Text(_mesto,
                style: const TextStyle(
                    fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 13, color: Colors.white70),
            ]),
          ),
        ),
      ]),
      centerTitle: false,
      actions: [
        Padding(padding: const EdgeInsets.only(right: 8),
          child: _NotifButton(onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ni novih obvestil'))))),
        Padding(padding: const EdgeInsets.only(right: 12),
          child: _HamburgerButton(onTap: () => showAppDrawer(context))),
      ],
    );
  }

  Widget _buildSearchBar() {
    return AnimatedBuilder(
      animation: _themeProgress,
      builder: (context, _) {
        final t = _themeProgress.value;
        // Org mode: bijela pozadina s malo prozirnosti umjesto skoro prozirne
        final bgColor = Color.lerp(Colors.white, Colors.white.withOpacity(0.92), t)!;
        final iconColor = Color.lerp(kGreenMid, kGreenMid, t)!;
        final textColor = Color.lerp(kTextDark, kTextDark, t)!;
        final hintColor = Color.lerp(kTextLight, kTextLight, t)!;
        final borderColor = Color.lerp(Colors.transparent, Colors.white.withOpacity(0.6), t)!;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: kRadius16,
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08 * (1 - t * 0.5)),
                  blurRadius: 24, offset: const Offset(0, 6)),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: TextStyle(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                hintText: 'Išči hrano v bližini...',
                hintStyle: TextStyle(fontSize: 14, color: hintColor),
                prefixIcon: Icon(Icons.search_rounded, color: iconColor, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.cancel_rounded, color: hintColor, size: 20))
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: InputBorder.none,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuestBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kGreenPale,
          borderRadius: kRadius12,
          border: Border.all(color: kGreenMid.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.visibility_outlined, color: kGreenMid, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Brskate kot gost. Oglase lahko pregledujete — za rezervacijo se prijavite.',
                style: TextStyle(fontSize: 13, color: kTextDark, height: 1.35),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _showAuthPopup,
              style: TextButton.styleFrom(
                foregroundColor: kGreenMid,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              child: const Text('Prijava',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child:IntrinsicHeight(
       child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
        Expanded(child: _QuickAction(
          icon: Icons.bolt_rounded, label: 'Kmalu poteče',
          color: const Color(0xFFE53935), active: _activeFilter == 'expiring',
          onTap: () => _setFilter('expiring'))),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(
          icon: _locationLoading ? Icons.hourglass_top_rounded : Icons.near_me_rounded,
          label: _locationLoading ? 'Pridobivam...' : 'Najbližje',
          color: const Color(0xFF0288D1),
          active: _activeFilter == 'nearest',
          loading: _locationLoading,
          onTap: () => _setFilter('nearest'))),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(
          icon: Icons.eco_rounded, label: 'Na voljo',
          color: kGreenMid, active: _activeFilter == 'available',
          onTap: () => _setFilter('available'))),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(
          icon: Icons.queue_rounded, label: 'Čakalna vrsta',
          color: const Color(0xFF5C6BC0), active: _activeFilter == 'reserved',
          onTap: () => _setFilter('reserved'))),
      ]),
      ),
    );
  }

  // Called from HeatmapFullPage when user taps "Podrobnosti" on a pin
  void _scrollToOglas(String oglasId) {
    // Close heatmap page first, then scroll
    Navigator.of(context).pop();
    final idx = _oglasIndexMap[oglasId];
    if (idx == null || !_listScrollCtrl.hasClients) return;
    // Approximate: appBar ~220, each card ~110px, sections above list ~300
    const sectionOffset = 380.0;
    const cardHeight = 115.0;
    final targetOffset = sectionOffset + idx * cardHeight;
    _listScrollCtrl.animateTo(
      targetOffset.clamp(0.0, _listScrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildHeatmapSection(List<FoodOglas> filtered) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            const Text('Toplotna karta', style: kHeading3),
          ]),
        ),
        HeatmapPreviewCard(onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => HeatmapFullPage(
            onScrollToOglas: _scrollToOglas,
            userLat: _userLat,
            userLng: _userLng,
          )))),
      ]),
    );
  }

  Widget _buildListingsHeader(int count) {
    return AnimatedBuilder(
      animation: _themeProgress,
      builder: (context, _) {
        final t = _themeProgress.value;
        final titleColor = Color.lerp(kTextDark, kTextDark, t)!; // ostaje tamno
        final countColor = Color.lerp(kGreenMid, kGreenMid, t)!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Oglasi v bližini', style: kHeading3.copyWith(color: titleColor)),
                if (_activeFilter != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _activeFilter = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: kGreenMid, borderRadius: kRadiusFull),
                      child: Row(children: [
                        Text(_filterLabel(_activeFilter!),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 3),
                        const Icon(Icons.close, color: Colors.white, size: 10),
                      ]),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text('$count rezultatov najdenih',
                style: kCaption.copyWith(
                    color: countColor, fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
          ]),
        );
      },
    );
  }

  String _filterLabel(String f) {
    switch (f) {
      case 'available': return 'Na voljo';
      case 'expiring':  return 'Kmalu poteče';
      case 'reserved':  return 'Čakalna vrsta';
      case 'nearest':   return 'Najbližje';
      default: return f;
    }
  }

  Widget _buildTabRow() {
    return AnimatedBuilder(
      animation: _themeProgress,
      builder: (context, _) {
        final t = _themeProgress.value;
        // Tab aktivni: zeleni → bijeli; neaktivni: bijeli → bijeli s vidljivim rubom
        final activeTabBg = Color.lerp(kGreenMid, Colors.white, t)!;
        final activeTabText = Color.lerp(Colors.white, kGreenMid, t)!;
        final inactiveTabBg = Color.lerp(Colors.white, Colors.white.withOpacity(0.88), t)!;
        final inactiveTabText = Color.lerp(kTextMid, kTextMid, t)!;
        final activeShadow = Color.lerp(kGreenMid, Colors.black, t * 0.4)!;

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final active = i == _selectedTab;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: active ? activeTabBg : inactiveTabBg,
                      borderRadius: kRadiusFull,
                      boxShadow: active
                          ? [BoxShadow(color: activeShadow.withOpacity(0.35),
                                blurRadius: 16, offset: const Offset(0, 5))]
                          : [BoxShadow(color: Colors.black.withOpacity(0.04 * (1 - t * 0.7)),
                                blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Text(_tabs[i], style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? activeTabText : inactiveTabText,
                    )),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFAB(double t) {
    // t=1 → organizacija: bijeli FAB sa zelenim tekstom
    final fabBg = Color.lerp(kGreenMid, Colors.white, t)!;
    final fabFg = Color.lerp(Colors.white, kGreenMid, t)!;
    final shadowColor = Color.lerp(kGreenMid, Colors.black, t * 0.5)!;
    return Container(
      decoration: BoxDecoration(borderRadius: kRadius16, boxShadow: [
        BoxShadow(color: shadowColor.withOpacity(0.4),
            blurRadius: 28, offset: const Offset(0, 10)),
      ]),
      child: FloatingActionButton.extended(
        onPressed: _showAddOglas,
        backgroundColor: fabBg, elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: kRadius16),
        icon: Icon(Icons.add_rounded, color: fabFg, size: 22),
        label: Text('Dodaj oglas',
          style: TextStyle(color: fabFg, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  List<NavigationDestination> _navDestinations(bool isGuest, Color selected, Color unselected) {
    return [
      NavigationDestination(
        icon: Icon(Icons.home_outlined, color: unselected),
        selectedIcon: Icon(Icons.home_rounded, color: selected),
        label: 'Domov',
      ),
      if (!_isDavatelj)
        NavigationDestination(
          icon: Icon(Icons.restaurant_rounded, color: unselected),
          selectedIcon: Icon(Icons.restaurant_rounded, color: selected),
          label: 'Recepti',
        ),
      NavigationDestination(
        icon: Icon(Icons.inbox_outlined, color: unselected),
        selectedIcon: Icon(Icons.inbox_rounded, color: selected),
        label: 'Moje objave',
      ),
      NavigationDestination(
        icon: Icon(isGuest ? Icons.login_rounded : Icons.person_outline_rounded, color: unselected),
        selectedIcon: Icon(
          isGuest ? Icons.login_rounded : Icons.person_rounded,
          color: selected,
        ),
        label: isGuest ? 'Prijava' : 'Profil',
      ),
    ];
  }

  Widget _buildBottomNav({
    required Color navBg,
    required Color navIndicator,
    required Color navSelectedIcon,
    required Color navUnselectedIcon,
  }) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final isGuest = isAppGuest(authSnap.data);
        final destinations = _navDestinations(isGuest, navSelectedIcon, navUnselectedIcon);
        return Container(
          decoration: BoxDecoration(
            color: navBg,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15),
                  blurRadius: 30, offset: const Offset(0, -6)),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final isSelected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? navSelectedIcon : navUnselectedIcon,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _navIndex.clamp(0, destinations.length - 1),
              onDestinationSelected: (i) {
                if (isGuest && _authRequiredNavIndices().contains(i)) {
                  _showAuthPopup();
                  return;
                }
                setState(() => _navIndex = i);
              },
              backgroundColor: Colors.transparent, elevation: 0,
              indicatorColor: navIndicator,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: destinations,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrgStatsRow(int available, int expiring, int reserved) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => _setFilter('available'),
          child: _OrgStatCard(
            icon: Icons.eco_rounded, value: '$available', label: 'Aktivni oglasi',
            color: kGreenMid, active: _activeFilter == 'available',
          ))),
        const SizedBox(width: 10),
        Expanded(child: GestureDetector(
          onTap: () => _setFilter('expiring'),
          child: _OrgStatCard(
            icon: Icons.bolt_rounded, value: '$expiring', label: 'Poteče kmalu',
            color: kOrange, active: _activeFilter == 'expiring',
          ))),
        const SizedBox(width: 10),
        Expanded(child: GestureDetector(
          onTap: () => _setFilter('reserved'),
          child: _OrgStatCard(
            icon: Icons.queue_rounded, value: '$reserved', label: 'Rezervirano',
            color: const Color(0xFF5C6BC0), active: _activeFilter == 'reserved',
          ))),
      ]),
    );
  }

  Widget _buildOrgQuickActions() {
     return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child:IntrinsicHeight(
       child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
        Expanded(child: _QuickAction(
          icon: Icons.bolt_rounded, label: 'Kmalu poteče',
          color: const Color(0xFFE53935), active: _activeFilter == 'expiring',
          onTap: () => _setFilter('expiring'))),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(
          icon: Icons.near_me_rounded, label: 'Najbližje',
          color: const Color(0xFF0288D1), active: _activeFilter == 'nearest',
          onTap: () => _setFilter('nearest'))),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(
          icon: Icons.eco_rounded, label: 'Na voljo',
          color: kGreenMid, active: _activeFilter == 'available',
          onTap: () => _setFilter('available'))),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(
          icon: Icons.queue_rounded, label: 'Čakalna vrsta',
          color: const Color(0xFF5C6BC0), active: _activeFilter == 'reserved',
          onTap: () => _setFilter('reserved'))),
      ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Davatelj dashboard pomožni razredi
// ─────────────────────────────────────────────────────────────────────────────

/// Model za prihodnji prevzem
class _UpcomingPickup {
  final FoodOglas oglas;
  final DateTime termin;
  const _UpcomingPickup({required this.oglas, required this.termin});
}

/// Kartica z današnjo statistiko za davatelja
class _DavateljStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color bgColor;

  const _DavateljStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: kRadius12,
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: kRadius8,
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: kTextLight, height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// Vrstica prihodnjega prevzema v seznamu
class _UpcomingPickupTile extends StatelessWidget {
  final _UpcomingPickup pickup;
  final VoidCallback onTap;

  const _UpcomingPickupTile({required this.pickup, required this.onTap});

  String _formatTermin(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final day = DateTime(dt.year, dt.month, dt.day);
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$min';

    if (day == today) return 'Danes ob $timeStr';
    if (day == tomorrow) return 'Jutri ob $timeStr';
    return '${dt.day}.${dt.month}. ob $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final oglas = pickup.oglas;
    final hasPrice = (oglas.price ?? 0) > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ikona kategorije
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: oglas.imageColor,
                borderRadius: kRadius8,
              ),
              child: Icon(oglas.icon, color: kGreenMid, size: 20),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    oglas.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.schedule_rounded,
                        size: 12, color: kTextLight),
                    const SizedBox(width: 3),
                    Text(
                      _formatTermin(pickup.termin),
                      style: const TextStyle(fontSize: 12, color: kTextLight),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Cena / brezplačno + status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasPrice
                        ? const Color(0xFFE0F2F1)
                        : kGreenPale,
                    borderRadius: kRadiusFull,
                  ),
                  child: Text(
                    hasPrice
                        ? '${oglas.price!.toStringAsFixed(2)} €'
                        : 'Brezplačno',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasPrice
                          ? const Color(0xFF00897B)
                          : kGreenMid,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (oglas.status == OglasStatus.rezervirano)
                  const Text(
                    'Rezervirano',
                    style: TextStyle(
                      fontSize: 11,
                      color: kOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  const Text(
                    'Na voljo',
                    style: TextStyle(
                      fontSize: 11,
                      color: kGreenMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: kTextLight, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Skupna vrednost v tedenskem grafu
class _WeekSummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _WeekSummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: kTextLight),
      ),
    ]);
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  final VoidCallback onTap; final bool active; final bool loading;
  const _QuickAction({required this.icon, required this.label,
    required this.color, required this.onTap, this.active = false,
    this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: kRadius12,
          boxShadow: [
            BoxShadow(color: color.withOpacity(active ? 0.35 : 0.12),
              blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.max, children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: active ? Colors.white.withOpacity(0.25) : color.withOpacity(0.12),
              borderRadius: kRadius8),
            child: loading
              ? Padding(
                  padding: const EdgeInsets.all(9),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: active ? Colors.white : color,
                  ))
              : Icon(icon, color: active ? Colors.white : color, size: 18)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.white : color),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _NotifButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _NotifButton({this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 38, height: 38,
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18), borderRadius: kRadius12,
          border: Border.all(color: Colors.white.withOpacity(0.25))),
      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20)));
}

class _AvatarButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool dark;
  const _AvatarButton({this.onTap, this.dark = false});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final initials = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName![0].toUpperCase() : 'U';
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 19,
        backgroundColor: dark ? kGreenPale : Colors.white,
        child: Text(initials,
          style: const TextStyle(fontWeight: FontWeight.w900, color: kGreenMid, fontSize: 16))));
  }
}

class _HamburgerButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool dark;
  const _HamburgerButton({this.onTap, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: dark ? kGreenPale : Colors.white.withOpacity(0.2),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: dark ? kGreenMid.withOpacity(0.2) : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Icon(
          Icons.menu_rounded,
          color: dark ? kGreenMid : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _OrgStatCard extends StatelessWidget {
  final IconData icon; final String value, label;
  final Color color; final bool active;
  const _OrgStatCard({required this.icon, required this.value, required this.label,
    required this.color, this.active = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 13),
      decoration: BoxDecoration(
        color: active ? color : color.withOpacity(0.08),
        borderRadius: kRadius12,
        border: Border.all(color: color.withOpacity(active ? 0 : 0.25), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(active ? 0.35 : 0.10),
            blurRadius: 18, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(
            color: active ? Colors.white.withOpacity(0.25) : color.withOpacity(0.15),
            borderRadius: kRadius8),
          child: Icon(icon, size: 17, color: active ? Colors.white : color)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
            color: active ? Colors.white : color)),
          Text(label, style: kCaption.copyWith(
            fontSize: 14, color: active ? Colors.white70 : color.withOpacity(0.8)),
            overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

class _OrgQuickAction extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final bool active;
  final VoidCallback onTap;
  const _OrgQuickAction({required this.icon, required this.label,
    required this.color, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: kRadius12,
          border: Border.all(color: active ? color : kBorder, width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(active ? 0.3 : 0.06),
              blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? Colors.white : color, size: 22),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: active ? Colors.white : color),
            textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon; final String value, label;
  final Color iconColor, bgColor; final bool active;
  const _StatCard({required this.icon, required this.value, required this.label,
    required this.iconColor, required this.bgColor, this.active = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 13),
      decoration: BoxDecoration(
        color: active ? iconColor : Colors.white,
        borderRadius: kRadius12,
        boxShadow: [BoxShadow(color: iconColor.withOpacity(active ? 0.4 : 0.12),
            blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(
            color: active ? Colors.white.withOpacity(0.25) : bgColor,
            borderRadius: kRadius8),
          child: Icon(icon, size: 17, color: active ? Colors.white : iconColor)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
            color: active ? Colors.white : iconColor)),
          Text(label, style: kCaption.copyWith(
            fontSize: 14, color: active ? Colors.white70 : null),
            overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
          child: const Icon(Icons.search_off_rounded, size: 44, color: kGreenMid)),
        const SizedBox(height: 18),
        const Text('Ni zadetkov', style: kHeading3),
        const SizedBox(height: 6),
        const Text('V tej kategoriji ni oglasov.', style: kBody, textAlign: TextAlign.center),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════════
// HEATMAP — bere prave lat/lng koordinate iz Firestorea
// ══════════════════════════════════════════════════════════════════════════════

// Referenčna točka za Maribor (center mesta)
const _kRefLat = 46.5547;
const _kRefLng = 15.6450;
// Območje prikaza ±km
const _kViewKm = 8.0; // Pokriva cijeli Maribor ±8km od centra

// Pretvori geo koordinate v relativne [0,1] pozicije na canvasu
// HotspotData: (relX, relY, intensity, title, id, description, status)
typedef HotspotData = (double, double, double, String, String, String, String);

(double rx, double ry) _geoToRelative(double lat, double lng,
    {double refLat = _kRefLat, double refLng = _kRefLng}) {
  // 1 lat degree = 111km; 1 lng degree = 111 * cos(lat) km
  const kmPerLat = 111.0;
  final kmPerLng = 111.0 * cos(_kRefLat * pi / 180); // ~76km pri lat 46.5
  final dxKm = (lng - refLng) * kmPerLng;
  final dyKm = (lat - refLat) * kmPerLat;
  // Referenčna točka = centar mape (0.5, 0.5); ±_kViewKm = rub mape
  final rx = 0.5 + dxKm / (_kViewKm * 2);
  final ry = 0.5 - dyKm / (_kViewKm * 2); // Y invertiran (lat gore = ekran gore)
  return (rx.clamp(0.02, 0.98), ry.clamp(0.02, 0.98));
}

// Fallback točke (prikazane dokler se Firestore ne naloži)
// Fallback hotspoti razpoređeni oko centra (0.5, 0.5)
const _kFallbackHs = [
  (0.40, 0.45, 3.0, 'Vzorčni oglas', '', '', 'naRazpolago'),
  (0.55, 0.40, 2.5, 'Vzorčni oglas', '', '', 'naRazpolago'),
  (0.60, 0.55, 4.0, 'Vzorčni oglas', '', '', 'naRazpolago'),
  (0.45, 0.60, 2.0, 'Vzorčni oglas', '', '', 'naRazpolago'),
  (0.65, 0.45, 3.5, 'Vzorčni oglas', '', '', 'naRazpolago'),
  (0.35, 0.55, 2.0, 'Vzorčni oglas', '', '', 'naRazpolago'),
];

// ── Preview kartica (na home screenu) ─────────────────────────────────────────
class HeatmapPreviewCard extends StatelessWidget {
  final VoidCallback? onTap;
  final double? userLat;
  final double? userLng;
  const HeatmapPreviewCard({super.key, this.onTap, this.userLat, this.userLng});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 170,
        decoration: BoxDecoration(borderRadius: kRadius16, boxShadow: [
          BoxShadow(color: const Color(0xFF1B5E20).withOpacity(0.3),
              blurRadius: 28, offset: const Offset(0, 8)),
        ]),
        child: ClipRRect(
          borderRadius: kRadius16,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('oglasi')
                .where('status', isEqualTo: 'naRazpolago')
                .snapshots(),
            builder: (_, snap) {
              final refLat = userLat ?? _kRefLat;
              final refLng = userLng ?? _kRefLng;
              final hotspots = _extractHotspots(snap.data?.docs, refLat: refLat, refLng: refLng);
              final count = snap.data?.docs.length ?? 0;
              return Stack(fit: StackFit.expand, children: [
                const _MapBackground(),
                _LiveHeatmapCanvas(hotspots: hotspots, preview: true),
                // Gradient overlay
                Container(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                  stops: const [0.3, 1.0]))),
                // Labels
                Positioned(left: 16, bottom: 16, right: 60, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: kGreenAccent, borderRadius: kRadiusFull),
                      child: const Text('LIVE', style: TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
                    const SizedBox(width: 8),
                    const Flexible(child: Text('Toplotna karta hrane',
                      style: TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 4),
                  Text('$count aktivnih oglasov',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                ])),
                Positioned(right: 14, bottom: 14, child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: kRadiusFull,
                    border: Border.all(color: Colors.white.withOpacity(0.5))),
                  child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16))),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

// ── Polna stran heatmape ───────────────────────────────────────────────────────
class HeatmapFullPage extends StatefulWidget {
  final void Function(String oglasId)? onScrollToOglas;
  final double? userLat;
  final double? userLng;
  const HeatmapFullPage({super.key, this.onScrollToOglas, this.userLat, this.userLng});
  @override State<HeatmapFullPage> createState() => _HeatmapFullPageState();
}

class _HeatmapFullPageState extends State<HeatmapFullPage> {
  String _filter = 'Vsi';
  bool _showLabels = false;
  bool _panelExpanded = false;
  HotspotData? _selectedHotspot;

  static const _filters = ['Vsi', 'Prosti', 'Rezervirani'];
  static const _filterValues = ['Vsi', 'naRazpolago', 'rezervirano'];

  // Fiksna višina bottom panela — ne narašča
  static const _panelCollapsed = 200.0;
  static const _panelExpanded2 = 320.0;

  // Zoom / pan — GestureDetector based
  double _scale = 1.0;
  double _prevScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _prevOffset = Offset.zero;
  Offset _focalPointStart = Offset.zero;
  Size _mapSize = Size.zero;

  static const _minScale = 1.0;
  static const _maxScale = 5.0;

  double get _currentScale => _scale;

  Offset _clampOffset(Offset o, double s, Size size) {
    if (size == Size.zero) return Offset.zero;
    final maxX = size.width * (s - 1);
    final maxY = size.height * (s - 1);
    return Offset(
      o.dx.clamp(-maxX, 0.0),
      o.dy.clamp(-maxY, 0.0),
    );
  }

  void _zoomButton(double factor) {
    final next = (_scale * factor).clamp(_minScale, _maxScale);
    if (next == _scale) return;
    final cx = _mapSize.width / 2;
    final cy = _mapSize.height / 2;
    final ratio = next / _scale;
    final newOffset = Offset(
      cx - (cx - _offset.dx) * ratio,
      cy - (cy - _offset.dy) * ratio,
    );
    setState(() {
      _scale = next;
      _offset = _clampOffset(newOffset, next, _mapSize);
    });
  }

  void _resetZoom() => setState(() { _scale = 1.0; _offset = Offset.zero; });

  // Centrira mapu na korisnikovu GPS lokaciju s blagim zoom-om
  // Polling timer — kad korisnik uključi GPS čekamo i primamo lokaciju
  Timer? _locationPollTimer;

  Future<void> _centerOnUser() async {
    // Provjeri je li GPS uopće dostupan na uređaju
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      _showLocationAlert();
      return;
    }

    // Provjeri dozvolu
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      _showLocationAlert();
      return;
    }

    // Ima dozvolu ali možda još nema koordinata u widgetu — uzmi direktno
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      // Obavijesti parenta da ažurira koordinate (ako je moguće)
      // i odmah centriraj na dobivenu poziciju
      _doCenterOnPos(pos.latitude, pos.longitude);
    } catch (_) {
      // Fallback na widget.userLat ako getCurrentPosition ne uspije
      if (widget.userLat != null && mounted) {
        _doCenterOnPos(widget.userLat!, widget.userLng!);
      }
    }
  }

  void _doCenterOnPos(double lat, double lng) {
    if (_mapSize == Size.zero) return;
    // Izračunaj relativnu poziciju korisnika na mapi
    final refLat = widget.userLat ?? _kRefLat;
    final refLng = widget.userLng ?? _kRefLng;
    final (rx, ry) = _geoToRelative(lat, lng, refLat: refLat, refLng: refLng);
    const targetScale = 2.5;
    // Pomakni mapu tako da je korisnikov pin na centru ekrana
    final offsetX = _mapSize.width  * (0.5 - rx) * targetScale;
    final offsetY = _mapSize.height * (0.5 - ry) * targetScale;
    setState(() {
      _scale = targetScale;
      _offset = _clampOffset(Offset(offsetX, offsetY), targetScale, _mapSize);
    });
  }

  void _showLocationAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A28),
        shape: RoundedRectangleBorder(borderRadius: kRadius16),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.15),
              borderRadius: kRadius12,
            ),
            child: const Icon(Icons.location_off_rounded,
                color: Color(0xFF2196F3), size: 22),
          ),
          const SizedBox(width: 12),
          const Text('Lokacija izključena',
              style: TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'Prosim vključi lokacijo v nastavitvah naprave, nato se vrni v aplikacijo.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Prekliči',
                style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startLocationPolling();
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3).withOpacity(0.15),
              shape: RoundedRectangleBorder(borderRadius: kRadius12),
            ),
            child: const Text('Vključil sem',
                style: TextStyle(color: Color(0xFF2196F3),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // Polira GPS svakih 2s čim korisnik kaže da je uključio
  void _startLocationPolling() {
    _locationPollTimer?.cancel();
    _locationPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        _locationPollTimer?.cancel();
        _locationPollTimer = null;
        if (!mounted) return;
        // Trigger rebuild s novom lokacijom pa centriraj
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) _doCenterOnPos(pos.latitude, pos.longitude);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _locationPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final safeTop = mq.padding.top;
    // Koliko prostora ostane za mapu (oduzimamo top bar ~110 + bottom panel)
    final panelH = _panelExpanded ? _panelExpanded2 : _panelCollapsed;
    final topBarH = safeTop + 110.0;
    final mapH = screenH - topBarH - panelH;

    return Scaffold(
      backgroundColor: const Color(0xFF0F2318),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('oglasi').snapshots(),
        builder: (_, snap) {
          final allDocs = snap.data?.docs ?? [];
          final filtered = _filter == 'Vsi'
              ? allDocs
              : allDocs
                  .where((d) =>
                      (d.data() as Map)['status'] ==
                      _filterValues[_filters.indexOf(_filter)])
                  .toList();

          final hotspots = _extractHotspots(filtered,
              refLat: widget.userLat ?? _kRefLat,
              refLng: widget.userLng ?? _kRefLng);
          final activeCount = allDocs
              .where((d) => (d.data() as Map)['status'] == 'naRazpolago')
              .length;
          final reservedCount = allDocs
              .where((d) => (d.data() as Map)['status'] == 'rezervirano')
              .length;
          final prevzetoCount =
              allDocs.length - activeCount - reservedCount;

          return Column(
            children: [
              // ── TOP BAR (fiksna višina) ──────────────────────────────────
              Container(
                color: const Color(0xFF0F2318),
                padding: EdgeInsets.only(top: safeTop),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Naslov row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: kRadius12,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2))),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 20)),
                        ),
                        const SizedBox(width: 12),
                        const Text('Toplotna karta',
                          style: TextStyle(color: Colors.white,
                            fontSize: 18, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        // LIVE badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kGreenAccent.withOpacity(0.9),
                            borderRadius: kRadiusFull),
                          child: Row(children: [
                            Container(width: 7, height: 7,
                              decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text('${allDocs.length} LIVE',
                              style: const TextStyle(color: Colors.white,
                                fontSize: 12, fontWeight: FontWeight.w800)),
                          ])),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    // Filter chips
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ..._filters.map((f) => GestureDetector(
                            onTap: () => setState(() => _filter = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: _filter == f
                                    ? kGreenAccent
                                    : Colors.white.withOpacity(0.12),
                                borderRadius: kRadiusFull,
                                border: Border.all(
                                  color: _filter == f
                                      ? kGreenAccent
                                      : Colors.white.withOpacity(0.2))),
                              child: Text(f,
                                style: TextStyle(
                                  color: _filter == f
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600))))),
                          // Toggle nazivi
                          GestureDetector(
                            onTap: () =>
                                setState(() => _showLabels = !_showLabels),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: _showLabels
                                    ? Colors.white.withOpacity(0.22)
                                    : Colors.white.withOpacity(0.08),
                                borderRadius: kRadiusFull,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.2))),
                              child: Row(children: [
                                Icon(Icons.label_outline_rounded,
                                  color: _showLabels
                                      ? Colors.white
                                      : Colors.white54,
                                  size: 14),
                                const SizedBox(width: 4),
                                Text('Nazivi',
                                  style: TextStyle(
                                    color: _showLabels
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                              ]))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),

              // ── MAPA (flex — zapolni preostali prostor) ──────────────────
              Expanded(
                child: LayoutBuilder(builder: (_, constraints) {
                  // Zapamti veličinu mape za zoom/pan računanje
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_mapSize != constraints.biggest) {
                      _mapSize = constraints.biggest;
                    }
                  });
                  _mapSize = constraints.biggest;
                  final mapW = constraints.maxWidth;
                  final mapH = constraints.maxHeight;

                  return GestureDetector(
                    // Pan
                    onScaleStart: (d) {
                      _prevScale = _scale;
                      _prevOffset = _offset;
                      _focalPointStart = d.localFocalPoint;
                    },
                    onScaleUpdate: (d) {
                      setState(() {
                        // Zoom
                        final newScale = (_prevScale * d.scale).clamp(_minScale, _maxScale);
                        // Pan — pomakni za razliku focalPointa
                        final panDelta = d.localFocalPoint - _focalPointStart;
                        // Focal point u koordinatama scene
                        final focalScene = (_focalPointStart - _prevOffset) / _prevScale;
                        final newOffset = d.localFocalPoint - focalScene * newScale;
                        _scale = newScale;
                        _offset = _clampOffset(newOffset, newScale, Size(mapW, mapH));
                      });
                    },
                    onScaleEnd: (_) {
                      _prevScale = _scale;
                      _prevOffset = _offset;
                    },
                    // Tap na prazan prostor → dismiss popup
                    onTap: _selectedHotspot != null
                        ? () => setState(() => _selectedHotspot = null)
                        : null,
                    child: ClipRect(
                      child: Stack(
                        children: [
                          // Transformirana mapa
                          Transform(
                            transform: Matrix4.identity()
                              ..translate(_offset.dx, _offset.dy)
                              ..scale(_scale),
                            child: SizedBox(
                              width: mapW,
                              height: mapH,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Pozadina
                                  Builder(builder: (_) {
                                    double? uRelX, uRelY;
                                    if (widget.userLat != null && widget.userLng != null) {
                                      uRelX = 0.5; uRelY = 0.5;
                                    }
                                    return _MapBackground(dark: true, userRelX: uRelX, userRelY: uRelY);
                                  }),
                                  // Heatmap canvas + tap točke
                                  _LiveHeatmapCanvas(
                                    hotspots: hotspots,
                                    preview: false,
                                    showLabels: _showLabels,
                                    selectedId: _selectedHotspot?.$5,
                                    scale: _scale,
                                    onHotspotTap: (hs) => setState(() =>
                                        _selectedHotspot = _selectedHotspot?.$5 == hs.$5 ? null : hs),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Zoom gumbi (ne transformiraju se)
                          Positioned(
                            right: 12,
                            top: 12,
                            child: Column(children: [
                              _ZoomButton(
                                icon: Icons.add_rounded,
                                onTap: () => _zoomButton(1.4),
                                enabled: _scale < _maxScale - 0.05,
                              ),
                              const SizedBox(height: 6),
                              _ZoomButton(
                                icon: Icons.remove_rounded,
                                onTap: () => _zoomButton(1 / 1.4),
                                enabled: _scale > _minScale + 0.05,
                              ),
                              const SizedBox(height: 6),
                              _ZoomButton(
                                icon: Icons.center_focus_strong_rounded,
                                onTap: _resetZoom,
                                enabled: _scale > _minScale + 0.05,
                              ),
                              const SizedBox(height: 6),
                              // 4. gumb — moja lokacija (plava boja)
                              _ZoomButton(
                                icon: Icons.my_location_rounded,
                                onTap: () => _centerOnUser(),
                                enabled: true, // uvijek klikabilan — prikaže alert ako GPS isključen
                                activeColor: const Color(0xFF2196F3),
                              ),
                            ]),
                          ),

                          // Mini popup — izvan transformacije, uvijek pri dnu
                          if (_selectedHotspot != null)
                            _HotspotPopup(
                              hotspot: _selectedHotspot!,
                              onClose: () => setState(() => _selectedHotspot = null),
                              onDetails: widget.onScrollToOglas != null
                                  ? () => widget.onScrollToOglas!(_selectedHotspot!.$5)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),

              // ── BOTTOM PANEL (fiksna višina, ne overlaya) ────────────────
              GestureDetector(
                onTap: () =>
                    setState(() => _panelExpanded = !_panelExpanded),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                  padding: EdgeInsets.fromLTRB(
                      20, 14, 20, mq.padding.bottom + 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle + toggle indikator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 36, height: 4,
                            decoration: BoxDecoration(
                                color: kBorder, borderRadius: kRadiusFull)),
                          const SizedBox(width: 8),
                          Icon(
                            _panelExpanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            color: kTextLight, size: 18),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Stat kartice (vedno vidne) ──────────────────────
                      Row(children: [
                        _HeatStat(value: '${allDocs.length}',
                            label: 'Skupaj', color: kTextDark),
                        const SizedBox(width: 8),
                        _HeatStat(value: '$activeCount',
                            label: 'Prosti', color: kGreenMid),
                        const SizedBox(width: 8),
                        _HeatStat(value: '$reservedCount',
                            label: 'Rezervirani', color: kOrange),
                        const SizedBox(width: 8),
                        _HeatStat(value: '$prevzetoCount',
                            label: 'Prevzeto',
                            color: const Color(0xFF1565C0)),
                      ]),

                      // ── Razširjeni del ───────────────────────────────────
                      if (_panelExpanded) ...[
                        const SizedBox(height: 14),
                        const Divider(color: kBorder, height: 1),
                        const SizedBox(height: 14),
                        Row(children: [
                          _LegendDot(color: kGreenAccent,
                              label: 'Visoka gostota'),
                          const SizedBox(width: 14),
                          _LegendDot(
                              color: kGreenLight.withOpacity(0.6),
                              label: 'Srednja'),
                          const SizedBox(width: 14),
                          _LegendDot(
                              color: kGreenLight.withOpacity(0.25),
                              label: 'Nizka'),
                        ]),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                                Icons.my_location_rounded, size: 16),
                            label: const Text('Pokaži bližnje oglase'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kGreenMid,
                              side: const BorderSide(
                                  color: kGreenMid, width: 1.5),
                              shape: const RoundedRectangleBorder(
                                  borderRadius: kRadius12),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13)),
                          )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveHeatmapCanvas extends StatefulWidget {
  final List<HotspotData> hotspots;
  final bool preview;
  final bool showLabels;
  final String? selectedId;
  final void Function(HotspotData)? onHotspotTap;
  final double scale;

  const _LiveHeatmapCanvas({
    required this.hotspots,
    required this.preview,
    this.showLabels = false,
    this.selectedId,
    this.onHotspotTap,
    this.scale = 1.0,
  });

  @override
  State<_LiveHeatmapCanvas> createState() => _LiveHeatmapCanvasState();
}

class _LiveHeatmapCanvasState extends State<_LiveHeatmapCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _p;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _p = Tween<double>(begin: 0.75, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _p,
      builder: (_, __) {
        final pts = widget.hotspots.isEmpty
            ? _kFallbackHs.toList()
            : widget.hotspots;

        return LayoutBuilder(builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: [
              // Heatmap blobs (painter — bez točaka)
              CustomPaint(
                painter: _LiveHeatmapPainter(
                  hotspots: pts,
                  pulse: _p.value,
                  preview: widget.preview,
                  showLabels: widget.showLabels,
                  selectedId: widget.selectedId,
                ),
                child: Container(color: Colors.transparent),
              ),
              // Tappable dot overlays (samo na full page)
              if (!widget.preview)
                for (final hs in pts)
                  if (hs.$5.isNotEmpty) // samo pravi Firestore artikli (imaju id)
                    _buildTapDot(hs, w, h),
            ],
          );
        });
      },
    );
  }

  Widget _buildTapDot(HotspotData hs, double w, double h) {
    final cx = hs.$1 * w;
    final cy = hs.$2 * h;
    final isSelected = widget.selectedId == hs.$5;
    // Scale the hit area inversely with zoom so it stays easy to tap
    final scale = widget.scale;
    final hitSize = (36.0 / scale).clamp(24.0, 48.0);
    return Positioned(
      left: cx - hitSize / 2,
      top: cy - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: GestureDetector(
        onTap: () => widget.onHotspotTap?.call(hs),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: isSelected
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
        ),
      ),
    );
  }
}


class _LiveHeatmapPainter extends CustomPainter {
  final List<HotspotData> hotspots;
  final double pulse;
  final bool preview;
  final bool showLabels;
  final String? selectedId;

  _LiveHeatmapPainter({
    required this.hotspots,
    required this.pulse,
    required this.preview,
    required this.showLabels,
    this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pts = hotspots.isEmpty
        ? _kFallbackHs
        : hotspots;

    for (final hs in pts) {
      final rx = hs.$1; final ry = hs.$2;
      final intensity = hs.$3; final title = hs.$4;
      final id = hs.$5;
      final cx = rx * size.width;
      final cy = ry * size.height;
      final baseR = (preview ? 16.0 : 28.0) * intensity.clamp(0.5, 5.0) / 3.0;

      // Heatmap blob — 4 sloji radijalnog gradienta
      for (int i = 3; i >= 0; i--) {
        final r = baseR * (1.0 + i * 0.6) * pulse;
        final opacity = 0.07 * (4 - i) * pulse;
        final paint = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF4CAF50).withOpacity(opacity + 0.04),
              const Color(0xFF81C784).withOpacity(opacity * 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
        canvas.drawCircle(Offset(cx, cy), r, paint);
      }

      final isSelected = id.isNotEmpty && id == selectedId;

      // Selected ring
      if (isSelected) {
        canvas.drawCircle(
            Offset(cx, cy), 12 * pulse,
            Paint()
              ..color = Colors.white.withOpacity(0.35 * pulse)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }

      // Centralna točka
      final dotR = preview ? 4.0 : 5.5;
      canvas.drawCircle(
          Offset(cx, cy), dotR + 2,
          Paint()..color = Colors.black.withOpacity(0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(
          Offset(cx, cy), dotR,
          Paint()..color = (isSelected ? Colors.white : kGreenAccent).withOpacity(0.9 * pulse));
      canvas.drawCircle(
          Offset(cx, cy), dotR * 0.4,
          Paint()..color = Colors.white.withOpacity(0.8));

      // Naziv oglasa (samo na full page)
      if (!preview && showLabels && title.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: title.length > 14 ? '${title.substring(0, 12)}…' : title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 80);
        tp.paint(canvas, Offset(cx - tp.width / 2, cy + dotR + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_LiveHeatmapPainter o) =>
      o.pulse != pulse || o.hotspots != hotspots || 
      o.showLabels != showLabels || o.selectedId != selectedId;
}

// ── Helper: iz Firestore docs izvuci hotspots ──────────────────────────────────
List<HotspotData> _extractHotspots(
    List<QueryDocumentSnapshot>? docs,
    {double refLat = _kRefLat, double refLng = _kRefLng}) {
  if (docs == null || docs.isEmpty) return [];
  final result = <HotspotData>[];
  for (final doc in docs) {
    final d = doc.data() as Map<String, dynamic>;
    final lat = (d['lat'] as num?)?.toDouble();
    final lng = (d['lng'] as num?)?.toDouble();
    final title = d['title'] as String? ?? '';
    final description = d['description'] as String? ?? '';
    final status = d['status'] as String? ?? 'naRazpolago';
    if (lat == null || lng == null) continue;
    final (rx, ry) = _geoToRelative(lat, lng, refLat: refLat, refLng: refLng);
    // Intenzitet ovisi o statusu: prosti = 3, rezervirani = 2, prevzeti = 1
    final intensity = status == 'naRazpolago'
        ? 3.0
        : status == 'rezervirano'
            ? 2.0
            : 1.0;
    result.add((rx, ry, intensity, title, doc.id, description, status));
  }
  return result;
}

// ── Pozadinska mapa (grid + ceste) ────────────────────────────────────────────
class _MapBackground extends StatelessWidget {
  final bool dark;
  final double? userRelX; // relativna pozicija korisnika [0,1]
  final double? userRelY;
  const _MapBackground({this.dark = false, this.userRelX, this.userRelY});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _MapGridPainter(dark: dark, userRelX: userRelX, userRelY: userRelY),
        child: Container(
            color: dark ? const Color(0xFF0F2318) : const Color(0xFF1A3A2A)),
      );
}

class _MapGridPainter extends CustomPainter {
  final bool dark;
  final double? userRelX;
  final double? userRelY;
  const _MapGridPainter({this.dark = false, this.userRelX, this.userRelY});

  @override
  void paint(Canvas canvas, Size size) {
    final gridColor =
        dark ? const Color(0xFF1A3A28) : const Color(0xFF2A4A3A);
    final roadColor =
        dark ? const Color(0xFF2A5038) : const Color(0xFF3A5A4A);

    final gp = Paint()..color = gridColor..strokeWidth = 0.8;
    final step = dark ? 35.0 : 22.0;
    for (double y = 0; y < size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    for (double x = 0; x < size.width; x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);

    // Glavne ceste Maribora — prilagođeno novoj projekciji (center=0.5,0.5)
    // Drava teče W→E kroz centar (~y=0.52), Partizanska je glavna H cesta (~y=0.48)
    final rp = Paint()
      ..color = roadColor
      ..strokeWidth = dark ? 4.5 : 3.0
      ..strokeCap = StrokeCap.round;

    // Partizanska / Koroška (glavna H os kroz centar)
    canvas.drawLine(
        Offset(0, size.height * 0.48), Offset(size.width, size.height * 0.48), rp);
    // Tyrševa / Ob Dravi (vzporedna sjeverno)
    canvas.drawLine(
        Offset(0, size.height * 0.38), Offset(size.width * 0.75, size.height * 0.38), rp);
    // Cesta Pobrežje (južno)
    canvas.drawLine(
        Offset(0, size.height * 0.62), Offset(size.width, size.height * 0.62), rp);

    // Ul. heroja Staneta / Gosposvetska (V os — malo lijevo od centra)
    canvas.drawLine(
        Offset(size.width * 0.46, 0), Offset(size.width * 0.46, size.height), rp);
    // Ul. Vita Kraigherja (V os desno)
    canvas.drawLine(
        Offset(size.width * 0.58, 0), Offset(size.width * 0.58, size.height), rp);
    // Cesta prema Limbuš (Z rub)
    canvas.drawLine(
        Offset(size.width * 0.25, size.height * 0.3),
        Offset(size.width * 0.25, size.height * 0.75), rp);
    // Cesta prema Ruše (I rub)
    canvas.drawLine(
        Offset(size.width * 0.78, size.height * 0.25),
        Offset(size.width * 0.78, size.height * 0.75), rp);

    // Reka Drava — teče W→E malo ispod centra (~y=0.52-0.54)
    final riverP = Paint()
      ..color = const Color(0xFF1565C0).withOpacity(0.45)
      ..strokeWidth = dark ? 9.0 : 6.0
      ..strokeCap = StrokeCap.round;
    final riverPath = Path()
      ..moveTo(0, size.height * 0.54)
      ..cubicTo(
          size.width * 0.20, size.height * 0.52,
          size.width * 0.40, size.height * 0.55,
          size.width * 0.55, size.height * 0.53)
      ..cubicTo(
          size.width * 0.70, size.height * 0.51,
          size.width * 0.85, size.height * 0.54,
          size.width,        size.height * 0.53);
    canvas.drawPath(riverPath, riverP);

    // Moj pin — prava GPS pozicija korisnika ali center mape
    final myX = (userRelX != null) ? userRelX! * size.width : size.width * 0.5;
    final myY = (userRelY != null) ? userRelY! * size.height : size.height * 0.5;
    canvas.drawCircle(
        Offset(myX, myY), 14,
        Paint()..color = const Color(0xFF2196F3).withOpacity(0.18));
    canvas.drawCircle(
        Offset(myX, myY), 8,
        Paint()..color = const Color(0xFF2196F3).withOpacity(0.35));
    canvas.drawCircle(
        Offset(myX, myY), 6,
        Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(myX, myY), 4.5,
        Paint()..color = const Color(0xFF2196F3));
  }

  @override
  bool shouldRepaint(_MapGridPainter o) =>
      o.userRelX != userRelX || o.userRelY != userRelY || o.dark != dark;
}

// ── Mini popup za klik na heatmap točku ──────────────────────────────────────
class _HotspotPopup extends StatelessWidget {
  final HotspotData hotspot;
  final VoidCallback onClose;
  final VoidCallback? onDetails;

  const _HotspotPopup({
    required this.hotspot,
    required this.onClose,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final title = hotspot.$4;
    final description = hotspot.$6;
    final status = hotspot.$7;
    final id = hotspot.$5;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'rezervirano':
        statusColor = kOrange;
        statusLabel = 'Rezervirano';
        statusIcon = Icons.schedule_rounded;
        break;
      case 'prevzeto':
        statusColor = const Color(0xFF78909C);
        statusLabel = 'Prevzeto';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      default:
        statusColor = kGreenAccent;
        statusLabel = 'Na razpolago';
        statusIcon = Icons.check_rounded;
    }

    return Positioned(
      left: 16, right: 16, bottom: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A28),
            borderRadius: kRadius16,
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.18),
                    borderRadius: kRadiusFull,
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(statusIcon, color: statusColor, size: 11),
                    const SizedBox(width: 4),
                    Text(statusLabel, style: TextStyle(
                      color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white54, size: 14),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              // Title
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Only show button if we have a real id and callback
              if (id.isNotEmpty && onDetails != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.arrow_downward_rounded, size: 15),
                    label: const Text('Prikaži oglas na seznamu'),
                    style: TextButton.styleFrom(
                      foregroundColor: kGreenAccent,
                      backgroundColor: kGreenAccent.withOpacity(0.12),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(borderRadius: kRadius8),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── UI helpers ─────────────────────────────────────────────────────────────────
class _HeatStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HeatStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: kRadius8,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(
          fontSize: 11, color: kTextMid, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: kCaption),
  ]);
}

// ── Zoom gumb za heatmap ──────────────────────────────────────────────────────
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? activeColor; // null = bijeli stil, boja = obojeni stil (npr. plavi za lokaciju)

  const _ZoomButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isColored = activeColor != null && enabled;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isColored
              ? activeColor!.withOpacity(0.25)
              : enabled
                  ? Colors.white.withOpacity(0.18)
                  : Colors.white.withOpacity(0.07),
          borderRadius: kRadius12,
          border: Border.all(
            color: isColored
                ? activeColor!.withOpacity(0.7)
                : Colors.white.withOpacity(enabled ? 0.35 : 0.15),
            width: isColored ? 1.5 : 1.0,
          ),
          boxShadow: enabled
              ? [BoxShadow(
                  color: (isColored ? activeColor! : Colors.black).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2))]
              : [],
        ),
        child: Icon(
          icon,
          color: isColored
              ? activeColor
              : enabled ? Colors.white : Colors.white38,
          size: 18,
        ),
      ),
    );
  }
}