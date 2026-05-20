import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../cards/food_card.dart';
import '../cards/food_detail_sheet.dart';
import 'profile_page.dart';
import 'mine_screen.dart';
import 'auth_screen.dart';
import 'recipe_page.dart';

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

  double distKm = 1.0;
  final lat = (d['lat'] as num?)?.toDouble();
  final lng = (d['lng'] as num?)?.toDouble();
  if (lat != null && lng != null) {
    const refLat = 46.5547; const refLng = 15.6459;
    final dLat = (lat - refLat) * 111.0;
    final dLng = (lng - refLng) * 111.0 * cos(refLat * pi / 180);
    distKm = sqrt(dLat * dLat + dLng * dLng);
  }

  final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
  final expiryDate = (d['expiryDate'] as Timestamp?)?.toDate();

  bool expiringSoon = d['expiringSoon'] as bool? ?? false;
  if (expiryDate != null) {
    final hoursLeft = expiryDate.difference(DateTime.now()).inHours;
    if (hoursLeft <= 24 && hoursLeft >= 0) expiringSoon = true;
  }

  // NOVO: čitaj waitlist
  final waitlistRaw = d['waitlist'];
  final waitlist = (waitlistRaw is List)
      ? waitlistRaw.map((e) => e.toString()).toList()
      : <String>[];

  return FoodOglas(
    id: doc.id,
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
    waitlist: waitlist, // NOVO
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

class _HomeScreenState extends State<HomeScreen> {
  bool _isDavatelj = false;
  int _selectedTab = 0;
  int _navIndex = 0;
  String _searchQuery = '';
  String? _activeFilter;
  String _mesto = 'Maribor'; // NOVO: tappable lokacija
  final TextEditingController _searchCtrl = TextEditingController();
  StreamSubscription<User?>? _authSub;

  static const _tabs = ['Vse', 'Kuhano', 'Sestavine', 'Peka', 'Sadje & zelenjava'];

  @override
  void initState() {
    super.initState();
    _loadUserType();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user == null) {
        setState(() { _isDavatelj = false; _navIndex = 0; });
      } else {
        _loadUserType();
      }
    });
  }

  Future<void> _loadUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      setState(() => _isDavatelj = doc.data()?['userType'] == 'davatelj');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // NOVO: Dialog za promjenu mesta/lokacije
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
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Hitre možnosti
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in ['Maribor', 'Ljubljana', 'Celje', 'Kranj', 'Koper'])
              GestureDetector(
                onTap: () {
                  ctrl.text = m;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kGreenPale,
                    borderRadius: kRadiusFull,
                    border: Border.all(color: kGreenMid.withOpacity(0.3)),
                  ),
                  child: Text(m,
                      style: const TextStyle(
                          fontSize: 14, color: kGreenMid, fontWeight: FontWeight.w600)),
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

  // ── Filtriranje ─────────────────────────────────────────────────────────────
  List<FoodOglas> _applyFilters(List<FoodOglas> all) {
    var list = List<FoodOglas>.from(all);
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
    setState(() => _activeFilter = (_activeFilter == f) ? null : f);
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

  void _goToProfile() => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const ProfilePage()));

  void _showAddOglas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddOglasSheet(onSaved: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oglas uspešno objavljen! 🎉')));
      }),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: _buildBody(),
      floatingActionButton: _navIndex == 0
          ? (FirebaseAuth.instance.currentUser != null && _isDavatelj
              ? _buildFAB()
              : null)
          : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_navIndex) {
      case 0: return _buildHomeWithStream();
      case 1: return const RecipePage();
      case 2: return const MineScreen();
      case 3: return const ProfilePage();
      default: return _buildHomeWithStream();
    }
  }

  Widget _buildHomeWithStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final oglasi = snap.hasData
            ? snap.data!.docs.map(_docToOglas).toList()
            : kSampleOglasi;

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
    if (_isDavatelj) {
      return _buildOrgHomeContent(filtered, availableCount, expiringCount, reservedCount);
    }
    return CustomScrollView(slivers: [
      _buildSliverAppBar(),
      SliverToBoxAdapter(child: _buildSearchBar()),
      SliverToBoxAdapter(child: _buildQuickActionsRow()),
      SliverToBoxAdapter(child: _buildHeatmapSection()),
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

  // ── Organizacija homepage ──────────────────────────────────────────────────
  Widget _buildOrgHomeContent(
    List<FoodOglas> filtered, int available, int expiring, int reserved) {
    return CustomScrollView(slivers: [
      _buildOrgSliverAppBar(),
      SliverToBoxAdapter(child: _buildSearchBar()),
      SliverToBoxAdapter(child: _buildOrgQuickActions()),
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

  // ── Org AppBar ─────────────────────────────────────────────────────────────
  Widget _buildOrgSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 110, pinned: true, elevation: 2,
      backgroundColor: Colors.white,
      shadowColor: Colors.black.withOpacity(0.12),
      surfaceTintColor: Colors.transparent, forceElevated: true,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          color: Colors.white,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Column(mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kGreenPale,
                    borderRadius: kRadiusFull,
                    border: Border.all(color: kGreenMid.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.store_rounded, size: 13, color: kGreenMid),
                    const SizedBox(width: 5),
                    Text('Organizacija', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: kGreenMid)),
                  ]),
                ),
              ]),
              const SizedBox(height: 6),
              const Text('Dobrodošli nazaj',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: kTextDark, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              const Text('Upravljajte vaše oglase in doseg.',
                style: TextStyle(fontSize: 14, color: kTextMid)),
            ]),
          )),
        ),
      ),
      title: Row(children: [
        Container(width: 26, height: 26,
          decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadius8),
          child: const Icon(Icons.eco, color: kGreenMid, size: 15)),
        const SizedBox(width: 8),
        const Text('FoodWasteZero',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
            color: kTextDark, letterSpacing: -0.2)),
      ]),
      centerTitle: false,
      actions: [
        Padding(padding: const EdgeInsets.only(right: 8),
          child: _NotifButton(onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ni novih obvestil'))))),
        Padding(padding: const EdgeInsets.only(right: 12),
          child: _AvatarButton(onTap: _goToProfile, dark: true)),
      ],
    );
  }

  // ── AppBar — s tappable lokacijo ───────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 110, pinned: true, elevation: 2,
      backgroundColor: const Color(0xFF2E7D32),
      shadowColor: Colors.black.withOpacity(0.2),
      surfaceTintColor: Colors.transparent, forceElevated: true,
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
        // NOVO: tappable lokacija
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
              const Icon(Icons.location_on, size: 11, color: Colors.white70),
              const SizedBox(width: 3),
              Text(_mesto,
                style: const TextStyle(
                    fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 13, color: Colors.white70),
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
          child: _AvatarButton(onTap: _goToProfile)),
      ],
    );
  }

  // ── Search — BEZ filter gumba ──────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: kRadius16,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08),
                blurRadius: 24, offset: const Offset(0, 6)),
          ]),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          style: const TextStyle(fontSize: 14, color: kTextDark),
          decoration: InputDecoration(
            hintText: 'Išči hrano v bližini...',
            hintStyle: kCaption.copyWith(fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: kGreenMid, size: 22),
            // NOVO: samo clear gumb, brez filter ikone
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.cancel_rounded, color: kTextLight, size: 20))
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }


  // ── Quick actions — BEZ Shranjeno ──────────────────────────────────────────
  Widget _buildQuickActionsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
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
    );
  }

  // ── Heatmap ────────────────────────────────────────────────────────────────
  Widget _buildHeatmapSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            const Text('Toplotna karta', style: kHeading3),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HeatmapFullPage())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadiusFull,
                  border: Border.all(color: kGreenMid.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.open_in_full_rounded, size: 12, color: kGreenMid),
                  const SizedBox(width: 4),
                  Text('Odpri', style: kCaption.copyWith(
                      color: kGreenMid, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
        HeatmapPreviewCard(onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const HeatmapFullPage()))),
      ]),
    );
  }

  // ── Listings header ────────────────────────────────────────────────────────
  Widget _buildListingsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Oglasi v bližini', style: kHeading3),
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
                color: kGreenMid, fontWeight: FontWeight.w600, fontSize: 14)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => _setFilter('nearest'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _activeFilter == 'nearest' ? kGreenMid : Colors.white,
              borderRadius: kRadius8,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
                  blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Icon(Icons.sort_rounded, size: 14,
                  color: _activeFilter == 'nearest' ? Colors.white : kTextMid),
              const SizedBox(width: 4),
              Text('Razdalja', style: kCaption.copyWith(
                fontWeight: FontWeight.w600,
                color: _activeFilter == 'nearest' ? Colors.white : kTextMid)),
            ]),
          ),
        ),
      ]),
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

  // ── Tab row ────────────────────────────────────────────────────────────────
  Widget _buildTabRow() {
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
                  color: active ? kGreenMid : Colors.white,
                  borderRadius: kRadiusFull,
                  boxShadow: active
                      ? [BoxShadow(color: kGreenMid.withOpacity(0.4),
                            blurRadius: 16, offset: const Offset(0, 5))]
                      : [BoxShadow(color: Colors.black.withOpacity(0.06),
                            blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Text(_tabs[i], style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : kTextMid,
                )),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(borderRadius: kRadius16, boxShadow: [
        BoxShadow(color: kGreenMid.withOpacity(0.5),
            blurRadius: 28, offset: const Offset(0, 10)),
      ]),
      child: FloatingActionButton.extended(
        onPressed: _showAddOglas,
        backgroundColor: kGreenMid, elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: kRadius16),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text('Dodaj oglas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final isGuest = FirebaseAuth.instance.currentUser == null;
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.1),
            blurRadius: 30, offset: const Offset(0, -6)),
      ]),
      child: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          if (isGuest && (i == 2 || i == 3)) {
            _showAuthPopup();
            return;
          }
          setState(() => _navIndex = i);
        },
        backgroundColor: Colors.transparent, elevation: 0,
        indicatorColor: kGreenPale,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: kGreenMid),
              label: 'Domov'),
          const NavigationDestination(
              icon: Icon(Icons.restaurant_rounded),
              selectedIcon: Icon(Icons.restaurant_rounded, color: kGreenMid),
              label: 'AI Chef'),
          const NavigationDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox_rounded, color: kGreenMid),
              label: 'Moje objave'),
          NavigationDestination(
            icon: Icon(isGuest ? Icons.login_rounded : Icons.person_outline_rounded),
            selectedIcon: Icon(isGuest ? Icons.login_rounded : Icons.person_rounded,
                color: kGreenMid),
            label: isGuest ? 'Prijava' : 'Profil',
          ),
        ],
      ),
    );
  }

  // ── Org stats ──────────────────────────────────────────────────────────────
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
      child: Row(children: [
        Expanded(child: _OrgQuickAction(
          icon: Icons.add_circle_outline_rounded, label: 'Nov oglas',
          color: kGreenMid, onTap: _showAddOglas)),
        const SizedBox(width: 10),
        Expanded(child: _OrgQuickAction(
          icon: Icons.bolt_rounded, label: 'Poteče kmalu',
          color: kOrange, active: _activeFilter == 'expiring',
          onTap: () => _setFilter('expiring'))),
        const SizedBox(width: 10),
        Expanded(child: _OrgQuickAction(
          icon: Icons.near_me_rounded, label: 'Najbližje',
          color: const Color(0xFF0288D1), active: _activeFilter == 'nearest',
          onTap: () => _setFilter('nearest'))),
        const SizedBox(width: 10),
        Expanded(child: _OrgQuickAction(
          icon: Icons.eco_rounded, label: 'Na voljo',
          color: kGreenMid, active: _activeFilter == 'available',
          onTap: () => _setFilter('available'))),
      ]),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  final VoidCallback onTap; final bool active;
  const _QuickAction({required this.icon, required this.label,
    required this.color, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: Column(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: active ? Colors.white.withOpacity(0.25) : color.withOpacity(0.12),
              borderRadius: kRadius8),
            child: Icon(icon, color: active ? Colors.white : color, size: 18)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
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
// Heatmap (ostaja isto)
// ══════════════════════════════════════════════════════════════════════════════
class HeatmapPreviewCard extends StatelessWidget {
  final VoidCallback? onTap;
  const HeatmapPreviewCard({super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 170,
      decoration: BoxDecoration(borderRadius: kRadius16, boxShadow: [
        BoxShadow(color: const Color(0xFF1B5E20).withOpacity(0.3),
            blurRadius: 28, offset: const Offset(0, 8)),
      ]),
      child: ClipRRect(borderRadius: kRadius16, child: Stack(fit: StackFit.expand, children: [
        const _MockMapBackground(),
        const _HeatmapDots(),
        Container(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
          stops: const [0.3, 1.0]))),
        Positioned(left: 16, bottom: 16, right: 60, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kGreenAccent, borderRadius: kRadiusFull),
              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.w800, letterSpacing: 1.2))),
            const SizedBox(width: 8),
            const Flexible(child: Text('Toplotna karta hrane',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('oglasi').snapshots(),
            builder: (_, snap) {
              final count = snap.data?.docs.length ?? kSampleOglasi.length;
              return Text('$count aktivnih oglasov',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14));
            },
          ),
        ])),
        Positioned(right: 14, bottom: 14, child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
            borderRadius: kRadiusFull, border: Border.all(color: Colors.white.withOpacity(0.5))),
          child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16))),
      ])),
    ));
  }
}

