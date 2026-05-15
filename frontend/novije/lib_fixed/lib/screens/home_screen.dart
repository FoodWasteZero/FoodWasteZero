import 'dart:math';
import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../cards/food_card.dart';
import 'profile_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;
  int _navIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  static const _tabs = ['Vse','Kuhano','Sestavine','Peka','Sadje & zelenjava'];

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
      floatingActionButton: _navIndex == 0 ? _buildFAB() : null,
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
        SliverToBoxAdapter(child: _buildHeatmapSection()),
        SliverToBoxAdapter(child: _buildListingsHeader()),
        SliverToBoxAdapter(child: _buildTabRow()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          sliver: _filtered.isEmpty
              ? const SliverToBoxAdapter(child: _EmptyState())
              : SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => FoodCard(oglas: _filtered[i]),
                  childCount: _filtered.length,
                )),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(IconData icon, String title, String sub) {
    return SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(28), decoration: const BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
        child: Icon(icon, size: 48, color: kGreenMid)),
      const SizedBox(height: 18),
      Text(title, style: kHeading2),
      const SizedBox(height: 8),
      Text(sub, style: kBody, textAlign: TextAlign.center),
    ])));
  }

  Widget _buildMyListings() {
    return SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(28), decoration: const BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
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
      expandedHeight: 120, pinned: true, elevation: 0,
      backgroundColor: Colors.white,
      shadowColor: Colors.black.withOpacity(0.08),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          )),
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: kRadiusFull),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.location_on, size: 11, color: Colors.white70),
                    SizedBox(width: 3),
                    Text('Maribor', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
                  ]),
                ),
                const SizedBox(height: 5),
                const Text('Hrana blizu tebe 🌿', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3)),
                const Text('Reši hrano. Pomagaj skupnosti.', style: TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w400)),
              ])),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(children: [
                  _NotifButton(onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ni novih obvestil')))),
                  const SizedBox(width: 8),
                  _AvatarButton(onTap: _goToProfile),
                ]),
              ]),
            ]),
          )),
        ),
      ),
      title: const Text('FoodWasteZero', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextDark, letterSpacing: -0.2)),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: kTextMid),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ni novih obvestil'))),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: kRadius12, boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 4)),
        ]),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          decoration: InputDecoration(
            hintText: 'Išči hrano...',
            hintStyle: kCaption.copyWith(fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: kGreenMid, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                    child: const Icon(Icons.close, color: kTextLight, size: 18))
                : Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: kGreenMid, borderRadius: kRadius8, boxShadow: [
                      BoxShadow(color: kGreenMid.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
                    ]),
                    child: const Icon(Icons.tune, color: Colors.white, size: 16)),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        _StatCard(icon: Icons.eco_outlined, value: '$_availableCount', label: 'Na voljo', iconColor: kGreenLight, bgColor: kGreenPale),
        const SizedBox(width: 10),
        _StatCard(icon: Icons.flash_on_outlined, value: '$_expiringSoonCount', label: 'Kmalu poteče', iconColor: kOrange, bgColor: kOrangePale),
        const SizedBox(width: 10),
        _StatCard(icon: Icons.handshake_outlined, value: '$_reservedCount', label: 'Rezervirano', iconColor: const Color(0xFF5C6BC0), bgColor: const Color(0xFFE8EAF6)),
      ]),
    );
  }

  Widget _buildHeatmapSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            const Text('Toplotna karta', style: kHeading3),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeatmapFullPage())),
              child: Text('Odpri celotno', style: kCaption.copyWith(color: kGreenMid, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        HeatmapPreviewCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeatmapFullPage()))),
      ]),
    );
  }

  Widget _buildListingsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(children: [
        const Text('Oglasi v bližini', style: kHeading3),
        const Spacer(),
        Text('${_filtered.length} rezultatov', style: kCaption.copyWith(color: kGreenMid, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildTabRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 36,
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
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? kGreenMid : Colors.white,
                  borderRadius: kRadiusFull,
                  boxShadow: active
                      ? [BoxShadow(color: kGreenMid.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]
                      : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Text(_tabs[i], style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? Colors.white : kTextMid)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(borderRadius: kRadius16, boxShadow: [
        BoxShadow(color: kGreenMid.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 8)),
      ]),
      child: FloatingActionButton.extended(
        onPressed: _showAddOglas,
        backgroundColor: kGreenMid, elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: kRadius16),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Dodaj oglas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -4)),
      ]),
      child: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        backgroundColor: Colors.transparent, elevation: 0,
        indicatorColor: kGreenPale,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: kGreenMid), label: 'Domov'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map, color: kGreenMid), label: 'Zemljevid'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox, color: kGreenMid), label: 'Moje'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: kGreenMid), label: 'Profil'),
        ],
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
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull))),
        const SizedBox(height: 20),
        const Text('Dodaj oglas', style: kHeading2),
        const SizedBox(height: 6),
        const Text('Kaj bi rad delil s skupnostjo?', style: kBody),
        const SizedBox(height: 20),
        _AddCategoryTile(icon: Icons.soup_kitchen, label: 'Kuhano', sub: 'Pripravljeni obroki, juhe, enolončnice...', color: kOrange, bgColor: kOrangePale),
        const SizedBox(height: 10),
        _AddCategoryTile(icon: Icons.grass, label: 'Sestavine', sub: 'Sadje, zelenjava, moka, jajca...', color: kGreenLight, bgColor: kGreenPale),
        const SizedBox(height: 10),
        _AddCategoryTile(icon: Icons.bakery_dining, label: 'Peka', sub: 'Kruh, kolači, pecivo...', color: const Color(0xFF8D6E63), bgColor: const Color(0xFFEFEBE9)),
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
        decoration: BoxDecoration(color: bgColor, borderRadius: kRadius12, border: Border.all(color: color.withOpacity(0.2))),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: kRadius12), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: kBodyBold), const SizedBox(height: 2), Text(sub, style: kCaption),
          ])),
          Icon(Icons.chevron_right, color: color, size: 20),
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
      width: 36, height: 36,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: kRadius12),
      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 18),
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
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
      ]),
      child: CircleAvatar(radius: 18, backgroundColor: Colors.white,
        child: Text('U', style: TextStyle(fontWeight: FontWeight.w800, color: kGreenMid, fontSize: 15))),
    ));
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon; final String value, label; final Color iconColor, bgColor;
  const _StatCard({required this.icon, required this.value, required this.label, required this.iconColor, required this.bgColor});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: kRadius12, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
      ]),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: bgColor, borderRadius: kRadius8), child: Icon(icon, size: 18, color: iconColor)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kTextDark)),
          Text(label, style: kCaption.copyWith(fontSize: 10), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    ));
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
        Container(padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle, boxShadow: [
            BoxShadow(color: kGreenMid.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8)),
          ]),
          child: const Icon(Icons.search_off, size: 40, color: kGreenMid)),
        const SizedBox(height: 16),
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
      height: 160,
      decoration: BoxDecoration(borderRadius: kRadius16, boxShadow: kCardShadow),
      child: ClipRRect(borderRadius: kRadius16, child: Stack(fit: StackFit.expand, children: [
        const _MockMapBackground(),
        const _HeatmapDots(),
        Container(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
        ))),
        Positioned(left: 16, bottom: 14, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kGreenAccent, borderRadius: kRadiusFull),
              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1))),
            const SizedBox(width: 8),
            const Text('Toplotna karta hrane', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 3),
          Text('${kSampleOglasi.length} aktivnih oglasov v Mariboru',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
        ])),
        Positioned(right: 14, bottom: 14, child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: kRadiusFull, border: Border.all(color: Colors.white.withOpacity(0.4))),
          child: const Icon(Icons.open_in_full, color: Colors.white, size: 16),
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
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: kRadius12),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20))),
            const SizedBox(width: 12),
            const Text('Toplotna karta', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: kGreenAccent.withOpacity(0.9), borderRadius: kRadiusFull),
              child: Row(children: [
                const Icon(Icons.circle, color: Colors.white, size: 8), const SizedBox(width: 4),
                Text('${kSampleOglasi.length} aktivnih', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ])),
          ]),
        )),
        Positioned(left: 0, right: 0, bottom: 0, child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Razporeditev hrane', style: kHeading3),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadiusFull),
                child: const Text('Maribor', style: TextStyle(color: kGreenMid, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _LegendDot(color: kGreenAccent, label: 'Visoka gostota'),
              const SizedBox(width: 16),
              _LegendDot(color: kGreenLight.withOpacity(0.6), label: 'Srednja gostota'),
              const SizedBox(width: 16),
              _LegendDot(color: kGreenLight.withOpacity(0.25), label: 'Nizka gostota'),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prikazujem bližnje oglase...'))); },
              icon: const Icon(Icons.my_location, size: 16),
              label: const Text('Pokaži bližnje oglase'),
              style: OutlinedButton.styleFrom(foregroundColor: kGreenMid, side: const BorderSide(color: kGreenMid), shape: const RoundedRectangleBorder(borderRadius: kRadius12), padding: const EdgeInsets.symmetric(vertical: 12)),
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
    const SizedBox(width: 4), Text(label, style: kCaption),
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
