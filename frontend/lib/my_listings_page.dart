import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';

// ── My Listings Page ──────────────────────────────────────────────────────────
class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key});

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sample user's own listings — in real app, filter by current user ID
  final List<FoodOglas> _myListings = kSampleOglasi.take(4).toList();

  List<FoodOglas> get _active =>
      _myListings.where((o) => !o.isExpiringSoon).toList();
  List<FoodOglas> get _expiring =>
      _myListings.where((o) => o.isExpiringSoon).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStatsRow(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildListingsList(_myListings),
                  _buildListingsList(_active),
                  _buildListingsList(_expiring),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
            child: const Icon(Icons.list_alt_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jan Novak',
                  style: TextStyle(fontSize: 11, color: kTextLight)),
              Text('Moji oglasi', style: kHeading2),
            ],
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: kRadiusFull,
              border: Border.all(color: kBorder),
              boxShadow: kCardShadow,
            ),
            child: Row(
              children: const [
                Icon(Icons.sort_rounded, color: kGreenMid, size: 13),
                SizedBox(width: 4),
                Text(
                  'Razvrsti',
                  style: TextStyle(
                    fontSize: 11,
                    color: kGreenMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: '${_myListings.length}',
              label: 'Skupaj',
              icon: Icons.grid_view_rounded,
              color: kGreenMid,
              bgColor: kGreenPale,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '${_active.length}',
              label: 'Aktivnih',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF2196F3),
              bgColor: const Color(0xFFE3F2FD),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '${_expiring.length}',
              label: 'Potekajoči',
              icon: Icons.timer_outlined,
              color: kOrange,
              bgColor: kOrangePale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          border: Border.all(color: kBorder),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kGreenMid, kGreen],
            ),
            borderRadius: kRadius8,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: kTextLight,
          labelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Vsi'),
            Tab(text: 'Aktivni'),
            Tab(text: 'Potekajoči'),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsList(List<FoodOglas> listings) {
    if (listings.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: listings.length,
      itemBuilder: (context, i) => _MyListingCard(
        oglas: listings[i],
        onDelete: () => setState(() => _myListings.remove(listings[i])),
        onEdit: () {},
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kGreenPale,
                borderRadius: kRadiusFull,
              ),
              child: const Icon(Icons.inbox_outlined,
                  color: kGreenMid, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Ni oglasov',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kTextDark)),
            const SizedBox(height: 6),
            const Text(
              'Dodajte prvi oglas in pomagajte zmanjšati zavrženo hrano',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kTextLight),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        border: Border.all(color: kBorder),
        boxShadow: kCardShadow,
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
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color),
              ),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 10,
                    color: kTextLight,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── My Listing Card ───────────────────────────────────────────────────────────
class _MyListingCard extends StatelessWidget {
  final FoodOglas oglas;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _MyListingCard({
    required this.oglas,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius16,
        border: Border.all(color: kBorder),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: oglas.imageColor,
                    borderRadius: kRadius12,
                  ),
                  child: Center(
                    child: Icon(oglas.icon, size: 32, color: kTextMid),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              oglas.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kTextDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: kTextLight),
                          const SizedBox(width: 2),
                          Text(
                            oglas.location,
                            style: const TextStyle(
                                fontSize: 11, color: kTextLight),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildPriceBadge(),
                          const SizedBox(width: 6),
                          _buildTimeBadge(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Stats bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _buildMiniStat(
                    Icons.visibility_outlined, '24', 'ogledov'),
                _buildDivider(),
                _buildMiniStat(
                    Icons.favorite_border_rounded, '3', 'všeček'),
                _buildDivider(),
                _buildMiniStat(
                    Icons.chat_bubble_outline_rounded, '1', 'sporočil'),
                const Spacer(),
                // Action buttons
                _buildActionBtn(
                  Icons.edit_outlined,
                  kGreenMid,
                  kGreenPale,
                  onEdit,
                ),
                const SizedBox(width: 6),
                _buildActionBtn(
                  Icons.delete_outline_rounded,
                  kOrange,
                  kOrangePale,
                  () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isExp = oglas.isExpiringSoon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isExp ? kOrangePale : kGreenPale,
        borderRadius: kRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isExp ? kOrange : kGreenMid,
              borderRadius: kRadiusFull,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isExp ? 'Potekajoč' : 'Aktiven',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isExp ? kOrange : kGreenMid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: oglas.isFree ? kGreenPale : Colors.grey.shade100,
        borderRadius: kRadius8,
      ),
      child: Text(
        oglas.isFree ? 'BREZPLAČNO' : 'PLAČLJIVO',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: oglas.isFree ? kGreenMid : kTextMid,
        ),
      ),
    );
  }

  Widget _buildTimeBadge() {
    return Row(
      children: [
        Icon(
          Icons.access_time_rounded,
          size: 11,
          color: oglas.isExpiringSoon ? kOrange : kTextLight,
        ),
        const SizedBox(width: 2),
        Text(
          oglas.time,
          style: TextStyle(
            fontSize: 11,
            color: oglas.isExpiringSoon ? kOrange : kTextLight,
            fontWeight: oglas.isExpiringSoon
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(IconData icon, String count, String label) {
    return Row(
      children: [
        Icon(icon, size: 13, color: kTextLight),
        const SizedBox(width: 3),
        Text(
          count,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kTextMid),
        ),
        const SizedBox(width: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: kTextLight)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: kBorder,
    );
  }

  Widget _buildActionBtn(
    IconData icon,
    Color color,
    Color bg,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: kRadius8,
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: kRadiusFull,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: kOrangePale,
                borderRadius: kRadiusFull,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: kOrange, size: 28),
            ),
            const SizedBox(height: 14),
            const Text('Izbriši oglas?',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kTextDark)),
            const SizedBox(height: 6),
            const Text(
              'Ta oglas bo trajno izbrisan in ga ne boste mogli obnoviti.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kTextLight),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: kRadius12),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Prekliči',
                        style: TextStyle(
                            color: kTextMid,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: kRadius12),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Izbriši',
                        style: TextStyle(
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}