class _MockMapBackground extends StatelessWidget {
  const _MockMapBackground();
  @override
  Widget build(BuildContext context) =>
    CustomPaint(painter: _MapGridPainter(), child: Container(color: const Color(0xFF1A3A2A)));
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF2A4A3A)..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 22) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    for (double x = 0; x < size.width; x += 30) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    final rp = Paint()..color = const Color(0xFF3A5A4A)..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.45), rp);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), rp);
  }
  @override bool shouldRepaint(_) => false;
}

class _HeatmapDots extends StatefulWidget {
  const _HeatmapDots();
  @override State<_HeatmapDots> createState() => _HeatmapDotsState();
}

class _HeatmapDotsState extends State<_HeatmapDots> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _p;
  static const _hs = [(0.2,0.35,3.0),(0.45,0.25,2.0),(0.6,0.55,4.0),(0.75,0.3,2.5),(0.3,0.65,1.5),(0.85,0.7,3.0),(0.15,0.7,2.0),(0.55,0.75,1.5)];
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true); _p = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _p, builder: (_, __) => CustomPaint(painter: _HeatmapPainter(_hs, _p.value), child: Container(color: Colors.transparent)));
}

class _HeatmapPainter extends CustomPainter {
  final List<(double,double,double)> hs; final double p;
  _HeatmapPainter(this.hs, this.p);
  @override void paint(Canvas canvas, Size size) {
    for (final (rx,ry,intensity) in hs) {
      final cx = rx*size.width, cy = ry*size.height, br = intensity*14.0*p;
      for (int i = 3; i >= 0; i--) {
        final r = br*(1+i*0.5), op = 0.06*(4-i)*p;
        canvas.drawCircle(Offset(cx,cy), r, Paint()..shader = RadialGradient(
          colors:[const Color(0xFF4CAF50).withOpacity(op+0.05),Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(cx,cy), radius: r)));
      }
      canvas.drawCircle(Offset(cx,cy), 3.5, Paint()..color = kGreenAccent.withOpacity(0.9*p));
    }
  }
  @override bool shouldRepaint(_HeatmapPainter o) => o.p != p;
}

