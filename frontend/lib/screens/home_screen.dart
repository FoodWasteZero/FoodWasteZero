// lib/screens/home_screen.dart
// – Firestore stream za live oglase
// – Pravi form za dodavanje (naziv, opis, kategorija, lokacija po izboru)
// – Funkcionalni filteri: Na voljo / Kmalu poteče / Rezervirano / Najbližje
// – Stats kartice se računaju iz live podataka

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../cards/food_card.dart';
import '../cards/food_detail_sheet.dart';
import 'profile_page.dart';

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
    default:
      icon = Icons.grass_rounded; color = const Color(0xFFF1F8E9);
  }

  // Izračunaj distanceKm iz koordinata (Maribor center kao referenca)
  double distKm = 1.0;
  final lat = (d['lat'] as num?)?.toDouble();
  final lng = (d['lng'] as num?)?.toDouble();
  if (lat != null && lng != null) {
    const refLat = 46.5547; const refLng = 15.6459;
    final dLat = (lat - refLat) * 111.0;
    final dLng = (lng - refLng) * 111.0 * cos(refLat * pi / 180);
    distKm = sqrt(dLat * dLat + dLng * dLng);
  }

  // Kmalu poteče — ako je dodano unutar zadnjeg sata ili je oznaka postavljena
  bool expiringSoon = d['expiringSoon'] as bool? ?? false;
  final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
  if (createdAt != null) {
    final age = DateTime.now().difference(createdAt);
    if (age.inMinutes < 60) expiringSoon = true;
  }

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
  // Posebni filter: null = brez, 'available', 'expiring', 'reserved', 'nearest'
  String? _activeFilter;
  final TextEditingController _searchCtrl = TextEditingController();

  static const _tabs = ['Vse', 'Kuhano', 'Sestavine', 'Peka', 'Sadje & zelenjava'];

  @override
  void initState() {
    super.initState();
    _loadUserType();
  }

  Future<void> _loadUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      setState(() => _isDavatelj = doc['userType'] == 'davatelj');
    }
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  // ── Filtriranje ─────────────────────────────────────────────────────────────
  List<FoodOglas> _applyFilters(List<FoodOglas> all) {
    var list = List<FoodOglas>.from(all);

    // Tab filter (kategorija)
    if (_selectedTab != 0) {
      list = list.where((o) => o.category == _tabs[_selectedTab]).toList();
    }

    // Quick action filteri
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

    // Iskanje
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

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _goToProfile() => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const ProfilePage()));

  void _showAddOglas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddOglasSheet(onSaved: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oglas uspešno objavljen! 🎉')));
      }),
    );
  }

  void _showShranjeno() => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ShranjenoSheet());

  void _showRezervacije() => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RezervacijeSheet());

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: _buildBody(),
      floatingActionButton: _navIndex == 0
          ? (_isDavatelj ? _buildFAB() : null)
          : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_navIndex) {
      case 0: return _buildHomeWithStream();
      case 1: return _buildPlaceholder(Icons.map_outlined, 'Zemljevid', 'Interaktivni zemljevid prihaja kmalu.');
      case 2: return _buildMyListingsWithStream();
      case 3: return const ProfilePage();
      default: return _buildHomeWithStream();
    }
  }

  // ── Firestore stream wraper ─────────────────────────────────────────────────
  Widget _buildHomeWithStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final oglasi = snap.hasData
            ? snap.data!.docs.map(_docToOglas).toList()
            : kSampleOglasi; // fallback na sample dok se učitava

        final filtered = _applyFilters(oglasi);
        final availableCount = oglasi.where((o) => o.status == OglasStatus.naRazpolago).length;
        final expiringCount  = oglasi.where((o) => o.isExpiringSoon).length;
        final reservedCount  = oglasi.where((o) => o.status == OglasStatus.rezervirano).length;

        return _buildHomeContent(filtered, oglasi, availableCount, expiringCount, reservedCount);
      },
    );
  }

  Widget _buildMyListingsWithStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildPlaceholder(Icons.inbox_outlined, 'Moji oglasi', 'Prijavite se za ogled.');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('uid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final moji = snap.hasData
            ? snap.data!.docs.map(_docToOglas).toList()
            : <FoodOglas>[];

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (moji.isEmpty) {
          return SafeArea(child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
                child: const Icon(Icons.inbox_outlined, size: 48, color: kGreenMid)),
              const SizedBox(height: 18),
              const Text('Moji oglasi', style: kHeading2),
              const SizedBox(height: 8),
              const Text('Še niste objavili nobenega oglasa.', style: kBody),
              const SizedBox(height: 24),
              if (_isDavatelj)
                ElevatedButton.icon(
                  onPressed: _showAddOglas,
                  icon: const Icon(Icons.add), label: const Text('Dodaj oglas')),
            ],
          )));
        }

        return CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true, backgroundColor: const Color(0xFF2E7D32),
            title: const Text('Moji oglasi',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            actions: [
              if (_isDavatelj)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ElevatedButton.icon(
                    onPressed: _showAddOglas,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Dodaj'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kGreenMid,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      shape: RoundedRectangleBorder(borderRadius: kRadius8),
                    ),
                  ),
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => FoodCard(
                oglas: moji[i],
                onTap: () => FoodDetailSheet.show(context, moji[i]),
              ),
              childCount: moji.length,
            )),
          ),
        ]);
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
    return CustomScrollView(slivers: [
      _buildSliverAppBar(),
      SliverToBoxAdapter(child: _buildSearchBar()),
      SliverToBoxAdapter(child: _buildStatsRow(availableCount, expiringCount, reservedCount)),
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

  Widget _buildPlaceholder(IconData icon, String title, String sub) {
    return SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
        child: Icon(icon, size: 48, color: kGreenMid)),
      const SizedBox(height: 18),
      Text(title, style: kHeading2),
      const SizedBox(height: 8),
      Text(sub, style: kBody, textAlign: TextAlign.center),
    ])));
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
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
              Text('Hrana blizu tebe 🌿',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              SizedBox(height: 3),
              Text('Reši hrano. Pomagaj skupnosti.',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
          )),
        ),
      ),
      title: Row(children: [
        Container(width: 26, height: 26,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: kRadius8),
          child: const Icon(Icons.eco, color: Colors.white, size: 15)),
        const SizedBox(width: 8),
        const Text('FoodWasteZero',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2)),
        const SizedBox(width: 6),
        const Icon(Icons.location_on, size: 12, color: Colors.white60),
        const Text('Maribor',
          style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
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

  // ── Search ──────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: kRadius16,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 6)),
          ]),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          style: const TextStyle(fontSize: 14, color: kTextDark),
          decoration: InputDecoration(
            hintText: 'Išči hrano v bližini...',
            hintStyle: kCaption.copyWith(fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: kGreenMid, size: 22),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                    child: const Icon(Icons.cancel_rounded, color: kTextLight, size: 20))
                : Container(margin: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: kGreenMid, borderRadius: kRadius8),
                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 17)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // ── Stats ───────────────────────────────────────────────────────────────────
  Widget _buildStatsRow(int available, int expiring, int reserved) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => _setFilter('available'),
          child: _StatCard(
            icon: Icons.eco_rounded, value: '$available', label: 'Na voljo',
            iconColor: kGreenLight, bgColor: kGreenPale,
            active: _activeFilter == 'available',
          ))),
        const SizedBox(width: 10),
        Expanded(child: GestureDetector(
          onTap: () => _setFilter('expiring'),
          child: _StatCard(
            icon: Icons.bolt_rounded, value: '$expiring', label: 'Kmalu poteče',
            iconColor: kOrange, bgColor: kOrangePale,
            active: _activeFilter == 'expiring',
          ))),
        const SizedBox(width: 10),
        Expanded(child: GestureDetector(
          onTap: () => _setFilter('reserved'),
          child: _StatCard(
            icon: Icons.handshake_rounded, value: '$reserved', label: 'Rezervirano',
            iconColor: const Color(0xFF5C6BC0), bgColor: const Color(0xFFE8EAF6),
            active: _activeFilter == 'reserved',
          ))),
      ]),
    );
  }

  // ── Quick actions ───────────────────────────────────────────────────────────
  Widget _buildQuickActionsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        if (_isDavatelj)
          Expanded(child: _QuickAction(
            icon: Icons.add_circle_rounded, label: 'Dodaj oglas', color: kGreenMid,
            onTap: _showAddOglas))
        else
          Expanded(child: _QuickAction(
            icon: Icons.bookmark_outline_rounded, label: 'Shranjeno',
            color: const Color(0xFF5C6BC0), onTap: _showShranjeno)),
        const SizedBox(width: 10),
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
      ]),
    );
  }

  // ── Heatmap ─────────────────────────────────────────────────────────────────
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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeatmapFullPage())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadiusFull,
                  border: Border.all(color: kGreenMid.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.open_in_full_rounded, size: 12, color: kGreenMid),
                  const SizedBox(width: 4),
                  Text('Odpri', style: kCaption.copyWith(color: kGreenMid, fontWeight: FontWeight.w700)),
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

  // ── Listings header ─────────────────────────────────────────────────────────
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
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 3),
                    const Icon(Icons.close, color: Colors.white, size: 10),
                  ]),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 2),
          Text('$count rezultatov najdenih',
            style: kCaption.copyWith(color: kGreenMid, fontWeight: FontWeight.w600, fontSize: 11)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => _setFilter('nearest'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _activeFilter == 'nearest' ? kGreenMid : Colors.white,
              borderRadius: kRadius8,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 2))],
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
      case 'reserved':  return 'Rezervirano';
      case 'nearest':   return 'Najbližje';
      default: return f;
    }
  }

  // ── Tab row ─────────────────────────────────────────────────────────────────
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
                      ? [BoxShadow(color: kGreenMid.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 5))]
                      : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Text(_tabs[i], style: TextStyle(
                  fontSize: 12,
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

  // ── FAB ─────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(borderRadius: kRadius16, boxShadow: [
        BoxShadow(color: kGreenMid.withOpacity(0.5), blurRadius: 28, offset: const Offset(0, 10)),
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

  // ── Bottom nav ──────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, -6)),
      ]),
      child: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        backgroundColor: Colors.transparent, elevation: 0,
        indicatorColor: kGreenPale,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: kGreenMid), label: 'Domov'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded, color: kGreenMid), label: 'Zemljevid'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox_rounded, color: kGreenMid), label: 'Moje'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: kGreenMid), label: 'Profil'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD OGLAS SHEET — pravi form sa Firestore zapisom
