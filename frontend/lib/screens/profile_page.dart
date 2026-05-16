import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/theme.dart';
import '../models/models.dart';
import 'recipe_suggestions_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final List<ClaimedItem> _items = List.from(kSampleClaimedItems);

  String _displayName = '';
  String _email = '';
  String _userType = 'uporabnik';
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _displayName = user.displayName ?? '';
      _email = user.email ?? '';
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _displayName = doc['ime'] ?? _displayName;
          _userType = doc['userType'] ?? 'uporabnik';
          _loadingUser = false;
        });
      } else {
        setState(() => _loadingUser = false);
      }
    } catch (_) {
      setState(() => _loadingUser = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  bool get _isDavatelj => _userType == 'davatelj';

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
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => RecipeSuggestionsPage(ingredients: selected)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildProfileHeader()),
            if (_isDavatelj)
              SliverToBoxAdapter(child: _buildStatsGrid()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  _isDavatelj ? 'Moji oglasi' : 'Moja zahtevana hrana',
                  style: kHeading2,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildTabBar()),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 400,
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [_buildCookedTab(), _buildIngredientsTab()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _displayName.isEmpty ? 'Uporabnik' : _displayName;
    final badge = _isDavatelj ? 'Davatelj hrane' : 'Iskač hrane';
    final badgeIcon = _isDavatelj
        ? Icons.volunteer_activism_rounded
        : Icons.search_rounded;

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
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: kRadiusFull,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 34),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 18, height: 18,
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
            child: _loadingUser
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white60, strokeWidth: 2))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(_email,
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: kRadiusFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(badge,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          // Logout
          GestureDetector(
            onTap: _logout,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: kRadius12,
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Moj vpliv', style: kHeading3),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ProfileStatCard(
                icon: Icons.scale_rounded, value: '12.4',
                label: 'kg hrane\nrešene',
                gradientColors: const [Color(0xFF1B5E20), Color(0xFF43A047)],
                shadowColor: const Color(0xFF2E7D32),
              )),
              const SizedBox(width: 10),
              Expanded(child: _ProfileStatCard(
                icon: Icons.co2_rounded, value: '8.3',
                label: 'kg CO\u2082\nprihranjenega',
                gradientColors: const [Color(0xFF00695C), Color(0xFF26A69A)],
                shadowColor: const Color(0xFF00897B),
              )),
              const SizedBox(width: 10),
              Expanded(child: _ProfileStatCard(
                icon: Icons.restaurant_rounded, value: '27',
                label: 'obrokov\nrešenih',
                gradientColors: const [Color(0xFFE65100), Color(0xFFFFA726)],
                shadowColor: const Color(0xFFFF6F00),
              )),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: kRadius12, boxShadow: kCardShadow),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
            color: kGreenMid, borderRadius: kRadius12, boxShadow: kElevatedShadow),
        labelColor: Colors.white,
        unselectedLabelColor: kTextMid,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Icon(Icons.soup_kitchen, size: 15), SizedBox(width: 5), Text('Kuhano')])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Icon(Icons.grass, size: 15), SizedBox(width: 5), Text('Sestavine')])),
        ],
      ),
    );
  }

  Widget _buildCookedTab() {
    if (_cooked.isEmpty) return _buildEmptyState('Ni kuhanih obrokov', Icons.soup_kitchen);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      itemCount: _cooked.length,
      itemBuilder: (_, i) => _ClaimedCard(item: _cooked[i], showActions: false),
    );
  }

  Widget _buildIngredientsTab() {
    return Column(children: [
      if (_selectedIngredients.isNotEmpty) _buildActionBar(),
      Expanded(
        child: _ingredients.isEmpty
            ? _buildEmptyState('Ni sestavin', Icons.grass)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                itemCount: _ingredients.length,
                itemBuilder: (_, i) => _ClaimedCard(
                  item: _ingredients[i], showActions: true,
                  onToggle: () => setState(
                      () => _ingredients[i].isSelected = !_ingredients[i].isSelected),
                ),
              ),
      ),
    ]);
  }

  Widget _buildActionBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kGreenPale, borderRadius: kRadius12,
        border: Border.all(color: kGreenMid.withOpacity(0.3)),
      ),
      child: Row(children: [
        Text('${_selectedIngredients.length} izbrano',
            style: const TextStyle(fontWeight: FontWeight.w700, color: kGreenMid, fontSize: 13)),
        const Spacer(),
        GestureDetector(
          onTap: _deleteSelected,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: kRadiusFull,
              border: Border.all(color: const Color(0xFFEF5350))),
            child: const Text('Izbriši',
                style: TextStyle(color: Color(0xFFEF5350), fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _useSelected,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: kGreenMid, borderRadius: kRadiusFull, boxShadow: kElevatedShadow),
            child: const Text('Uporabi',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmptyState(String label, IconData icon) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 48, color: kBorder),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: kTextLight, fontSize: 14)),
    ]));
  }
}

class _ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> gradientColors;
  final Color shadowColor;

  const _ProfileStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.gradientColors,
    required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: kRadius12,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: shadowColor.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            borderRadius: kRadius8,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.85),
            height: 1.3,
          ),
        ),
      ]),
    );
  }
}

class _ClaimedCard extends StatelessWidget {
  final ClaimedItem item;
  final bool showActions;
  final VoidCallback? onToggle;
  const _ClaimedCard({required this.item, required this.showActions, this.onToggle});

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
            color: item.isSelected && showActions ? kGreenMid.withOpacity(0.5) : kBorder),
          boxShadow: kCardShadow,
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: item.color, borderRadius: kRadius12),
            child: Icon(item.icon, color: kGreenMid, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: kBodyBold),
            Text(item.quantity, style: kCaption),
          ])),
          if (showActions)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: item.isSelected ? kGreenMid : Colors.transparent,
                borderRadius: kRadiusFull,
                border: Border.all(color: item.isSelected ? kGreenMid : kBorder, width: 2)),
              child: item.isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
        ]),
      ),
    );
  }
}