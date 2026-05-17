// lib/screens/mine_screen.dart
//build empty zacasno zakomentiran da vidim kak dela - more bit davatelj drugace
//gumb za nov oglas zgine ko naredi oglas? fix fix
// Samostojna stran "Moje" — izločena iz home_screen.dart.
// Prikazuje userjeve oglase iz Firestora + gumb/forma za dodajanje.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../cards/food_card.dart';
import '../cards/food_detail_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper: Firestore doc → FoodOglas
// ─────────────────────────────────────────────────────────────────────────────
FoodOglas _docToOglasMoje(DocumentSnapshot doc) {
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
      icon = Icons.soup_kitchen_rounded;
      color = const Color(0xFFFFE0B2);
      break;
    case 'Peka':
      icon = Icons.bakery_dining_rounded;
      color = const Color(0xFFEFEBE9);
      break;
    case 'Sadje & zelenjava':
      icon = Icons.apple_rounded;
      color = const Color(0xFFE8F5E9);
      break;
    default:
      icon = Icons.grass_rounded;
      color = const Color(0xFFF1F8E9);
  }

  double distKm = 1.0;
  final lat = (d['lat'] as num?)?.toDouble();
  final lng = (d['lng'] as num?)?.toDouble();
  if (lat != null && lng != null) {
    const refLat = 46.5547;
    const refLng = 15.6459;
    final dLat = (lat - refLat) * 111.0;
    final dLng = (lng - refLng) * 111.0 * cos(refLat * pi / 180);
    distKm = sqrt(dLat * dLat + dLng * dLng);
  }

  bool expiringSoon = d['expiringSoon'] as bool? ?? false;
  final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
  if (createdAt != null &&
      DateTime.now().difference(createdAt).inMinutes < 60) {
    expiringSoon = true;
  }

  return FoodOglas(
    id: doc.id,
    title: d['title'] as String? ?? '',
    description: d['description'] as String? ?? '',
    location: d['location'] as String? ?? '',
    time: _timeAgoMoje(createdAt),
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

String _timeAgoMoje(DateTime? dt) {
  if (dt == null) return 'Pravkar';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Pravkar';
  if (diff.inMinutes < 60) return 'Pred ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Pred ${diff.inHours} ur';
  return 'Pred ${diff.inDays} dni';
}

// ─────────────────────────────────────────────────────────────────────────────
// MojeScreen
// ─────────────────────────────────────────────────────────────────────────────
class MineScreen extends StatefulWidget {
  const MineScreen({super.key});

  @override
  State<MineScreen> createState() => _MojeScreenState();
}

class _MojeScreenState extends State<MineScreen> {
  bool _isDavatelj = false;

  @override
  void initState() {
    super.initState();
    _loadUserType();
  }

  Future<void> _loadUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() => _isDavatelj = true);
      return;
    }
  }

  void _showAddOglas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddOglasSheet(
        onSaved: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oglas uspešno objavljen! 🎉'),
            backgroundColor: kGreenMid,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: kSurface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                        color: kGreenPale, shape: BoxShape.circle),
                    child: const Icon(Icons.lock_outline_rounded,
                        size: 40, color: kGreenMid),
                  ),
                  const SizedBox(height: 20),
                  const Text('Niste prijavljeni', style: kHeading2),
                  const SizedBox(height: 8),
                  const Text(
                    'Za ogled in dodajanje oglasov\nse prijavite v račun.',
                    style: kBody,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kSurface,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('oglasi')
            .where('uid', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: kGreenMid));
          }

          final moji =
              snap.data!.docs.map(_docToOglasMoje).toList();

          if (moji.isEmpty) {
            return _buildEmpty();
          }

          return CustomScrollView(
            slivers: [
              // ── AppBar ─────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFF2E7D32),
                title: const Text(
                  'Moji oglasi',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: kRadius8),
                        ),
                      ),
                    ),
                ],
              ),

              // ── Gumb "Dodaj oglas" ─────────────────────────────────────
              if (_isDavatelj)
                SliverToBoxAdapter(child: _buildAddButton()),

              // ── Lista ──────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => FoodCard(
                      oglas: moji[i],
                      onTap: () =>
                          FoodDetailSheet.show(context, moji[i]),
                    ),
                    childCount: moji.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Gumb "Dodaj oglas" ─────────────────────────────────────────────────────
  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GestureDetector(
        onTap: _showAddOglas,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: kRadius16,
            boxShadow: [
              BoxShadow(
                color: kGreenMid.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: kRadius8,
                ),
                child:
                    const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Dodaj oglas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // ── Prazno stanje ──────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFF2E7D32),
          title: const Text('Moji oglasi',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        if (_isDavatelj) SliverToBoxAdapter(child: _buildAddButton()),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                        color: kGreenPale, shape: BoxShape.circle),
                    child: const Icon(Icons.inbox_outlined,
                        size: 48, color: kGreenMid),
                  ),
                  const SizedBox(height: 18),
                  const Text('Moji oglasi', style: kHeading2),
                  const SizedBox(height: 8),
                  const Text('Še niste objavili nobenega oglasa.',
                      style: kBody, textAlign: TextAlign.center),
                  //if (_isDavatelj) ...[
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: _showAddOglas,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                          ),
                          borderRadius: kRadiusFull,
                          boxShadow: [
                            BoxShadow(
                              color: kGreenMid.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Dodaj prvi oglas',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                //],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AddOglasSheet — izločen iz home_screen.dart (javni, da ga home_screen
// lahko še vedno uporablja prek _showAddOglas)
// ─────────────────────────────────────────────────────────────────────────────
class AddOglasSheet extends StatefulWidget {
  final VoidCallback? onSaved;
  const AddOglasSheet({super.key, this.onSaved});

  @override
  State<AddOglasSheet> createState() => _AddOglasSheetState();
}

class _AddOglasSheetState extends State<AddOglasSheet> {
  int _step = 0;
  String _selectedCategory = 'Sestavine';
  bool _loading = false;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isFree = true;

  String _selectedCity = 'Maribor, Center';
  static const _lokacije = [
    ('Maribor, Center', 46.5547, 15.6459),
    ('Maribor, Tabor', 46.5600, 15.6380),
    ('Maribor, Tezno', 46.5480, 15.6610),
    ('Maribor, Pobrežje', 46.5610, 15.6720),
    ('Maribor, Magdalena', 46.5500, 15.6250),
    ('Maribor, Radvanje', 46.5420, 15.6180),
    ('Hoče', 46.5100, 15.6500),
    ('Miklavž', 46.5050, 15.6970),
    ('Limbuš', 46.5270, 15.5950),
    ('Ruše', 46.5400, 15.5120),
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
    final loc = _lokacije.firstWhere(
      (l) => l.$1 == _selectedCity,
      orElse: () => _lokacije.first,
    );

    try {
      await FirebaseFirestore.instance.collection('oglasi').add({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _selectedCategory,
        'location': _selectedCity,
        'lat': loc.$2,
        'lng': loc.$3,
        'isFree': _isFree,
        'status': 'naRazpolago',
        'uid': user?.uid,
        'username':
            user?.displayName != null ? '@${user!.displayName}' : null,
        'createdAt': FieldValue.serverTimestamp(),
        'expiringSoon': false,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Napaka: $e')));
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
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration:
                  BoxDecoration(color: kBorder, borderRadius: kRadiusFull),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(children: [
            if (_step == 1)
              GestureDetector(
                onTap: () => setState(() => _step = 0),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 10),
                  decoration:
                      BoxDecoration(color: kGreenPale, borderRadius: kRadius8),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: kGreenMid, size: 18),
                ),
              ),
            Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(color: kGreenPale, borderRadius: kRadius12),
              child: const Icon(Icons.add_circle_outline_rounded,
                  color: kGreenMid, size: 22),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Dodaj oglas', style: kHeading2),
              Text(
                  _step == 0 ? 'Izberi kategorijo' : 'Izpolni podatke',
                  style: kBody),
            ]),
          ]),
          const SizedBox(height: 20),

          // ── Korak 0: kategorija ──────────────────────────────────────
          if (_step == 0) ...[
            _OglasCategory(
              icon: Icons.soup_kitchen_rounded,
              label: 'Kuhano',
              sub: 'Pripravljeni obroki, juhe, enolončnice...',
              color: kOrange,
              bgColor: kOrangePale,
              selected: _selectedCategory == 'Kuhano',
              onTap: () => setState(() {
                _selectedCategory = 'Kuhano';
                _step = 1;
              }),
            ),
            const SizedBox(height: 10),
            _OglasCategory(
              icon: Icons.grass_rounded,
              label: 'Sestavine',
              sub: 'Sadje, zelenjava, moka, jajca...',
              color: kGreenLight,
              bgColor: kGreenPale,
              selected: _selectedCategory == 'Sestavine',
              onTap: () => setState(() {
                _selectedCategory = 'Sestavine';
                _step = 1;
              }),
            ),
            const SizedBox(height: 10),
            _OglasCategory(
              icon: Icons.bakery_dining_rounded,
              label: 'Peka',
              sub: 'Kruh, kolači, pecivo...',
              color: const Color(0xFF8D6E63),
              bgColor: const Color(0xFFEFEBE9),
              selected: _selectedCategory == 'Peka',
              onTap: () => setState(() {
                _selectedCategory = 'Peka';
                _step = 1;
              }),
            ),
            const SizedBox(height: 10),
            _OglasCategory(
              icon: Icons.apple_rounded,
              label: 'Sadje & zelenjava',
              sub: 'Sveže iz vrta ali kmetije...',
              color: const Color(0xFF00897B),
              bgColor: const Color(0xFFE0F2F1),
              selected: _selectedCategory == 'Sadje & zelenjava',
              onTap: () => setState(() {
                _selectedCategory = 'Sadje & zelenjava';
                _step = 1;
              }),
            ),
          ],

          // ── Korak 1: detalji ─────────────────────────────────────────
          if (_step == 1) ...[
            _OglasFormField(
              ctrl: _titleCtrl,
              label: 'Naziv oglasa',
              hint: 'npr. Domača jabolka, 3 kg',
              icon: Icons.label_outline_rounded,
            ),
            const SizedBox(height: 12),
            _OglasFormField(
              ctrl: _descCtrl,
              label: 'Opis (neobvezno)',
              hint: 'Dodajte opis, količino, posebnosti...',
              icon: Icons.notes_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Lokacija
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.location_on_rounded,
                    color: kGreenMid, size: 18),
                const SizedBox(width: 6),
                const Text('Lokacija',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: kTextDark)),
              ]),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: kGreenPale,
                  borderRadius: kRadius12,
                  border:
                      Border.all(color: kGreenMid.withOpacity(0.25)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCity,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more_rounded,
                        color: kGreenMid),
                    style: const TextStyle(
                        fontSize: 13,
                        color: kTextDark,
                        fontWeight: FontWeight.w600),
                    items: _lokacije
                        .map((l) => DropdownMenuItem(
                            value: l.$1, child: Text(l.$1)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCity = v!),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('Koordinate se določijo samodejno.',
                  style:
                      kCaption.copyWith(color: kTextLight, fontSize: 11)),
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
                      color: (_isFree ? kGreenMid : kOrange)
                          .withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(
                      _isFree
                          ? Icons.volunteer_activism_rounded
                          : Icons.attach_money_rounded,
                      color: _isFree ? kGreenMid : kOrange,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          _isFree
                              ? 'Brezplačno'
                              : 'Simbolična cena',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color:
                                  _isFree ? kGreenMid : kOrange)),
                      Text(
                          _isFree
                              ? 'Hrana je brezplačna'
                              : 'Cena po dogovoru',
                          style: kCaption),
                    ]),
                  ),
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
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreenMid,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                      borderRadius: kRadius12),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Objavi oglas',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ],
                      ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lokalni helper widgeti
// ─────────────────────────────────────────────────────────────────────────────
class _OglasFormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final int maxLines;

  const _OglasFormField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: kGreenMid, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: kTextDark)),
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
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: InputBorder.none,
          ),
        ),
      ),
    ]);
  }
}

class _OglasCategory extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color, bgColor;
  final bool selected;
  final VoidCallback onTap;

  const _OglasCategory({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.bgColor,
    required this.selected,
    required this.onTap,
  });

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
          border: Border.all(
              color: selected ? color : color.withOpacity(0.25),
              width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: kRadius12),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label, style: kBodyBold),
              const SizedBox(height: 2),
              Text(sub, style: kCaption),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: color, size: 22),
        ]),
      ),
    );
  }
}