// ─────────────────────────────────────────────────────────────────────────────
class _AddOglasSheet extends StatefulWidget {
  final VoidCallback? onSaved;
  const _AddOglasSheet({this.onSaved});
  @override State<_AddOglasSheet> createState() => _AddOglasSheetState();
}

class _AddOglasSheetState extends State<_AddOglasSheet> {
  // Koraci: 0 = kategorija, 1 = detalji
  int _step = 0;
  String? _selectedCategory;
  bool _loading = false;

  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  bool _isFree = true;

  // Lokacija — user bira iz liste četvrti Maribora
  String _selectedCity = 'Maribor, Center';
  static const _lokacije = [
    ('Maribor, Center',    46.5547, 15.6459),
    ('Maribor, Tabor',     46.5600, 15.6380),
    ('Maribor, Tezno',     46.5480, 15.6610),
    ('Maribor, Pobrežje',  46.5610, 15.6720),
    ('Maribor, Magdalena', 46.5500, 15.6250),
    ('Maribor, Radvanje',  46.5420, 15.6180),
    ('Hoče',               46.5100, 15.6500),
    ('Miklavž',            46.5050, 15.6970),
    ('Limbuš',             46.5270, 15.5950),
    ('Ruše',               46.5400, 15.5120),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vnesite naziv oglasa.')));
      return;
    }
    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    final loc = _lokacije.firstWhere((l) => l.$1 == _selectedCity,
        orElse: () => _lokacije.first);

