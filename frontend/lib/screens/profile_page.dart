import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../models/models.dart';
import 'recipe_suggestions_page.dart';

// ══════════════════════════════════════════════════════════════════════════════
// profile_page.dart
// Place at: lib/screens/profile_page.dart
// ══════════════════════════════════════════════════════════════════════════════

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final List<ClaimedItem> _items = List.from(kSampleClaimedItems);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<ClaimedItem> get _cooked =>
      _items.where((i) => i.type == 'Kuhano').toList();

  List<ClaimedItem> get _ingredients =>
      _items.where((i) => i.type == 'Sestavine').toList();

  List<ClaimedItem> get _selectedIngredients =>
      _ingredients.where((i) => i.isSelected).toList();

  void _deleteSelected() {
    setState(() => _items.removeWhere((i) => i.isSelected));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sestavine odstranjene')),
    );
  }

  void _useSelected() {
    final selected = _selectedIngredients.map((i) => i.name).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeSuggestionsPage(ingredients: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildProfileHeader()),
            SliverToBoxAdapter(child: _buildStatsGrid()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: const Text('Moja zahtevana hrana', style: kHeading2),
              ),
            ),
            SliverToBoxAdapter(child: _buildTabBar()),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 400,
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildCookedTab(),
                    _buildIngredientsTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile header ──────────────────────────────────────────────────────────
  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kGreenMid, kGreen],
        ),
        borderRadius: kRadius16,
        boxShadow: kElevatedShadow,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: kRadiusFull,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child:
                    const Icon(Icons.person, color: Colors.white, size: 34),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: kGreenAccent,
                    borderRadius: kRadiusFull,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jan Novak',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                const Text(
                  'jan.novak@email.com',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: kRadiusFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.workspace_premium,
                          color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Zeleni Heroj',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: kRadius8,
              ),
              child: const Icon(Icons.edit_outlined,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats grid ──────────────────────────────────────────────────────────────
  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Moj vpliv', style: kHeading3),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: [
              _ProfileStatCard(
                icon: Icons.scale,
                value: '12.4',
                label: 'kg hrane\nrešene',
                color: kGreenMid,
              ),
              _ProfileStatCard(
                icon: Icons.co2,
                value: '8.3',
                label: 'kg CO₂\nprihranjenega',
                color: const Color(0xFF00897B),
              ),
              _ProfileStatCard(
                icon: Icons.restaurant,
                value: '27',
                label: 'obrokov\nrešenih',
                color: kOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        boxShadow: kCardShadow,
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: kGreenMid,
          borderRadius: kRadius12,
          boxShadow: kElevatedShadow,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: kTextMid,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.soup_kitchen, size: 15),
                SizedBox(width: 5),
                Text('Kuhano'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.grass, size: 15),
                SizedBox(width: 5),
                Text('Sestavine'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cooked tab ──────────────────────────────────────────────────────────────
  Widget _buildCookedTab() {
    if (_cooked.isEmpty) {
      return _buildEmptyState('Ni kuhanih obrokov', Icons.soup_kitchen);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      itemCount: _cooked.length,
      itemBuilder: (_, i) =>
          _ClaimedCard(item: _cooked[i], showActions: false),
    );
  }

  // ── Ingredients tab ─────────────────────────────────────────────────────────
  Widget _buildIngredientsTab() {
    return Column(
      children: [
        if (_selectedIngredients.isNotEmpty) _buildActionBar(),
        Expanded(
          child: _ingredients.isEmpty
              ? _buildEmptyState('Ni sestavin', Icons.grass)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  itemCount: _ingredients.length,
                  itemBuilder: (_, i) => _ClaimedCard(
                    item: _ingredients[i],
                    showActions: true,
                    onToggle: () => setState(
                      () => _ingredients[i].isSelected =
                          !_ingredients[i].isSelected,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Action bar (shown when ingredients are selected) ────────────────────────
  Widget _buildActionBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kGreenPale,
        borderRadius: kRadius12,
        border: Border.all(color: kGreenMid.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedIngredients.length} izbrano',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: kGreenMid,
                fontSize: 13),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _deleteSelected,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: kRadiusFull,
                border:
                    Border.all(color: const Color(0xFFEF5350)),
              ),
              child: const Text(
                'Izbriši',
                style: TextStyle(
                    color: Color(0xFFEF5350),
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _useSelected,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: kGreenMid,
                borderRadius: kRadiusFull,
                boxShadow: kElevatedShadow,
              ),
              child: const Text(
                'Uporabi',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String label, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: kBorder),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: kTextLight, fontSize: 14)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ProfileStatCard — private to this screen (mirrors _StatCard in HomeScreen)
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _ProfileStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        boxShadow: kCardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: kRadius8,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color),
          ),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 10, color: kTextLight)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ClaimedCard — card for a single claimed item
// ══════════════════════════════════════════════════════════════════════════════
class _ClaimedCard extends StatelessWidget {
  final ClaimedItem item;
  final bool showActions;
  final VoidCallback? onToggle;

  const _ClaimedCard({
    required this.item,
    required this.showActions,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: showActions ? onToggle : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isSelected && showActions ? kGreenPale : kCard,
          borderRadius: kRadius12,
          border: Border.all(
            color: item.isSelected && showActions
                ? kGreenMid.withOpacity(0.5)
                : kBorder,
          ),
          boxShadow: kCardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: kRadius12,
              ),
              child: Icon(item.icon, color: kGreenMid, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: kBodyBold),
                  Text(item.quantity, style: kCaption),
                ],
              ),
            ),
            if (showActions)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: item.isSelected ? kGreenMid : Colors.transparent,
                  borderRadius: kRadiusFull,
                  border: Border.all(
                    color: item.isSelected ? kGreenMid : kBorder,
                    width: 2,
                  ),
                ),
                child: item.isSelected
                    ? const Icon(Icons.check,
                        color: Colors.white, size: 14)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}