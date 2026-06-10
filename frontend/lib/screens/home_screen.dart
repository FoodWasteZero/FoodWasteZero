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
import '../widgets/notifications_sheet.dart';
import '../services/ui_state_service.dart';
import '../common/publisher_navigation.dart';

// ────────────────────────────────────────────────────────────────
// Helper: Firestore doc → FoodOglas
// ────────────────────────────────────────────────────────────────
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
    expiryDate: expiryDate,
    termin1: (d['termin1'] as Timestamp?)?.toDate(),
    waitlist: waitlist,
    portions: (d['portions'] as num?)?.toInt(),
    remainingPortions: (d['remainingPortions'] as num?)?.toInt(),
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

// ──────────────────────────────────────��─────────────────────────
// HomeScreen
// ────────────────────────────────────────────────────────────────
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
  VoidCallback? _navIndexListener;

  int get _mineNavIndex => _isDavatelj ? 1 : 2;

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
    _navIndexListener = () {
      final req = UIStateService.instance.requestedNavIndex.value;
      if (req == null || !mounted) return;
      UIStateService.instance.requestedNavIndex.value = null;
      setState(() => _navIndex = req == -1 ? _mineNavIndex : req);
    };
    UIStateService.instance.requestedNavIndex
        .addListener(_navIndexListener!);
  }

  // ── Tiho pridobi lokacijo ob zagonu ─────────────────────────────────────
  Future<void> _fetchLocationSilent() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      if (mounted) setState(() => _locationLoading = true);

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
          _locationLoading = false;
        });
        _reverseGeocode(pos.latitude, pos.longitude);
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
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
    if (_navIndexListener != null) {
      UIStateService.instance.requestedNavIndex
          .removeListener(_navIndexListener!);
    }
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
    // Ako nema lokacije i klikne "Najbližje" — prikaži obavijest
    if (newFilter == 'nearest' && _userLat == null) {
      _fetchLocation(); // zatraži GPS
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.location_off_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Vključi lokacijo za razvrščanje po razdalji'),
          ]),
          backgroundColor: const Color(0xFF1565C0),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: kRadius12),
          action: SnackBarAction(
            label: 'Vključi',
            textColor: Colors.white,
            onPressed: _fetchLocation,
          ),
        ),
      );
      return; // Ne aktiviraj filter dok nema lokacije
    }
    setState(() => _activeFilter = newFilter);
    if (newFilter == 'nearest' && _userLat != null) {
      _fetchLocation();
    }
  }

  void _showAuthPopup() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AuthScreen(isModal: true),
    );
    if (mounted) {
      setState(() {}); // Refresh UI nakon zatvaranja modala
      _loadUserType();
    }
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

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          backgroundColor: isDark
              ? kDarkSurface
              : Color.lerp(kSurface, const Color(0xFFE8F5E9), t * 0.5)!,
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

  // Placeholder for _buildHomeWithStream - rest of the code would continue...
  Widget _buildHomeWithStream() => const SizedBox.shrink();
  Widget _buildBottomNav({required Color navBg, required Color navIndicator, required Color navSelectedIcon, required Color navUnselectedIcon}) => const SizedBox.shrink();
}
