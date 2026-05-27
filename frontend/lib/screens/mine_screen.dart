import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../common/theme.dart';
import '../models/models.dart';
import '../cards/food_card.dart';
import '../cards/food_detail_sheet.dart';

// ── Nominatim geocoding helper ────────────────────────────────────────────────
// Vrača (lat, lng) za dani naslov/ulicu, ili null ako ne najde.
// Dodaje ", Slovenija" ako korisnik nije unio državu — poboljšava preciznost.
Future<({double lat, double lng})?> _geocodeAddress(String address) async {
  if (address.trim().isEmpty) return null;

  // Ako adresa ne sadrži "slovenija" ili "maribor" etc., dodaj kontekst
  final query = address.toLowerCase().contains('slovenij') ||
          address.toLowerCase().contains('maribor') ||
          address.toLowerCase().contains('ljubljana')
      ? address.trim()
      : '${address.trim()}, Slovenija';

  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query,
    'format': 'json',
    'limit': '1',
    'countrycodes': 'si',
  });

  try {
    final resp = await http.get(uri, headers: {
      'User-Agent': 'PraktikumApp/1.0 (flutter)',
      'Accept-Language': 'sl,en',
    }).timeout(const Duration(seconds: 6));

    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as List<dynamic>;
    if (data.isEmpty) return null;

    final lat = double.tryParse(data[0]['lat'] as String? ?? '');
    final lng = double.tryParse(data[0]['lon'] as String? ?? '');
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  } catch (_) {
    return null;
  }
}

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
      icon = Icons.soup_kitchen_rounded; color = const Color(0xFFFFE0B2); break;
    case 'Peka':
      icon = Icons.bakery_dining_rounded; color = const Color(0xFFEFEBE9); break;
    case 'Sadje & zelenjava':
      icon = Icons.apple_rounded; color = const Color(0xFFE8F5E9); break;
    case 'Ostalo':
      icon = Icons.more_horiz_rounded; color = const Color(0xFFE8EAF6); break;
    default:
      icon = Icons.grass_rounded; color = const Color(0xFFF1F8E9);
  }

  double distKm = 1.0;
  final lat = (d['lat'] as num?)?.toDouble();
  final lng = (d['lng'] as num?)?.toDouble();
  if (lat != null && lng != null) {
    const refLat = 46.5547; const refLng = 15.6459;
    final dLat = (lat - refLat) * 111.0;
    final dLng = (lng - refLng) * 111.0 * cos(refLat * pi / 180);
    distKm = sqrt(dLat * dLat + dLng * dLng);
  }

  final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
  final expiryDate = (d['expiryDate'] as Timestamp?)?.toDate();

  bool expiringSoon = d['expiringSoon'] as bool? ?? false;
  if (expiryDate != null) {
    final hoursLeft = expiryDate.difference(DateTime.now()).inHours;
    if (hoursLeft <= 24 && hoursLeft >= 0) expiringSoon = true;
  }

  final waitlistRaw = d['waitlist'];
  final waitlist = (waitlistRaw is List)
      ? waitlistRaw.map((e) => e.toString()).toList()
      : <String>[];

  return FoodOglas(
    id: doc.id,
    uid: d['uid'] as String?,
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
    imageBase64: d['imageBase64'] as String?,
    reservedByUid: d['reservedByUid'] as String?,
    expiryDate: expiryDate,
    termin1: (d['termin1'] as Timestamp?)?.toDate(),
    termin2: (d['termin2'] as Timestamp?)?.toDate(),
    termin3: (d['termin3'] as Timestamp?)?.toDate(),
    termin4: (d['termin4'] as Timestamp?)?.toDate(),
    chosenTermin: (d['chosenTermin'] as Timestamp?)?.toDate(),
    offerPending: d['offerPending'] as bool? ?? false,
    offerExpiresAt: (d['offerExpiresAt'] as Timestamp?)?.toDate(),
    offerToken: d['offerToken'] as String?,
    waitlist: waitlist,
    portions: (d['portions'] as num?)?.toInt(),
    remainingPortions: (d['remainingPortions'] as num?)?.toInt(),
    price: (d['price'] as num?)?.toDouble(),
    isDavatelj: d['isDavatelj'] as bool? ?? false,
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

String _formatDate(DateTime dt) => '${dt.day}. ${dt.month}. ${dt.year}';

// ─────────────────────────────────────────────────────────────────────────────
// MineScreen
// ─────────────────────────────────────────────────────────────────────────────
class MineScreen extends StatefulWidget {
  const MineScreen({super.key});

  @override
  State<MineScreen> createState() => _MojeScreenState();
}

class _MojeScreenState extends State<MineScreen> {
  bool _isDavatelj = false;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadUserType();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null) {
        _loadUserType();
      } else {
        setState(() => _isDavatelj = false);
      }
    });
  }

  // FIX: sad pravilno provjerava userType vrijednost
  Future<void> _loadUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() => _isDavatelj = doc.data()?['userType'] == 'davatelj');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _showAddOglas() {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddOglasSheet(
        onSaved: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oglas uspešno objavljen! 🎉'),
            backgroundColor: kGreenMid,
          ),
        ),
      ),
    ));
  }

  void _showEditOglas(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddOglasSheet(
        editDocId: doc.id,
        initialTitle: d['title'] as String? ?? '',
        initialDesc: d['description'] as String? ?? '',
        initialCategory: d['category'] as String? ?? 'Sestavine',
        initialLocation: d['location'] as String? ?? '',
        initialImageBase64: d['imageBase64'] as String?,
        initialExpiryDate: (d['expiryDate'] as Timestamp?)?.toDate(),
        initialGrams: (d['grams'] as num?)?.toInt(),
        initialPrice: (d['price'] as num?)?.toDouble(),
        initialTermin1: (d['termin1'] as Timestamp?)?.toDate(),
        initialTermin2: (d['termin2'] as Timestamp?)?.toDate(),
        initialTermin3: (d['termin3'] as Timestamp?)?.toDate(),
        initialTermin4: (d['termin4'] as Timestamp?)?.toDate(),
        initialPortions: (d['portions'] as num?)?.toInt(),
        onSaved: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oglas uspešno posodobljen! ✅'),
            backgroundColor: kGreenMid,
          ),
        ),
      ),
    ));
  }

  Future<void> _deleteOglas(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: kRadius12),
        title: const Text('Izbriši oglas', style: kHeading2),
        content: const Text(
          'Ali ste prepričani, da želite izbrisati ta oglas?',
          style: kBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Prekliči', style: TextStyle(color: kTextLight, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: kRadius8),
            ),
            child: const Text('Izbriši', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await FirebaseFirestore.instance.collection('oglasi').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oglas je bil izbrisan.'), backgroundColor: Colors.red),
        );
      }
    }
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
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
                    child: const Icon(Icons.lock_outline_rounded, size: 40, color: kGreenMid),
                  ),
                  const SizedBox(height: 20),
                  const Text('Niste prijavljeni', style: kHeading2),
                  const SizedBox(height: 8),
                  const Text(
                    'Za ogled in dodajanje oglasov\nse prijavite v račun.',
                    style: kBody, textAlign: TextAlign.center,
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
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: kGreenMid));
          }
          if (snap.hasError) {
            return _buildStreamError(snap.error.toString());
          }

          final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? [])
            ..sort((a, b) {
              final ta = (a.data() as Map<String, dynamic>?)?['createdAt'];
              final tb = (b.data() as Map<String, dynamic>?)?['createdAt'];
              final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
              final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
              return mb.compareTo(ma);
            });
          final moji = docs.map(_docToOglasMoje).toList();

          if (moji.isEmpty) {
            return _buildEmpty();
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFF2E7D32),
                title: const Text('Moje objave',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                actions: [
                  // Dodajanje samo za ne-davatelje (davatelji imajo FAB na home)
                  if (!_isDavatelj)
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
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        shape: RoundedRectangleBorder(borderRadius: kRadius8),
                      ),
                    ),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _OglasCard(
                      oglas: moji[i],
                      onTap: () => FoodDetailSheet.show(context, moji[i]),
                      onEdit: () => _showEditOglas(docs[i]),
                      onDelete: () => _deleteOglas(docs[i].id),
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

  Widget _buildStreamError(String message) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFF2E7D32),
          title: const Text('Moje objave',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: kOrange),
                  const SizedBox(height: 12),
                  const Text('Napaka pri nalaganju', style: kHeading2),
                  const SizedBox(height: 8),
                  Text(message, style: kBody, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFF2E7D32),
          title: const Text('Moje objave',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
                    child: const Icon(Icons.inbox_outlined, size: 48, color: kGreenMid),
                  ),
                  const SizedBox(height: 18),
                  const Text('Moje objave', style: kHeading2),
                  const SizedBox(height: 8),
                  const Text('Še niste objavili nobenega oglasa.',
                      style: kBody, textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: _showAddOglas,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                        ),
                        borderRadius: kRadiusFull,
                        boxShadow: [
                          BoxShadow(color: kGreenMid.withOpacity(0.3),
                              blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Dodaj prvi oglas',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _OglasCard
// ─────────────────────────────────────────────────────────────────────────────
class _OglasCard extends StatelessWidget {
  final FoodOglas oglas;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OglasCard({
    required this.oglas,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        children: [
          FoodCard(oglas: oglas, onTap: onTap),
          Positioned(
            top: 8, right: 8,
            child: Row(children: [
              _ActionChip(icon: Icons.edit_rounded, color: kGreenMid,
                  onTap: onEdit, tooltip: 'Uredi'),
              const SizedBox(width: 6),
              _ActionChip(icon: Icons.delete_outline_rounded, color: Colors.red,
                  onTap: onDelete, tooltip: 'Izbriši'),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionChip({required this.icon, required this.color,
      required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: kRadius8,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AddOglasSheet — BEZ isFree togglea, z vsemi kategorijami
// ─────────────────────────────────────────────────────────────────────────────
class AddOglasSheet extends StatefulWidget {
  final bool showPriceField;
  final VoidCallback? onSaved;
  final String? editDocId;
  final String? initialTitle;
  final String? initialDesc;
  final String? initialCategory;
  final String? initialLocation;
  final String? initialImageBase64;
  final DateTime? initialExpiryDate;
  final int? initialGrams;
  final double? initialPrice;
  final DateTime? initialTermin1;
  final DateTime? initialTermin2;
  final DateTime? initialTermin3;
  final DateTime? initialTermin4;
  final int? initialPortions;

  const AddOglasSheet({
    super.key,
    this.showPriceField = false,
    this.onSaved,
    this.editDocId,
    this.initialTitle,
    this.initialDesc,
    this.initialCategory,
    this.initialLocation,
    this.initialImageBase64,
    this.initialExpiryDate,
    this.initialGrams,
    this.initialPrice,
    this.initialTermin1,
    this.initialTermin2,
    this.initialTermin3,
    this.initialTermin4,
    this.initialPortions,
  });

  bool get isEditing => editDocId != null;

  @override
  State<AddOglasSheet> createState() => _AddOglasSheetState();
}

class _AddOglasSheetState extends State<AddOglasSheet> {
  int _step = 0;
  String? _selectedCategory;
  bool _loading = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _gramsCtrl;
  late final TextEditingController _portionsCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _termin1Ctrl;
  late final TextEditingController _termin2Ctrl;
  late final TextEditingController _termin3Ctrl;
  late final TextEditingController _termin4Ctrl;
  DateTime? _termin1Value;
  DateTime? _termin2Value;
  DateTime? _termin3Value;
  DateTime? _termin4Value;
  bool _titleError = false;
  bool _gramsError = false;
  bool _locationError = false;
  bool _termin1Error = false;
  bool _termin2Error = false;

  Uint8List? _pickedBytes;
  String? _existingBase64;
  DateTime? _expiryDate;

  // Geocoded koordinate za heatmapu
  double? _geocodedLat;
  double? _geocodedLng;
  bool _geocoding = false;
  bool _geocodeOk = false;   // true = uspješno; false = nije još ili failed

  // Debounce timer za geocoding dok korisnik tipka
  Timer? _geocodeTimer;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _descCtrl = TextEditingController(text: widget.initialDesc ?? '');
    _gramsCtrl = TextEditingController(text: widget.initialGrams != null ? widget.initialGrams.toString() : '');
    _portionsCtrl = TextEditingController(text: widget.initialPortions != null ? widget.initialPortions.toString() : '');
    _priceCtrl = TextEditingController(
      text: widget.initialPrice != null ? widget.initialPrice!.toStringAsFixed(2) : '',
    );
    _locationCtrl = TextEditingController(text: widget.initialLocation ?? '');
    _termin1Value = widget.initialTermin1;
    _termin2Value = widget.initialTermin2;
    _termin3Value = widget.initialTermin3;
    _termin4Value = widget.initialTermin4;
    _termin1Ctrl = TextEditingController(text: _formatPickupTerm(_termin1Value));
    _termin2Ctrl = TextEditingController(text: _formatPickupTerm(_termin2Value));
    _termin3Ctrl = TextEditingController(text: _formatPickupTerm(_termin3Value));
    _termin4Ctrl = TextEditingController(text: _formatPickupTerm(_termin4Value));
    _existingBase64 = widget.initialImageBase64;
    _expiryDate = widget.initialExpiryDate;
    if (widget.isEditing) _step = 1;

    // Geocodira adresu 800ms nakon što korisnik prestane tipkati
    _locationCtrl.addListener(() {
      _geocodeTimer?.cancel();
      final text = _locationCtrl.text.trim();
      if (text.isEmpty) {
        setState(() { _geocodedLat = null; _geocodedLng = null; _geocodeOk = false; });
        return;
      }
      setState(() { _geocodeOk = false; });
      _geocodeTimer = Timer(const Duration(milliseconds: 800), () async {
        if (!mounted) return;
        setState(() => _geocoding = true);
        final result = await _geocodeAddress(text);
        if (!mounted) return;
        setState(() {
          _geocoding = false;
          if (result != null) {
            _geocodedLat = result.lat;
            _geocodedLng = result.lng;
            _geocodeOk = true;
          } else {
            _geocodedLat = null;
            _geocodedLng = null;
            _geocodeOk = false;
          }
        });
      });
    });

    // Ako editiramo i već imamo adresu, geocodiraj odmah
    if (widget.isEditing && (widget.initialLocation?.isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _locationCtrl.notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _geocodeTimer?.cancel();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _gramsCtrl.dispose();
    _portionsCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _termin1Ctrl.dispose();
    _termin2Ctrl.dispose();
    _termin3Ctrl.dispose();
    _termin4Ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 800,
    );
    if (picked != null && mounted) {
      final bytes = await picked.readAsBytes();
      setState(() => _pickedBytes = bytes);
    }
  }

  Future<String?> _encodeImageToBase64() async {
    if (_pickedBytes == null) return _existingBase64;
    try {
      return base64Encode(_pickedBytes!);
    } catch (_) {
      return _existingBase64;
    }
  }

  String _formatPickupTerm(DateTime? dt) {
    if (dt == null) return '';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.${dt.year} $hour:$minute';
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kGreenMid,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : const TimeOfDay(hour: 16, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kGreenMid,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null) return null;
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _pickTermin(int index) async {
    final current = switch (index) {
      1 => _termin1Value,
      2 => _termin2Value,
      3 => _termin3Value,
      4 => _termin4Value,
      _ => null,
    };
    final picked = await _pickDateTime(current);
    if (picked == null || !mounted) return;
    setState(() {
      switch (index) {
        case 1:
          _termin1Value = picked;
          _termin1Ctrl.text = _formatPickupTerm(picked);
          _termin1Error = false;
          break;
        case 2:
          _termin2Value = picked;
          _termin2Ctrl.text = _formatPickupTerm(picked);
          _termin2Error = false;
          break;
        case 3:
          _termin3Value = picked;
          _termin3Ctrl.text = _formatPickupTerm(picked);
          break;
        case 4:
          _termin4Value = picked;
          _termin4Ctrl.text = _formatPickupTerm(picked);
          break;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kGreenMid,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _save() async {
    final titleEmpty = _titleCtrl.text.trim().isEmpty;
    final gramsEmpty = _gramsCtrl.text.trim().isEmpty;
    final locationEmpty = _locationCtrl.text.trim().isEmpty;
    final termin1Empty = _termin1Value == null;
    final termin2Empty = _termin2Value == null;
    if (titleEmpty || gramsEmpty || locationEmpty || termin1Empty || termin2Empty) {
      setState(() {
        _titleError = titleEmpty;
        _gramsError = gramsEmpty;
        _locationError = locationEmpty;
        _termin1Error = termin1Empty;
        _termin2Error = termin2Empty;
      });
      return;
    }
    setState(() {
      _titleError = false;
      _gramsError = false;
      _locationError = false;
      _termin1Error = false;
      _termin2Error = false;
      _loading = true;
    });

    final user = FirebaseAuth.instance.currentUser;

    try {
      final imageBase64 = await _encodeImageToBase64();

      // Preveri ali je uporabnik davatelj
      bool isDavatelj = false;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        isDavatelj = userDoc.data()?['userType'] == 'davatelj';
      }

      // Geocodiranje adrese (ako još nije urađeno ili se promijenila)
      double? lat = _geocodedLat;
      double? lng = _geocodedLng;
      if (lat == null || lng == null) {
        final result = await _geocodeAddress(_locationCtrl.text.trim());
        lat = result?.lat;
        lng = result?.lng;
      }

      if (widget.isEditing) {
        // Pri urejanju: posodobi portions IN remainingPortions skupaj
        // Preberemo trenutno stanje iz Firestorea, da izračunamo razliko
        final newPortions = int.tryParse(_portionsCtrl.text.trim()) ?? 1;
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final docRef = FirebaseFirestore.instance
              .collection('oglasi')
              .doc(widget.editDocId);
          final snapshot = await transaction.get(docRef);
          if (!snapshot.exists) throw Exception('Oglas ne obstaja več.');
          final data = snapshot.data()!;

          final oldPortions = (data['portions'] as num?)?.toInt() ?? 1;
          final oldRemaining = (data['remainingPortions'] as num?)?.toInt() ?? oldPortions;

          // Izračunaj koliko je že rezerviranih (razlika med skupnim in preostalim)
          final reserved = oldPortions - oldRemaining;
          // Novo preostalo = novo skupno - že rezervirano (ne sme biti negativno)
          final newRemaining = (newPortions - reserved).clamp(0, newPortions);

          transaction.update(docRef, {
            'title': _titleCtrl.text.trim(),
            'description': _descCtrl.text.trim(),
            'grams': int.tryParse(_gramsCtrl.text.trim()) ?? 0,
            'portions': newPortions,
            'remainingPortions': newRemaining,
            'category': _selectedCategory ?? 'Ostalo',
            'location': _locationCtrl.text.trim(),
            'price': double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.')) ?? 0.0,
            'termin1': Timestamp.fromDate(_termin1Value!),
            'termin2': Timestamp.fromDate(_termin2Value!),
            if (_termin3Value != null) 'termin3': Timestamp.fromDate(_termin3Value!),
            if (_termin4Value != null) 'termin4': Timestamp.fromDate(_termin4Value!),
            'updatedAt': FieldValue.serverTimestamp(),
            if (imageBase64 != null) 'imageBase64': imageBase64,
            'expiryDate': _expiryDate != null
                ? Timestamp.fromDate(_expiryDate!)
                : FieldValue.delete(),
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
          });
        });
      } else {
        final docRef = FirebaseFirestore.instance.collection('oglasi').doc();
        final portions = int.tryParse(_portionsCtrl.text.trim()) ?? 1;
        await docRef.set({
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'grams': int.tryParse(_gramsCtrl.text.trim()) ?? 0,
          'portions': portions,
          'remainingPortions': portions,
          'category': _selectedCategory ?? 'Ostalo',
          'location': _locationCtrl.text.trim(),
          'price': double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.')) ?? 0.0,
          'status': 'naRazpolago',
          'uid': user?.uid,
          'username': user?.displayName != null ? '@${user!.displayName}' : null,
          'isDavatelj': isDavatelj,
          'createdAt': FieldValue.serverTimestamp(),
          'expiringSoon': false,
          'waitlist': [],
          'termin1': Timestamp.fromDate(_termin1Value!),
          'termin2': Timestamp.fromDate(_termin2Value!),
          if (_termin3Value != null) 'termin3': Timestamp.fromDate(_termin3Value!),
          if (_termin4Value != null) 'termin4': Timestamp.fromDate(_termin4Value!),
          if (imageBase64 != null) 'imageBase64': imageBase64,
          if (_expiryDate != null) 'expiryDate': Timestamp.fromDate(_expiryDate!),
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        });
      }

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF2E7D32),
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), borderRadius: kRadius8),
            child: Icon(
              widget.isEditing ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
              color: Colors.white, size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.isEditing ? 'Uredi oglas' : 'Dodaj oglas',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              _step == 0 ? 'Izberi kategorijo' : 'Izpolni podatke',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ]),
        ]),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24,
              MediaQuery.of(context).viewInsets.bottom + 32,
              ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // ── Korak 0: Kategorija ──────────────────────────────────────
            if (_step == 0) ...[
              const SizedBox(height: 4),
              _OglasCategory(
                icon: Icons.soup_kitchen_rounded, label: 'Kuhano',
                sub: 'Pripravljeni obroki, juhe, enolončnice...',
                color: kOrange, bgColor: kOrangePale,
                selected: _selectedCategory == 'Kuhano',
                onTap: () => setState(() { _selectedCategory = 'Kuhano'; _step = 1; }),
              ),
              const SizedBox(height: 10),
              _OglasCategory(
                icon: Icons.grass_rounded, label: 'Sestavine',
                sub: 'Sadje, zelenjava, moka, jajca...',
                color: kGreenLight, bgColor: kGreenPale,
                selected: _selectedCategory == 'Sestavine',
                onTap: () => setState(() { _selectedCategory = 'Sestavine'; _step = 1; }),
              ),
              const SizedBox(height: 10),
              _OglasCategory(
                icon: Icons.bakery_dining_rounded, label: 'Peka',
                sub: 'Kruh, kolači, pecivo...',
                color: const Color(0xFF8D6E63), bgColor: const Color(0xFFEFEBE9),
                selected: _selectedCategory == 'Peka',
                onTap: () => setState(() { _selectedCategory = 'Peka'; _step = 1; }),
              ),
              const SizedBox(height: 10),
              _OglasCategory(
                icon: Icons.apple_rounded, label: 'Sadje & zelenjava',
                sub: 'Sveže iz vrta ali kmetije...',
                color: const Color(0xFF00897B), bgColor: const Color(0xFFE0F2F1),
                selected: _selectedCategory == 'Sadje & zelenjava',
                onTap: () => setState(() { _selectedCategory = 'Sadje & zelenjava'; _step = 1; }),
              ),
              const SizedBox(height: 10),
              // Ostalo je zdaj vedno vidno
              _OglasCategory(
                icon: Icons.more_horiz_rounded, label: 'Ostalo',
                sub: 'Vse, kar ne spada v zgornje kategorije...',
                color: const Color(0xFF5C6BC0), bgColor: const Color(0xFFE8EAF6),
                selected: _selectedCategory == 'Ostalo',
                onTap: () => setState(() { _selectedCategory = 'Ostalo'; _step = 1; }),
              ),
            ],

            // ── Korak 1: Detalji ─────────────────────────────────────────
            if (_step == 1) ...[
              // Back gumb
              if (!widget.isEditing)
                GestureDetector(
                  onTap: () => setState(() => _step = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadius8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.arrow_back_rounded, color: kGreenMid, size: 16),
                      const SizedBox(width: 6),
                      Text('Nazaj na kategorije',
                          style: kCaption.copyWith(
                              color: kGreenMid, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),

              // Izbrana kategorija chip
              if (_selectedCategory != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kGreenPale, borderRadius: kRadiusFull,
                    border: Border.all(color: kGreenMid.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.label_rounded, color: kGreenMid, size: 14),
                    const SizedBox(width: 6),
                    Text(_selectedCategory!,
                        style: const TextStyle(
                            fontSize: 14, color: kGreenMid, fontWeight: FontWeight.w700)),
                  ]),
                ),

              // Slika
              const _SectionLabel(icon: Icons.image_rounded, label: 'Fotografija (neobvezno)'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160, width: double.infinity,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7F5),
                    borderRadius: kRadius12,
                    border: Border.all(color: kGreenMid.withOpacity(0.25)),
                  ),
                  child: _buildImagePreview(),
                ),
              ),
              const SizedBox(height: 16),

              // Naziv (obvezno)
              _OglasFormField(
                ctrl: _titleCtrl,
                label: 'Naziv oglasa *',
                hint: 'npr. Domača jabolka',
                icon: Icons.label_outline_rounded,
                hasError: _titleError,
                onChanged: (_) {
                  if (_titleError) setState(() => _titleError = false);
                },
              ),
              if (_titleError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text('Naziv oglasa je obvezen.',
                        style: kCaption.copyWith(color: Colors.red, fontWeight: FontWeight.w600)),
                  ]),
                ),
              const SizedBox(height: 12),

              // Termin 1 in 2 (obvezno)
              _OglasFormField(
                ctrl: _termin1Ctrl,
                label: 'Termin 1 *',
                hint: 'Izberi datum in uro',
                icon: Icons.schedule_rounded,
                hasError: _termin1Error,
                readOnly: true,
                onTap: () => _pickTermin(1),
              ),
              if (_termin1Error)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text('Termin 1 je obvezen.',
                        style: kCaption.copyWith(color: Colors.red, fontWeight: FontWeight.w600)),
                  ]),
                ),
              const SizedBox(height: 12),

              _OglasFormField(
                ctrl: _termin2Ctrl,
                label: 'Termin 2 *',
                hint: 'Izberi datum in uro',
                icon: Icons.schedule_rounded,
                hasError: _termin2Error,
                readOnly: true,
                onTap: () => _pickTermin(2),
              ),
              if (_termin2Error)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text('Termin 2 je obvezen.',
                        style: kCaption.copyWith(color: Colors.red, fontWeight: FontWeight.w600)),
                  ]),
                ),
              const SizedBox(height: 12),

              _OglasFormField(
                ctrl: _termin3Ctrl,
                label: 'Termin 3 (neobvezno)',
                hint: 'Izberi datum in uro',
                icon: Icons.schedule_outlined,
                readOnly: true,
                onTap: () => _pickTermin(3),
              ),
              const SizedBox(height: 12),

              _OglasFormField(
                ctrl: _termin4Ctrl,
                label: 'Termin 4 (neobvezno)',
                hint: 'Izberi datum in uro',
                icon: Icons.schedule_outlined,
                readOnly: true,
                onTap: () => _pickTermin(4),
              ),
              const SizedBox(height: 12),

              // Grami (obvezno)
              _OglasFormField(
                ctrl: _gramsCtrl,
                label: 'Količina v gramih *',
                hint: 'npr. 500',
                icon: Icons.monitor_weight_outlined,
                hasError: _gramsError,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  if (_gramsError) setState(() => _gramsError = false);
                },
              ),
              if (_gramsError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text('Količina v gramih je obvezna.',
                        style: kCaption.copyWith(color: Colors.red, fontWeight: FontWeight.w600)),
                  ]),
                ),
              const SizedBox(height: 12),

              // Število porcij
              _OglasFormField(
                ctrl: _portionsCtrl,
                label: 'Število porcij',
                hint: 'npr. 3',
                icon: Icons.people_outline_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text(
                  'Koliko oseb lahko prevzame ta oglas? Vsaka rezervira svojo porcijo.',
                  style: kCaption.copyWith(color: kTextLight, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),

              // ── Cena ────────────────────────────────────────────────────
              if (widget.showPriceField) ...[
              const _SectionLabel(icon: Icons.euro_rounded, label: 'Cena'),
              const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7F5),
                    borderRadius: kRadius12,
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44,
                      alignment: Alignment.center,
                      child: const Text('€',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700, color: kGreenMid)),
                    ),
                    Container(width: 1, height: 44, color: kBorder),
                    Expanded(
                      child: TextField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}')),
                        ],
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextDark),
                        decoration: InputDecoration(
                          hintText: '0,00',
                          hintStyle: kCaption.copyWith(fontSize: 15),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                          suffixText: 'EUR',
                          suffixStyle: kCaption.copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Text('Vnesite ceno v evrih (npr. 2,50)',
                      style: kCaption.copyWith(color: kTextLight, fontSize: 12)),
                ),
              ],
              const SizedBox(height: 12),
              

              // Opis
              _OglasFormField(
                ctrl: _descCtrl,
                label: 'Opis (neobvezno)',
                hint: 'Dodajte opis, količino, posebnosti...',
                icon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Rok uporabe
              const _SectionLabel(
                  icon: Icons.calendar_today_rounded, label: 'Rok uporabe (neobvezno)'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: _expiryDate != null ? kGreenPale : const Color(0xFFF5F7F5),
                    borderRadius: kRadius12,
                    border: Border.all(
                        color: _expiryDate != null ? kGreenMid.withOpacity(0.4) : kBorder),
                  ),
                  child: Row(children: [
                    Icon(Icons.event_rounded,
                        color: _expiryDate != null ? kGreenMid : kTextLight, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _expiryDate != null
                            ? 'Rok: ${_formatDate(_expiryDate!)}'
                            : 'Izberite datum roka uporabe...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _expiryDate != null ? FontWeight.w600 : FontWeight.w400,
                          color: _expiryDate != null ? kTextDark : kTextLight,
                        ),
                      ),
                    ),
                    if (_expiryDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _expiryDate = null),
                        child: const Icon(Icons.close_rounded, color: kTextLight, size: 16),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // Lokacija (obvezno)
              _OglasFormField(
                ctrl: _locationCtrl,
                label: 'Naslov prevzema *',
                hint: 'npr. Partizanska 5, Maribor',
                icon: Icons.location_on_rounded,
                hasError: _locationError,
                onChanged: (_) {
                  if (_locationError) setState(() => _locationError = false);
                },
              ),
              if (_locationError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text('Naslov prevzema je obvezen.',
                        style: kCaption.copyWith(color: Colors.red, fontWeight: FontWeight.w600)),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Row(children: [
                  if (_geocoding) ...[
                    SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: kTextLight,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Iščem lokacijo na karti…',
                        style: kCaption.copyWith(color: kTextLight, fontSize: 13)),
                  ] else if (_geocodeOk) ...[
                    Icon(Icons.location_on_rounded, color: kGreenMid, size: 13),
                    const SizedBox(width: 4),
                    Text('Lokacija najdena — bo vidna na heatmapi',
                        style: kCaption.copyWith(color: kGreenMid, fontSize: 13)),
                  ] else if (_locationCtrl.text.isNotEmpty) ...[
                    Icon(Icons.location_off_outlined, color: kOrange, size: 13),
                    const SizedBox(width: 4),
                    Expanded(child: Text('Lokacija ni bila najdena — oglas bo shranjen brez koordinat',
                        style: kCaption.copyWith(color: kOrange, fontSize: 13))),
                  ] else
                    Text('Vnesite ulico in kraj prevzema.',
                        style: kCaption.copyWith(color: kTextLight, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 24),

              // Submit gumb
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreenMid, elevation: 0,
                    shape: const RoundedRectangleBorder(borderRadius: kRadius12),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.isEditing ? Icons.save_rounded : Icons.check_circle_rounded,
                              color: Colors.white, size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isEditing ? 'Shrani spremembe' : 'Objavi oglas',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_pickedBytes != null) {
      return Stack(fit: StackFit.expand, children: [
        Image.memory(_pickedBytes!, fit: BoxFit.cover),
        Positioned(
          bottom: 8, right: 8,
          child: GestureDetector(
            onTap: () => setState(() => _pickedBytes = null),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.red, borderRadius: kRadius8),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
        _replaceImageBtn(),
      ]);
    }

    if (_existingBase64 != null) {
      try {
        final bytes = base64Decode(_existingBase64!);
        return Stack(fit: StackFit.expand, children: [
          Image.memory(bytes, fit: BoxFit.cover),
          _replaceImageBtn(),
        ]);
      } catch (_) {}
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadius12),
          child: const Icon(Icons.add_photo_alternate_rounded, color: kGreenMid, size: 26),
        ),
        const SizedBox(height: 10),
        const Text('Dodajte fotografijo',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kGreenMid)),
        const SizedBox(height: 4),
        Text('Kliknite za izbiro iz galerije', style: kCaption.copyWith(fontSize: 13)),
      ],
    );
  }

  Widget _replaceImageBtn() => Positioned(
    bottom: 8, left: 8,
    child: GestureDetector(
      onTap: _pickImage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: kRadius8),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.edit_rounded, color: Colors.white, size: 13),
          SizedBox(width: 4),
          Text('Zamenjaj',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(children: [
        Icon(icon, color: kGreenMid, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextDark)),
      ]),
    );
  }
}

class _OglasFormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final int maxLines;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;

  const _OglasFormField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.hasError = false,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: kGreenMid, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextDark)),
      ]),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F5),
          borderRadius: kRadius12,
          border: Border.all(color: hasError ? Colors.red : kBorder, width: hasError ? 1.5 : 1),
        ),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          onTap: onTap,
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
            BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: kRadius12),
            child: Icon(icon, color: color, size: 22),
          ),
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