    try {
      await FirebaseFirestore.instance.collection('oglasi').add({
        'title':       _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category':    _selectedCategory,
        'location':    _selectedCity,
        'lat':         loc.$2,
        'lng':         loc.$3,
        'isFree':      _isFree,
        'status':      'naRazpolago',
        'uid':         user?.uid,
        'username':    user?.displayName != null ? '@${user!.displayName}' : null,
        'createdAt':   FieldValue.serverTimestamp(),
        'expiringSoon': false,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull))),
        const SizedBox(height: 20),

        // Header
        Row(children: [
          if (_step == 1)
            GestureDetector(
              onTap: () => setState(() => _step = 0),
              child: Container(
                width: 36, height: 36, margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadius8),
                child: const Icon(Icons.arrow_back_rounded, color: kGreenMid, size: 18)),
            ),
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadius12),
            child: const Icon(Icons.add_circle_outline_rounded, color: kGreenMid, size: 22)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Dodaj oglas', style: kHeading2),
            Text(_step == 0 ? 'Izberi kategorijo' : 'Izpolni podatke', style: kBody),
          ]),
        ]),
        const SizedBox(height: 20),

        // Korak 0: izbira kategorije
        if (_step == 0) ...[
          _CategoryTile(
            icon: Icons.soup_kitchen_rounded, label: 'Kuhano',
            sub: 'Pripravljeni obroki, juhe, enolončnice...',
            color: kOrange, bgColor: kOrangePale,
            selected: _selectedCategory == 'Kuhano',
            onTap: () { setState(() { _selectedCategory = 'Kuhano'; _step = 1; }); },
          ),
          const SizedBox(height: 10),
          _CategoryTile(
            icon: Icons.grass_rounded, label: 'Sestavine',
            sub: 'Sadje, zelenjava, moka, jajca...',
            color: kGreenLight, bgColor: kGreenPale,
            selected: _selectedCategory == 'Sestavine',
            onTap: () { setState(() { _selectedCategory = 'Sestavine'; _step = 1; }); },
          ),
          const SizedBox(height: 10),
          _CategoryTile(
            icon: Icons.bakery_dining_rounded, label: 'Peka',
            sub: 'Kruh, kolači, pecivo...',
            color: const Color(0xFF8D6E63), bgColor: const Color(0xFFEFEBE9),
            selected: _selectedCategory == 'Peka',
            onTap: () { setState(() { _selectedCategory = 'Peka'; _step = 1; }); },
          ),
          const SizedBox(height: 10),
          _CategoryTile(
            icon: Icons.apple_rounded, label: 'Sadje & zelenjava',
            sub: 'Sveže iz vrta ali kmetije...',
            color: const Color(0xFF00897B), bgColor: const Color(0xFFE0F2F1),
            selected: _selectedCategory == 'Sadje & zelenjava',
            onTap: () { setState(() { _selectedCategory = 'Sadje & zelenjava'; _step = 1; }); },
          ),
        ],

        // Korak 1: detalji
        if (_step == 1) ...[
          // Naziv
          _FormField(
            ctrl: _titleCtrl,
            label: 'Naziv oglasa',
            hint: 'npr. Domača jabolka, 3 kg',
            icon: Icons.label_outline_rounded,
          ),
          const SizedBox(height: 12),

          // Opis
          _FormField(
            ctrl: _descCtrl,
            label: 'Opis (neobvezno)',
            hint: 'Dodajte opis, količino, posebnosti...',
            icon: Icons.notes_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Lokacija — dropdown iz liste
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.location_on_rounded, color: kGreenMid, size: 18),
              const SizedBox(width: 6),
              const Text('Lokacija', style: TextStyle(fontWeight: FontWeight.w700,
                fontSize: 13, color: kTextDark)),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: kGreenPale,
                borderRadius: kRadius12,
                border: Border.all(color: kGreenMid.withOpacity(0.25)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCity,
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more_rounded, color: kGreenMid),
                  style: const TextStyle(fontSize: 13, color: kTextDark, fontWeight: FontWeight.w600),
                  items: _lokacije.map((l) => DropdownMenuItem(
                    value: l.$1,
                    child: Text(l.$1),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedCity = v!),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Koordinate se določijo samodejno.',
              style: kCaption.copyWith(color: kTextLight, fontSize: 11)),
          ]),
          const SizedBox(height: 16),

          // Brezplačno / simbolična cena
          GestureDetector(
            onTap: () => setState(() => _isFree = !_isFree),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isFree ? kGreenPale : kOrangePale,
                borderRadius: kRadius12,
                border: Border.all(
                  color: (_isFree ? kGreenMid : kOrange).withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(_isFree ? Icons.volunteer_activism_rounded : Icons.attach_money_rounded,
                  color: _isFree ? kGreenMid : kOrange, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_isFree ? 'Brezplačno' : 'Simbolična cena',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                      color: _isFree ? kGreenMid : kOrange)),
                  Text(_isFree ? 'Hrana je brezplačna' : 'Cena po dogovoru',
                    style: kCaption),
                ])),
                Switch(
                  value: _isFree,
                  onChanged: (v) => setState(() => _isFree = v),
                  activeColor: kGreenMid,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Submit
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreenMid, elevation: 0,
                shape: const RoundedRectangleBorder(borderRadius: kRadius12),
              ),
              child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Objavi oglas',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ]),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Form field helper ─────────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final int maxLines;
  const _FormField({required this.ctrl, required this.label,
    required this.hint, required this.icon, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: kGreenMid, size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700,
          fontSize: 13, color: kTextDark)),
      ]),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F5),
          borderRadius: kRadius12,
          border: Border.all(color: kBorder),
        ),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13, color: kTextDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: kCaption.copyWith(fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: InputBorder.none,
          ),
        ),
      ),
    ]);
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────
class _CategoryTile extends StatelessWidget {
  final IconData icon; final String label, sub;
  final Color color, bgColor; final bool selected;
  final VoidCallback onTap;
  const _CategoryTile({required this.icon, required this.label, required this.sub,
    required this.color, required this.bgColor, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: kRadius12,
          border: Border.all(color: selected ? color : color.withOpacity(0.25), width: selected ? 2 : 1),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: kRadius12),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: kBodyBold),
            const SizedBox(height: 2),
            Text(sub, style: kCaption),
          ])),
          Icon(Icons.chevron_right_rounded, color: color, size: 22),
        ]),
      ),
    );
  }
}

