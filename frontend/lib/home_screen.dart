import 'package:flutter/material.dart';

// ── Data model ──────────────────────────────────────────────────────────────

enum OglasStatus { naRazpolago, rezervirano, prevzeto }

class FoodOglas {
  final String title;
  final String location;
  final String time;
  final OglasStatus status;
  final String? username;
  final Color imageColor; // placeholder barva namesto prave slike

  const FoodOglas({
    required this.title,
    required this.location,
    required this.time,
    required this.status,
    this.username,
    required this.imageColor,
  });
}

// ── Sample data ──────────────────────────────────────────────────────────────

const List<FoodOglas> _oglasi = [
  FoodOglas(
    title: 'Domača jabolka z vrta (cca 5kg)',
    location: 'Maribor, Center',
    time: 'Pred 32 min',
    status: OglasStatus.naRazpolago,
    imageColor: Color(0xFFE8F5E9),
  ),
  FoodOglas(
    title: 'Polna posoda Golaža',
    location: 'Tezno, Maribor',
    time: 'Pred 1 uro',
    status: OglasStatus.rezervirano,
    username: '@AnaMarija',
    imageColor: Color(0xFFFFE0B2),
  ),
  FoodOglas(
    title: 'Svež domač kmečki kruh (polovica)',
    location: 'Hoče',
    time: 'Pred 2 urama',
    status: OglasStatus.prevzeto,
    username: '@LukaP',
    imageColor: Color(0xFFEFEBE9),
  ),
  FoodOglas(
    title: 'Ostanki kosila: Rižota s piščancem',
    location: 'Center, Maribor',
    time: 'Pred 3 urama',
    status: OglasStatus.naRazpolago,
    imageColor: Color(0xFFF9FBE7),
  ),
];

// ── Colours & helpers ────────────────────────────────────────────────────────

const _green = Color(0xFF2E7D32);
const _greenLight = Color(0xFF4CAF50);

Color _statusColor(OglasStatus s) {
  switch (s) {
    case OglasStatus.naRazpolago:
      return _greenLight;
    case OglasStatus.rezervirano:
      return const Color(0xFFFFA726);
    case OglasStatus.prevzeto:
      return const Color(0xFF78909C);
  }
}

String _statusLabel(OglasStatus s) {
  switch (s) {
    case OglasStatus.naRazpolago:
      return 'NA RAZPOLAGO';
    case OglasStatus.rezervirano:
      return 'REZERVIRANO';
    case OglasStatus.prevzeto:
      return 'PREVZETO';
  }
}

// ── Placeholder food icon per oglas ─────────────────────────────────────────

IconData _placeholderIcon(int index) {
  const icons = [
    Icons.apple,
    Icons.soup_kitchen,
    Icons.bakery_dining,
    Icons.rice_bowl,
  ];
  return icons[index % icons.length];
}

// ── Screens ──────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    _OglasiPage(),
    _PlaceholderPage(label: 'Dodaj oglas'),
    _PlaceholderPage(label: 'Moji oglasi'),
    _PlaceholderPage(label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _green,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Domov'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), activeIcon: Icon(Icons.add_circle), label: 'Dodaj'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'Moji Oglasi'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// ── Oglasi page ───────────────────────────────────────────────────────────────

class _OglasiPage extends StatelessWidget {
  const _OglasiPage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Oglasi za hrano',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _oglasi.length,
              itemBuilder: (ctx, i) => _OglasCard(oglas: _oglasi[i], index: i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // Logo
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          const Text(
            'FoodWasteZero',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _green,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          const Icon(Icons.location_on, color: _green, size: 16),
          const SizedBox(width: 2),
          const Text(
            'Maribor',
            style: TextStyle(fontSize: 14, color: _green, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                  const SizedBox(width: 6),
                  Text('Išči hrano...', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _green),
            ),
            child: Row(
              children: const [
                Icon(Icons.tune, color: _green, size: 18),
                SizedBox(width: 4),
                Text('Filter', style: TextStyle(color: _green, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Oglas card ────────────────────────────────────────────────────────────────

class _OglasCard extends StatelessWidget {
  final FoodOglas oglas;
  final int index;

  const _OglasCard({required this.oglas, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 130),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image placeholder
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: Container(
              width: 150,
              height: 180,
              color: oglas.imageColor,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (oglas.username != null) ...[
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: _green.withOpacity(0.2),
                      child: const Icon(Icons.person, size: 14, color: _green),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      oglas.username!,
                      style: const TextStyle(fontSize: 9, color: _green, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Icon(_placeholderIcon(index), size: 36, color: _green.withOpacity(0.7)),
                ],
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    oglas.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _infoRow(Icons.location_on_outlined, oglas.location),
                  const SizedBox(height: 3),
                  _infoRow(Icons.access_time_outlined, oglas.time),
                  const SizedBox(height: 8),
                  _StatusBadge(status: oglas.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final OglasStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Placeholder pages ─────────────────────────────────────────────────────────

class _PlaceholderPage extends StatelessWidget {
  final String label;

  const _PlaceholderPage({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(fontSize: 20, color: Colors.grey),
      ),
    );
  }
}