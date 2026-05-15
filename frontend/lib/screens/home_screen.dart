import 'dart:math';
import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../cards/food_card.dart';
import '../cards/food_detail_sheet.dart';
import 'profile_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // TODO: zamijeni s Firebase userType
  bool _isDavatelj = false; // false = običan korisnik, true = davatelj hrane

  int _selectedTab = 0;
  int _navIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  static const _tabs = ['Vse', 'Kuhano', 'Sestavine', 'Peka', 'Sadje & zelenjava'];

  List<FoodOglas> get _filtered {
    var list = _selectedTab == 0
        ? kSampleOglasi
        : kSampleOglasi.where((o) => o.category == _tabs[_selectedTab]).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((o) =>
        o.title.toLowerCase().contains(q) ||
        o.location.toLowerCase().contains(q) ||
        o.category.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  int get _availableCount => kSampleOglasi.where((o) => o.status == OglasStatus.naRazpolago).length;
  int get _expiringSoonCount => kSampleOglasi.where((o) => o.isExpiringSoon).length;
  int get _reservedCount => kSampleOglasi.where((o) => o.status == OglasStatus.rezervirano).length;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _goToProfile() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));

  void _showAddOglas() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddOglasSheet(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: _buildBody(),
      floatingActionButton: (_navIndex == 0 && _isDavatelj) ? _buildFAB() : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_navIndex) {
      case 0: return _buildHomeContent();
      case 1: return _buildPlaceholder(Icons.map_outlined, 'Zemljevid', 'Interaktivni zemljevid prihaja kmalu.');
      case 2: return _buildMyListings();
      case 3: return const ProfilePage();
      default: return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        SliverToBoxAdapter(child: _buildSearchBar()),
        SliverToBoxAdapter(child: _buildStatsRow()),
        SliverToBoxAdapter(child: _buildQuickActionsRow()),
        SliverToBoxAdapter(child: _buildHeatmapSection()),
        SliverToBoxAdapter(child: _buildListingsHeader()),
        SliverToBoxAdapter(child: _buildTabRow()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          sliver: _filtered.isEmpty
              ? const SliverToBoxAdapter(child: _EmptyState())
              : SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => FoodCard(
                      oglas: _filtered[i],
                      onTap: () => FoodDetailSheet.show(context, _filtered[i]),
                    ),
                  childCount: _filtered.length,
                )),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(IconData icon, String title, String sub) {
    return SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: kGreenMid.withOpacity(0.15), blurRadius: 32, offset: const Offset(0, 8))]),
        child: Icon(icon, size: 48, color: kGreenMid)),
      const SizedBox(height: 18),
      Text(title, style: kHeading2),
      const SizedBox(height: 8),
      Text(sub, style: kBody, textAlign: TextAlign.center),
    ])));
  }

  Widget _buildMyListings() {
    return SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: kGreenMid.withOpacity(0.15), blurRadius: 32, offset: const Offset(0, 8))]),
        child: const Icon(Icons.inbox_outlined, size: 48, color: kGreenMid)),
      const SizedBox(height: 18),
      const Text('Moji oglasi', style: kHeading2),
      const SizedBox(height: 8),
      const Text('Tukaj bodo prikazani vaši objavljeni oglasi.', style: kBody, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: _showAddOglas, icon: const Icon(Icons.add), label: const Text('Dodaj oglas')),
    ])));
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      elevation: 2,
      backgroundColor: const Color(0xFF2E7D32),
      shadowColor: Colors.black.withOpacity(0.2),
      surfaceTintColor: Colors.transparent,
      forceElevated: true,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
            ),
          ),
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hrana blizu tebe 🌿',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 3),
                const Text('Reši hrano. Pomagaj skupnosti.',
                  style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w400)),
              ],
            ),
          )),
        ),
      ),
      title: Row(children: [
        Container(
          width: 26, height: 26,
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
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _NotifButton(onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ni novih obvestil')))),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _AvatarButton(onTap: _goToProfile),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius16,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 6)),
            BoxShadow(color: kGreenMid.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
          ],
        ),
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
                : Container(
                    margin: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: kGreenMid,
                      borderRadius: kRadius8,
                      boxShadow: [BoxShadow(color: kGreenMid.withOpacity(0.45), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 17)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        Expanded(child: _StatCard(icon: Icons.eco_rounded, value: '$_availableCount', label: 'Na voljo', iconColor: kGreenLight, bgColor: kGreenPale)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(icon: Icons.bolt_rounded, value: '$_expiringSoonCount', label: 'Kmalu poteče', iconColor: kOrange, bgColor: kOrangePale)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(icon: Icons.handshake_rounded, value: '$_reservedCount', label: 'Rezervirano', iconColor: const Color(0xFF5C6BC0), bgColor: const Color(0xFFE8EAF6))),
      ]),
    );
  }

  Widget _buildQuickActionsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        if (_isDavatelj)
          Expanded(child: _QuickAction(icon: Icons.add_circle_rounded, label: 'Dodaj oglas', color: kGreenMid, onTap: _showAddOglas))
        else
          Expanded(child: _QuickAction(icon: Icons.bookmark_outline_rounded, label: 'Shranjeno', color: const Color(0xFF5C6BC0),
            onTap: () => _showShranjeno())),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(icon: Icons.bolt_rounded, label: 'Kmalu poteče', color: const Color(0xFFE53935),
          onTap: () { setState(() { _selectedTab = 0; _searchQuery = ''; }); })),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(icon: Icons.near_me_rounded, label: 'Najbližje', color: const Color(0xFF0288D1),
          onTap: () {
            final sorted = List<FoodOglas>.from(kSampleOglasi)
              ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
            setState(() { _selectedTab = 0; _searchQuery = sorted.first.location; });
          })),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(icon: Icons.filter_list_rounded, label: 'Filtriraj', color: const Color(0xFF00897B),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Filtri prihajajo kmalu...'))))),
      ]),
    );
  }

  void _showShranjeno() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ShranjenoSheet(),
    );
  }

  void _showRezervacije() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RezervacijeSheet(),
    );
  }

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
                decoration: BoxDecoration(
                  color: kGreenPale,
                  borderRadius: kRadiusFull,
                  border: Border.all(color: kGreenMid.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.open_in_full_rounded, size: 12, color: kGreenMid),
                  const SizedBox(width: 4),
                  Text('Odpri', style: kCaption.copyWith(color: kGreenMid, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
        HeatmapPreviewCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeatmapFullPage()))),
      ]),
    );
  }

  Widget _buildListingsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Oglasi v bližini', style: kHeading3),
          const SizedBox(height: 2),
          Text('${_filtered.length} rezultatov najdenih',
            style: kCaption.copyWith(color: kGreenMid, fontWeight: FontWeight.w600, fontSize: 11)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: kRadius8,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            const Icon(Icons.sort_rounded, size: 14, color: kTextMid),
            const SizedBox(width: 4),
            Text('Razdalja', style: kCaption.copyWith(fontWeight: FontWeight.w600, color: kTextMid)),
          ]),
        ),
      ]),
    );
  }

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
                      ? [
                          BoxShadow(color: kGreenMid.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 5)),
                          BoxShadow(color: kGreenMid.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
                        ]
                      : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Text(_tabs[i], style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : kTextMid,
                  letterSpacing: active ? 0.2 : 0,
                )),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFAB() {
    if (_isDavatelj) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: kRadius16,
          boxShadow: [
            BoxShadow(color: kGreenMid.withOpacity(0.5), blurRadius: 28, offset: const Offset(0, 10)),
            BoxShadow(color: kGreenMid.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddOglas,
          backgroundColor: kGreenMid, elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: kRadius16),
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: const Text('Dodaj oglas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.2)),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          borderRadius: kRadius16,
          boxShadow: [
            BoxShadow(color: kOrange.withOpacity(0.5), blurRadius: 28, offset: const Offset(0, 10)),
            BoxShadow(color: kOrange.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showRezervacije,
          backgroundColor: kOrange, elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: kRadius16),
          icon: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 22),
          label: const Text('Moje rezervacije', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.2)),
        ),
      );
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, -6)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
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