// ── Quick action ──────────────────────────────────────────────────────────────
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
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: active ? Colors.white : color),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── Notification button ───────────────────────────────────────────────────────
class _NotifButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _NotifButton({this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(width: 38, height: 38,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
        borderRadius: kRadius12, border: Border.all(color: Colors.white.withOpacity(0.25))),
      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20)));
}

// ── Avatar button ─────────────────────────────────────────────────────────────
class _AvatarButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _AvatarButton({this.onTap});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final initials = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName![0].toUpperCase() : 'U';
    return GestureDetector(onTap: onTap,
      child: CircleAvatar(radius: 19, backgroundColor: Colors.white,
        child: Text(initials,
          style: TextStyle(fontWeight: FontWeight.w900, color: kGreenMid, fontSize: 16))));
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
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
        boxShadow: [
          BoxShadow(color: iconColor.withOpacity(active ? 0.4 : 0.12),
            blurRadius: 20, offset: const Offset(0, 5)),
        ],
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
            fontSize: 10, color: active ? Colors.white70 : null),
            overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
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

// ── Shranjeno sheet ───────────────────────────────────────────────────────────
class _ShranjenoSheet extends StatelessWidget {
  const _ShranjenoSheet();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull))),
        const SizedBox(height: 22),
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: const Color(0xFFEDE7F6), borderRadius: kRadius12),
            child: const Icon(Icons.bookmark_rounded, color: Color(0xFF5C6BC0), size: 22)),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Shranjeni oglasi', style: kHeading2),
            Text('Oglasi, ki si jih shranil', style: kBody),
          ]),
        ]),
        const SizedBox(height: 24),
        Center(child: Column(children: [
          Icon(Icons.bookmark_border_rounded, size: 48, color: kBorder),
          const SizedBox(height: 8),
          const Text('Ni shranjenih oglasov', style: TextStyle(color: kTextLight, fontSize: 14)),
        ])),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ── Rezervacije sheet ─────────────────────────────────────────────────────────
