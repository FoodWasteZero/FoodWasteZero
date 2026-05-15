import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';
import 'widgets.dart';
import 'heatmap_widget.dart';
import 'ai_chef_widget.dart';
import 'profile_page.dart';
import 'add_listing_page.dart';   // ← NOVO
import 'my_listings_page.dart';   // ← NOVO

// ── Root scaffold with bottom nav ─────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    _HomePage(),
    AddListingPage(),   
    MyListingsPage(),   
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: _pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: AiChefFab(),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Domov',
                index: 0,
                current: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
              ),
              _NavItem(
                icon: Icons.add_circle_outline,
                activeIcon: Icons.add_circle,
                label: 'Dodaj',
                index: 1,
                current: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
              ),
              _NavItem(
                icon: Icons.list_alt_outlined,
                activeIcon: Icons.list_alt_rounded,
                label: 'Moji Oglasi',
                index: 2,
                current: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
                index: 3,
                current: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom nav item ───────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kGreenPale : Colors.transparent,
          borderRadius: kRadiusFull,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? activeIcon : icon,
              color: active ? kGreenMid : kTextLight,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: active ? kGreenMid : kTextLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Home / Dashboard page ─────────────────────────────────────────────────────
class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  String _activeFilter = 'Vse';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FoodOglas> get _filtered {
    var list = List<FoodOglas>.from(kSampleOglasi);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((o) =>
              o.title.toLowerCase().contains(q) ||
              o.location.toLowerCase().contains(q))
          .toList();
    }
    switch (_activeFilter) {
      case 'V bližini':
        list = list.where((o) => o.distanceKm <= 1.0).toList();
        break;
      case 'Brezplačno':
        list = list.where((o) => o.isFree).toList();
        break;
      case 'Kmalu poteče':
        list = list.where((o) => o.isExpiringSoon).toList();
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                child: const HeatmapPreviewCard(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: FilterChipsRow(
                onFilterChanged: (f) => setState(() => _activeFilter = f),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Row(
                  children: [
                    const Text('Oglasi za hrano', style: kHeading3),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kGreenPale,
                        borderRadius: kRadiusFull,
                      ),
                      child: Text(
                        '${_filtered.length} oglasov',
                        style: const TextStyle(
                          color: kGreenMid,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _filtered.isEmpty
                ? SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    sliver: SliverToBoxAdapter(child: _buildEmptyState()),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => FoodCard(oglas: _filtered[i]),
                        childCount: _filtered.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kGreenMid, kGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: kRadius8,
              boxShadow: kElevatedShadow,
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zdravo, Jan 👋',
                style: TextStyle(
                  fontSize: 12,
                  color: kTextLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'FoodWasteZero',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: kGreenMid,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: kRadiusFull,
              border: Border.all(color: kBorder),
              boxShadow: kCardShadow,
            ),
            child: Row(
              children: const [
                Icon(Icons.location_on, color: kGreenMid, size: 13),
                SizedBox(width: 3),
                Text(
                  'Maribor',
                  style: TextStyle(
                    fontSize: 11,
                    color: kGreenMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: kRadius12,
                  boxShadow: kCardShadow,
                ),
                child: const Icon(Icons.notifications_outlined,
                    color: kTextMid, size: 20),
              ),
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: kOrange,
                    borderRadius: kRadiusFull,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          border: Border.all(color: kBorder),
          boxShadow: kCardShadow,
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search, color: kTextLight, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'Išči hrano v okolici...',
                  hintStyle: TextStyle(color: kTextLight, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14, color: kTextDark),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.close, color: kTextLight, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 56, color: kBorder),
          const SizedBox(height: 12),
          const Text(
            'Ni rezultatov',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kTextMid,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Poskusite z drugimi filtri ali iskanjem',
            style: TextStyle(fontSize: 13, color: kTextLight),
          ),
        ],
      ),
    );
  }
}