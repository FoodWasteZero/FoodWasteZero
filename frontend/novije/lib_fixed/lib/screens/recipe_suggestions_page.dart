import 'dart:math';
import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../cards/food_card.dart';
import 'profile_page.dart'; // ← CHANGE 1: new import

// ══════════════════════════════════════════════════════════════════════════════
// home_screen.dart
// ══════════════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// CHANGE 2: _HomeScreenState now only owns _navIndex.
// _selectedTab and _filtered moved down into _HomeBodyState.
class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      // CHANGE 2: IndexedStack drives the four nav destinations.
      body: IndexedStack(
        index: _navIndex,
        children: const [
          _HomeBody(),                              // index 0 — feed
          _PlaceholderScreen(label: 'Zemljevid'),  // index 1
          _PlaceholderScreen(label: 'Moje'),       // index 2
          ProfilePage(),                           // index 3
        ],
      ),
      floatingActionButton: _navIndex == 0 ? _buildFAB() : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── FAB ─────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: kRadius16,
        boxShadow: [
          BoxShadow(
            color: kGreenMid.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: kGreenMid,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: kRadius16),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Dodaj oglas',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  // ── Bottom nav ──────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: kGreenPale,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: kGreenMid),
              label: 'Domov'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map, color: kGreenMid),
              label: 'Zemljevid'),
          NavigationDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox, color: kGreenMid),
              label: 'Moje'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: kGreenMid),
              label: 'Profil'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHANGE 3: _HomeBody — the original feed content extracted into its own widget
// ══════════════════════════════════════════════════════════════════════════════

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  int _selectedTab = 0;

  static const _tabs = [
    'Vse',
    'Kuhano',
    'Sestavine',
    'Peka',
    'Sadje & zelenjava',
  ];

  List<FoodOglas> get _filtered {
    if (_selectedTab == 0) return kSampleOglasi;
    final label = _tabs[_selectedTab];
    return kSampleOglasi.where((o) => o.category == label).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── 1. Collapsing header
        _buildSliverAppBar(),

        // ── 2. Search bar (below header, never overlaps)
        SliverToBoxAdapter(child: _buildSearchBar()),

        // ── 3. Stats row
        SliverToBoxAdapter(child: _buildStatsRow()),

        // ── 4. Live heatmap preview card
        SliverToBoxAdapter(child: _buildHeatmapSection()),

        // ── 5. Section header + category tabs
        SliverToBoxAdapter(child: _buildListingsHeader()),

        // ── 6. Category filter tabs
        SliverToBoxAdapter(child: _buildTabRow()),

        // ── 7. Food listings
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          sliver: _filtered.isEmpty
              ? const SliverToBoxAdapter(child: _EmptyState())
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => FoodCard(oglas: _filtered[i]),
                    childCount: _filtered.length,
                  ),
                ),
        ),
      ],
    );
  }

  // ── Sliver app bar ──────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      shadowColor: Colors.black.withOpacity(0.08),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Location pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: kRadiusFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.location_on,
                                  size: 11, color: Colors.white70),
                              SizedBox(width: 3),
                              Text('Maribor',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Hrana blizu tebe 🌿',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Text(
                          'Reši hrano. Pomagaj skupnosti.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                              fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  // Notification + Avatar — vertically centered
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          _NotifButton(),
                          const SizedBox(width: 8),
                          _AvatarButton(),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // Collapsed bar
      title: const Text(
        'FoodWasteZero',
        style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: kTextDark,
            letterSpacing: -0.2),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: kTextMid),
          onPressed: () {},
        ),
      ],
    );
  }

  // ── Search bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Išči hrano...',
            hintStyle: kCaption.copyWith(fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: kGreenMid, size: 20),
            suffixIcon: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kGreenMid,
                borderRadius: kRadius8,
                boxShadow: [
                  BoxShadow(
                    color: kGreenMid.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.tune, color: Colors.white, size: 16),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // ── Stats row ───────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.eco_outlined,
            value: '${kSampleOglasi.length}',
            label: 'Na voljo',
            iconColor: kGreenLight,
            bgColor: kGreenPale,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.flash_on_outlined,
            value: '2',
            label: 'Kmalu poteče',
            iconColor: kOrange,
            bgColor: kOrangePale,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.handshake_outlined,
            value: '1',
            label: 'Rezervirano',
            iconColor: const Color(0xFF5C6BC0),
            bgColor: const Color(0xFFE8EAF6),
          ),
        ],
      ),
    );
  }

  // ── Live heatmap section ────────────────────────────────────────────────────
  Widget _buildHeatmapSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                const Text('Toplotna karta', style: kHeading3),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HeatmapFullPage()),
                  ),
                  child: Text(
                    'Odpri celotno',
                    style: kCaption.copyWith(
                      color: kGreenMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          HeatmapPreviewCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HeatmapFullPage()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Listings header ─────────────────────────────────────────────────────────
  Widget _buildListingsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          const Text('Oglasi v bližini', style: kHeading3),
          const Spacer(),
          Text(
            '${_filtered.length} rezultatov',
            style: kCaption.copyWith(
                color: kGreenMid, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Category tabs ───────────────────────────────────────────────────────────
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? kGreenMid : Colors.white,
                  borderRadius: kRadiusFull,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: kGreenMid.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                ),
                child: Text(
                  _tabs[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : kTextMid,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHANGE 3: Placeholder for unbuilt nav tabs
// ══════════════════════════════════════════════════════════════════════════════

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: kHeading2),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Small private widgets used only in HomeScreen
// ══════════════════════════════════════════════════════════════════════════════

// ── Notification button ───────────────────────────────────────────────────────
class _NotifButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: kRadius12,
      ),
      child: const Icon(Icons.notifications_outlined,
          color: Colors.white, size: 18),
    );
  }
}