class _RezervacijeSheet extends StatelessWidget {
  const _RezervacijeSheet();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull))),
        const SizedBox(height: 22),
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: kOrangePale, borderRadius: kRadius12),
            child: const Icon(Icons.bookmark_added_rounded, color: kOrange, size: 22)),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Moje rezervacije', style: kHeading2),
            Text('Prihaja v naslednji verziji', style: kBody),
          ]),
        ]),
        const SizedBox(height: 24),
        Center(child: Column(children: [
          Icon(Icons.inbox_outlined, size: 48, color: kBorder),
          const SizedBox(height: 8),
          const Text('Ni aktivnih rezervacij', style: TextStyle(color: kTextLight, fontSize: 14)),
        ])),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Heatmap (ostaje isto)
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
        BoxShadow(color: const Color(0xFF1B5E20).withOpacity(0.3), blurRadius: 28, offset: const Offset(0, 8)),
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
              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9,
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
              return Text('$count aktivnih oglasov v Mariboru',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12));
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

// ── Full heatmap page ─────────────────────────────────────────────────────────
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
            const Text('Toplotna karta', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
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
                    Text('$count aktivnih', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull)),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Razporeditev hrane', style: kHeading3),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadiusFull),
                child: const Text('Maribor', style: TextStyle(color: kGreenMid, fontSize: 12, fontWeight: FontWeight.w700))),
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
              onPressed: () { Navigator.pop(context); },
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