// ── Quick action button ───────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: kRadius8),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── Add listing sheet ─────────────────────────────────────────────────────────
class _AddOglasSheet extends StatelessWidget {
  const _AddOglasSheet();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull))),
        const SizedBox(height: 22),
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadius12),
            child: const Icon(Icons.add_circle_outline_rounded, color: kGreenMid, size: 22)),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dodaj oglas', style: kHeading2),
            Text('Kaj bi rad delil s skupnostjo?', style: kBody),
          ]),
        ]),
        const SizedBox(height: 20),
        _AddCategoryTile(icon: Icons.soup_kitchen_rounded, label: 'Kuhano', sub: 'Pripravljeni obroki, juhe, enolončnice...', color: kOrange, bgColor: kOrangePale),
        const SizedBox(height: 10),
        _AddCategoryTile(icon: Icons.grass_rounded, label: 'Sestavine', sub: 'Sadje, zelenjava, moka, jajca...', color: kGreenLight, bgColor: kGreenPale),
        const SizedBox(height: 10),
        _AddCategoryTile(icon: Icons.bakery_dining_rounded, label: 'Peka', sub: 'Kruh, kolači, pecivo...', color: const Color(0xFF8D6E63), bgColor: const Color(0xFFEFEBE9)),
        const SizedBox(height: 10),
        _AddCategoryTile(icon: Icons.apple_rounded, label: 'Sadje & zelenjava', sub: 'Sveže iz vrta ali kmetije...', color: const Color(0xFF00897B), bgColor: const Color(0xFFE0F2F1)),
      ]),
    );
  }
}