// ── Avatar button ─────────────────────────────────────────────────────────────
class _AvatarButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        child: Text(
          'U',
          style: TextStyle(
              fontWeight: FontWeight.w800, color: kGreenMid, fontSize: 15),
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color bgColor;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: kRadius8,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: kTextDark)),
                  Text(label,
                      style: kCaption.copyWith(fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kGreenPale,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kGreenMid.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.search_off, size: 40, color: kGreenMid),
          ),
          const SizedBox(height: 16),
          const Text('Ni zadetkov', style: kHeading3),
          const SizedBox(height: 6),
          const Text('V tej kategoriji ni oglasov.',
              style: kBody, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Heatmap widgets (from heatmap_widget.dart — inlined here so home_screen
// stays self-contained; move back to widgets/heatmap_widget.dart and import
// if you prefer to keep the files separate)
// ══════════════════════════════════════════════════════════════════════════════

// ── Heatmap preview card ──────────────────────────────────────────────────────
class HeatmapPreviewCard extends StatelessWidget {
  final VoidCallback? onTap;
  const HeatmapPreviewCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 160,
        decoration: BoxDecoration(
          borderRadius: kRadius16,
          boxShadow: kCardShadow,
        ),
        child: ClipRRect(
          borderRadius: kRadius16,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background map texture
              const _MockMapBackground(),
              // Animated heatmap dots
              const _HeatmapDots(),
              // Bottom gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
              ),
              // Text overlay
              Positioned(
                left: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kGreenAccent,
                            borderRadius: kRadiusFull,
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Toplotna karta hrane',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '23 aktivnih oglasov v Mariboru',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Expand arrow
              Positioned(
                right: 14,
                bottom: 14,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: kRadiusFull,
                    border:
                        Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.open_in_full,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mock map grid background ──────────────────────────────────────────────────
class _MockMapBackground extends StatelessWidget {
  const _MockMapBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapGridPainter(),
      child: Container(color: const Color(0xFF1A3A2A)),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A4A3A)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final roadPaint = Paint()
      ..color = const Color(0xFF3A5A4A)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height * 0.45),
        Offset(size.width, size.height * 0.45), roadPaint);
    canvas.drawLine(Offset(size.width * 0.35, 0),
        Offset(size.width * 0.35, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Animated heatmap dots ─────────────────────────────────────────────────────
class _HeatmapDots extends StatefulWidget {
  const _HeatmapDots();

  @override
  State<_HeatmapDots> createState() => _HeatmapDotsState();
}

class _HeatmapDotsState extends State<_HeatmapDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  static const _hotspots = [
    (0.2, 0.35, 3.0),
    (0.45, 0.25, 2.0),
    (0.6, 0.55, 4.0),
    (0.75, 0.3, 2.5),
    (0.3, 0.65, 1.5),
    (0.85, 0.7, 3.0),
    (0.15, 0.7, 2.0),
    (0.55, 0.75, 1.5),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => CustomPaint(
        painter: _HeatmapPainter(_hotspots, _pulse.value),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<(double, double, double)> hotspots;
  final double pulse;
  _HeatmapPainter(this.hotspots, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    for (final (rx, ry, intensity) in hotspots) {
      final cx = rx * size.width;
      final cy = ry * size.height;
      final baseR = intensity * 14.0 * pulse;

      for (int i = 3; i >= 0; i--) {
        final radius = baseR * (1 + i * 0.5);
        final opacity = 0.06 * (4 - i) * pulse;
        final grad = RadialGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(opacity + 0.05),
            Colors.transparent,
          ],
        );
        final paint = Paint()
          ..shader = grad.createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: radius));
        canvas.drawCircle(Offset(cx, cy), radius, paint);
      }

      canvas.drawCircle(
        Offset(cx, cy),
        3.5,
        Paint()..color = kGreenAccent.withOpacity(0.9 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.pulse != pulse;
}

// ══════════════════════════════════════════════════════════════════════════════
// Full heatmap screen
// ══════════════════════════════════════════════════════════════════════════════

class HeatmapFullPage extends StatefulWidget {
  const HeatmapFullPage({super.key});

  @override
  State<HeatmapFullPage> createState() => _HeatmapFullPageState();
}

class _HeatmapFullPageState extends State<HeatmapFullPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  static const _fullHotspots = [
    (0.2, 0.35, 3.5),
    (0.45, 0.25, 2.5),
    (0.6, 0.55, 5.0),
    (0.75, 0.3, 3.0),
    (0.3, 0.65, 2.0),
    (0.85, 0.7, 3.5),
    (0.15, 0.7, 2.5),
    (0.55, 0.75, 2.0),
    (0.4, 0.45, 4.0),
    (0.7, 0.15, 2.0),
    (0.25, 0.15, 1.5),
    (0.9, 0.4, 2.5),
    (0.1, 0.5, 3.0),
    (0.65, 0.85, 2.0),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A2A),
      body: Stack(
        children: [
          // Full-screen animated map
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => CustomPaint(
                painter: _FullMapPainter(_fullHotspots, _pulse.value),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: kRadius12,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Toplotna karta',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kGreenAccent.withOpacity(0.9),
                      borderRadius: kRadiusFull,
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 4),
                        Text('23 aktivnih',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom legend card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kBorder,
                      borderRadius: kRadiusFull,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Razporeditev hrane', style: kHeading3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kGreenPale,
                          borderRadius: kRadiusFull,
                        ),
                        child: const Text('Maribor',
                            style: TextStyle(
                                color: kGreenMid,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _LegendDot(color: kGreenAccent, label: 'Visoka gostota'),
                      const SizedBox(width: 16),
                      _LegendDot(
                          color: kGreenLight.withOpacity(0.6),
                          label: 'Srednja gostota'),
                      const SizedBox(width: 16),
                      _LegendDot(
                          color: kGreenLight.withOpacity(0.25),
                          label: 'Nizka gostota'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('Pokaži bližnje oglase'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kGreenMid,
                        side: const BorderSide(color: kGreenMid),
                        shape: const RoundedRectangleBorder(
                            borderRadius: kRadius12),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: kCaption),
      ],
    );
  }
}

class _FullMapPainter extends CustomPainter {
  final List<(double, double, double)> hotspots;
  final double pulse;
  _FullMapPainter(this.hotspots, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF2A4A3A)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final roadPaint = Paint()
      ..color = const Color(0xFF3A5A4A)
      ..strokeWidth = 5;
    canvas.drawLine(Offset(0, size.height * 0.45),
        Offset(size.width, size.height * 0.45), roadPaint);
    canvas.drawLine(Offset(size.width * 0.35, 0),
        Offset(size.width * 0.35, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.65, 0),
        Offset(size.width * 0.65, size.height), roadPaint);

    for (final (rx, ry, intensity) in hotspots) {
      final cx = rx * size.width;
      final cy = ry * size.height;
      final baseR = intensity * 22.0 * pulse;

      for (int i = 4; i >= 0; i--) {
        final radius = baseR * (1 + i * 0.45);
        final opacity = 0.05 * (5 - i) * pulse;
        final grad = RadialGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(opacity + 0.04),
            Colors.transparent,
          ],
        );
        final paint = Paint()
          ..shader = grad.createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: radius));
        canvas.drawCircle(Offset(cx, cy), radius, paint);
      }
      canvas.drawCircle(
        Offset(cx, cy),
        4.5,
        Paint()..color = kGreenAccent.withOpacity(0.95 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(_FullMapPainter old) => old.pulse != pulse;
}