class HeatmapFullPage extends StatefulWidget {
  const HeatmapFullPage({super.key});
  @override State<HeatmapFullPage> createState() => _HeatmapFullPageState();
}

class _HeatmapFullPageState extends State<HeatmapFullPage> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _p;
  static const _hs = [(0.2,0.35,3.5),(0.45,0.25,2.5),(0.6,0.55,5.0),(0.75,0.3,3.0),(0.3,0.65,2.0),(0.85,0.7,3.5),(0.15,0.7,2.5),(0.55,0.75,2.0),(0.4,0.45,4.0),(0.7,0.15,2.0),(0.25,0.15,1.5),(0.9,0.4,2.5),(0.1,0.5,3.0),(0.65,0.85,2.0)];
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true); _p = Tween<double>(begin: 0.75, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)); }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A2A),
      body: Stack(children: [
        Positioned.fill(child: AnimatedBuilder(animation: _p,
          builder: (_, __) => CustomPaint(painter: _FullMapPainter(_hs, _p.value)))),
        SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                borderRadius: kRadius12, border: Border.all(color: Colors.white.withOpacity(0.25))),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
            const SizedBox(width: 12),
            const Text('Toplotna karta', style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('oglasi').snapshots(),
              builder: (_, snap) {
                final count = snap.data?.docs.length ?? kSampleOglasi.length;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: kGreenAccent.withOpacity(0.9), borderRadius: kRadiusFull),
                  child: Row(children: [
                    const Icon(Icons.circle, color: Colors.white, size: 8), const SizedBox(width: 4),
                    Text('$count aktivnih', style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]));
              },
            ),
          ]),
        )),
        Positioned(left: 0, right: 0, bottom: 0, child: Container(
          decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull)),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Razporeditev hrane', style: kHeading3),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadiusFull),
                child: const Text('Maribor', style: TextStyle(
                    color: kGreenMid, fontSize: 14, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              _LegendDot(color: kGreenAccent, label: 'Visoka gostota'),
              const SizedBox(width: 16),
              _LegendDot(color: kGreenLight.withOpacity(0.6), label: 'Srednja gostota'),
              const SizedBox(width: 16),
              _LegendDot(color: kGreenLight.withOpacity(0.25), label: 'Nizka gostota'),
            ]),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.my_location_rounded, size: 16),
              label: const Text('Pokaži bližnje oglase'),
              style: OutlinedButton.styleFrom(foregroundColor: kGreenMid,
                side: const BorderSide(color: kGreenMid, width: 1.5),
                shape: const RoundedRectangleBorder(borderRadius: kRadius12),
                padding: const EdgeInsets.symmetric(vertical: 13)),
            )),
          ]),
        )),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color; final String label;
  const _LegendDot({required this.color, required this.label});
  @override Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5), Text(label, style: kCaption),
  ]);
}