class _AddCategoryTile extends StatelessWidget {
  final IconData icon; final String label, sub; final Color color, bgColor;
  const _AddCategoryTile({required this.icon, required this.label, required this.sub, required this.color, required this.bgColor});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dodajanje: $label — prihaja kmalu!'))); },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: kRadius12,
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: kRadius12,
              boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: kBodyBold), const SizedBox(height: 2), Text(sub, style: kCaption),
          ])),
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: kRadius8),
            child: Icon(Icons.chevron_right_rounded, color: color, size: 18)),
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
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: kRadius12,
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
    ));
  }
}

// ── Avatar button ─────────────────────────────────────────────────────────────
class _AvatarButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _AvatarButton({this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      decoration: BoxDecoration(shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4))]),
      child: CircleAvatar(radius: 19, backgroundColor: Colors.white,
        child: Text('U', style: TextStyle(fontWeight: FontWeight.w900, color: kGreenMid, fontSize: 16))),
    ));
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon; final String value, label; final Color iconColor, bgColor;
  const _StatCard({required this.icon, required this.value, required this.label, required this.iconColor, required this.bgColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        boxShadow: [
          BoxShadow(color: iconColor.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 5)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: bgColor, borderRadius: kRadius8),
          child: Icon(icon, size: 17, color: iconColor)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: iconColor)),
          Text(label, style: kCaption.copyWith(fontSize: 10), overflow: TextOverflow.ellipsis),
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
          decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: kGreenMid.withOpacity(0.15), blurRadius: 32, offset: const Offset(0, 8))]),
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
// Heatmap preview card
// ══════════════════════════════════════════════════════════════════════════════
class HeatmapPreviewCard extends StatelessWidget {
  final VoidCallback? onTap;
  const HeatmapPreviewCard({super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 170,
      decoration: BoxDecoration(
        borderRadius: kRadius16,
        boxShadow: [
          BoxShadow(color: const Color(0xFF1B5E20).withOpacity(0.3), blurRadius: 28, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(borderRadius: kRadius16, child: Stack(fit: StackFit.expand, children: [
        const _MockMapBackground(),
        const _HeatmapDots(),
        Container(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
          stops: const [0.3, 1.0],
        ))),
        Positioned(left: 16, bottom: 16, right: 60, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kGreenAccent, borderRadius: kRadiusFull),
              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
            const SizedBox(width: 8),
            const Flexible(child: Text('Toplotna karta hrane',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text('${kSampleOglasi.length} aktivnih oglasov v Mariboru',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
        ])),
        Positioned(right: 14, bottom: 14, child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: kRadiusFull,
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16),
        )),
      ])),
    ));
  }
}