class _FullMapPainter extends CustomPainter {
  final List<(double,double,double)> hs; final double p;
  _FullMapPainter(this.hs, this.p);
  @override void paint(Canvas canvas, Size size) {
    final gp = Paint()..color = const Color(0xFF2A4A3A)..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0,y), Offset(size.width,y), gp);
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x,0), Offset(x,size.height), gp);
    final rp = Paint()..color = const Color(0xFF3A5A4A)..strokeWidth = 5;
    canvas.drawLine(Offset(0, size.height*0.45), Offset(size.width, size.height*0.45), rp);
    canvas.drawLine(Offset(size.width*0.35, 0), Offset(size.width*0.35, size.height), rp);
    canvas.drawLine(Offset(size.width*0.65, 0), Offset(size.width*0.65, size.height), rp);
    for (final (rx,ry,intensity) in hs) {
      final cx=rx*size.width, cy=ry*size.height, br=intensity*22.0*p;
      for (int i=4; i>=0; i--) {
        final r=br*(1+i*0.45), op=0.05*(5-i)*p;
        canvas.drawCircle(Offset(cx,cy), r, Paint()..shader = RadialGradient(
          colors:[const Color(0xFF4CAF50).withOpacity(op+0.04),Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(cx,cy), radius: r)));
      }
      canvas.drawCircle(Offset(cx,cy), 4.5, Paint()..color = kGreenAccent.withOpacity(0.95*p));
    }
  }
  @override bool shouldRepaint(_FullMapPainter o) => o.p != p;
}