class _MockMapBackground extends StatelessWidget {
  const _MockMapBackground();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _MapGridPainter(), child: Container(color: const Color(0xFF1A3A2A)));
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
        canvas.drawCircle(Offset(cx,cy), r, Paint()..shader = RadialGradient(colors:[const Color(0xFF4CAF50).withOpacity(op+0.05),Colors.transparent]).createShader(Rect.fromCircle(center: Offset(cx,cy), radius: r)));
      }
      canvas.drawCircle(Offset(cx,cy), 3.5, Paint()..color = kGreenAccent.withOpacity(0.9*p));
    }
  }
  @override bool shouldRepaint(_HeatmapPainter o) => o.p != p;
}

// ══════════════════════════════════════════════════════════════════════════════
// Full heatmap page
// ══════════════════════════════════════════════════════════════════════════════
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
        Positioned.fill(child: AnimatedBuilder(animation: _p, builder: (_, __) => CustomPaint(painter: _FullMapPainter(_hs, _p.value)))),
        SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: kRadius12,
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
            const SizedBox(width: 12),
            const Text('Toplotna karta', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kGreenAccent.withOpacity(0.9),
                borderRadius: kRadiusFull,
                boxShadow: [BoxShadow(color: kGreenAccent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                const Icon(Icons.circle, color: Colors.white, size: 8), const SizedBox(width: 4),
                Text('${kSampleOglasi.length} aktivnih', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ])),
          ]),
        )),
        Positioned(left: 0, right: 0, bottom: 0, child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull)),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Razporeditev hrane', style: kHeading3),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadiusFull,
                  boxShadow: [BoxShadow(color: kGreenMid.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]),
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
              onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prikazujem bližnje oglase...'))); },
              icon: const Icon(Icons.my_location_rounded, size: 16),
              label: const Text('Pokaži bližnje oglase'),
              style: OutlinedButton.styleFrom(foregroundColor: kGreenMid, side: const BorderSide(color: kGreenMid, width: 1.5),
                shape: const RoundedRectangleBorder(borderRadius: kRadius12), padding: const EdgeInsets.symmetric(vertical: 13)),
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
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 1))])),
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
        canvas.drawCircle(Offset(cx,cy), r, Paint()..shader = RadialGradient(colors:[const Color(0xFF4CAF50).withOpacity(op+0.04),Colors.transparent]).createShader(Rect.fromCircle(center: Offset(cx,cy), radius: r)));
      }
      canvas.drawCircle(Offset(cx,cy), 4.5, Paint()..color = kGreenAccent.withOpacity(0.95*p));
    }
  }
  @override bool shouldRepaint(_FullMapPainter o) => o.p != p;
}

// ── Shranjeno sheet ───────────────────────────────────────────────────────────
class _ShranjenoSheet extends StatelessWidget {
  const _ShranjenoSheet();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull))),
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
          const SizedBox(height: 4),
          const Text('Tapni ikono za shranjevanje oglasa', style: TextStyle(color: kTextLight, fontSize: 12)),
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
    // Mock rezervacije — zamijeni s Firebase podacima
    final rezervacije = kSampleOglasi.where((o) => o.status == OglasStatus.rezervirano).toList();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(0, 20, 0, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull))),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(color: kOrangePale, borderRadius: kRadius12),
              child: const Icon(Icons.bookmark_added_rounded, color: kOrange, size: 22)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Moje rezervacije', style: kHeading2),
              Text('${rezervacije.length} aktivnih rezervacij', style: kBody),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        if (rezervacije.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Column(children: [
              Icon(Icons.inbox_outlined, size: 48, color: kBorder),
              const SizedBox(height: 8),
              const Text('Ni aktivnih rezervacij', style: TextStyle(color: kTextLight, fontSize: 14)),
            ])),
          )
        else
          ...rezervacije.map((o) => Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kOrangePale,
              borderRadius: kRadius12,
              border: Border.all(color: kOrange.withOpacity(0.25)),
            ),
            child: Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: o.imageColor, borderRadius: kRadius12),
                child: Icon(o.icon, color: kGreenMid, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.title, style: kBodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(o.location, style: kCaption),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: kOrange.withOpacity(0.15), borderRadius: kRadiusFull,
                  border: Border.all(color: kOrange.withOpacity(0.4))),
                child: const Text('REZERVIRANO', style: TextStyle(color: kOrange, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ]),
          )),
        const SizedBox(height: 8),
      ]),
    );
  }
}