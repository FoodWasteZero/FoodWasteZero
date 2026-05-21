import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../cards/food_detail_sheet.dart';
import 'auth_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  String _displayName = '';
  String _email = '';
  String _userType = 'uporabnik';
  bool _loadingUser = true;

  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadUserData();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null) {
        setState(() => _loadingUser = true);
        _loadUserData();
      } else {
        setState(() {
          _displayName = '';
          _email = '';
          _userType = 'uporabnik';
          _loadingUser = false;
        });
      }
    });
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingUser = false);
      return;
    }
    if (mounted) {
      setState(() {
        _displayName = user.displayName ?? '';
        _email = user.email ?? '';
      });
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _displayName = doc.data()?['ime'] ?? _displayName;
          _userType = doc.data()?['userType'] ?? 'uporabnik';
          _loadingUser = false;
        });
      } else {
        if (mounted) setState(() => _loadingUser = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _displayName = '';
          _email = '';
          _userType = 'uporabnik';
          _loadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri odjavi: $e'),
              backgroundColor: Colors.red.shade700));
      }
    }
  }

  Future<void> _showEditProfile() async {
    final nameCtrl = TextEditingController(text: _displayName);
    final emailCtrl = TextEditingController(text: _email);
    final pwCtrl = TextEditingController();
    final pw2Ctrl = TextEditingController();
    bool obscurePw = true;
    bool obscurePw2 = true;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Uredi profil',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kTextDark)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: kTextMid),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _EditField(ctrl: nameCtrl, label: 'Ime', icon: Icons.person_outline_rounded),
                const SizedBox(height: 12),
                _EditField(ctrl: emailCtrl, label: 'E-pošta', icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),
                const Text('Novo geslo (pustite prazno, če ne menjate)',
                  style: TextStyle(fontSize: 12, color: kTextMid, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _EditField(
                  ctrl: pwCtrl, label: 'Novo geslo', icon: Icons.lock_outline_rounded,
                  obscure: obscurePw,
                  suffix: IconButton(
                    onPressed: () => setModal(() => obscurePw = !obscurePw),
                    icon: Icon(obscurePw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: kTextLight, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                _EditField(
                  ctrl: pw2Ctrl, label: 'Ponovi geslo', icon: Icons.lock_outline_rounded,
                  obscure: obscurePw2,
                  suffix: IconButton(
                    onPressed: () => setModal(() => obscurePw2 = !obscurePw2),
                    icon: Icon(obscurePw2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: kTextLight, size: 20),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ? null : () async {
                      final newName = nameCtrl.text.trim();
                      final newEmail = emailCtrl.text.trim();
                      final newPw = pwCtrl.text.trim();
                      final newPw2 = pw2Ctrl.text.trim();

                      if (newPw.isNotEmpty && newPw != newPw2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gesli se ne ujemata'),
                            backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setModal(() => saving = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser!;
                        if (newName != _displayName) {
                          await user.updateDisplayName(newName);
                          await FirebaseFirestore.instance
                            .collection('users').doc(user.uid).update({'ime': newName});
                        }
                        if (newEmail != _email && newEmail.isNotEmpty) {
                          await user.verifyBeforeUpdateEmail(newEmail);
                        }
                        if (newPw.isNotEmpty) {
                          await user.updatePassword(newPw);
                        }
                        if (mounted) {
                          setState(() { _displayName = newName; _email = newEmail; });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profil posodobljen ✓')));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Napaka: $e'), backgroundColor: Colors.red));
                        }
                      } finally {
                        setModal(() => saving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreenMid,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14))),
                    ),
                    child: saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Shrani spremembe',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  bool get _isDavatelj => _userType == 'davatelj';
  bool get _isGuest => FirebaseAuth.instance.currentUser == null;

  void _showAuthPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AuthScreen(isModal: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isGuest) {
      return _buildGuestView();
    }
    return _buildLoggedInView();
  }

  Widget _buildGuestView() {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadiusFull),
                  child: const Icon(Icons.person_outline_rounded, size: 52, color: kGreenMid),
                ),
                const SizedBox(height: 24),
                const Text('Niste prijavljeni',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextDark)),
                const SizedBox(height: 10),
                const Text(
                  'Prijavite se ali se registrirajte, da dostopate do profila in svojih oglasov.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextMid, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _showAuthPopup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreenMid,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(borderRadius: kRadius12),
                    ),
                    child: const Text('Prijava / Registracija',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInView() {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: kSurface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildProfileHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                _isDavatelj ? 'Moje objave' : 'Moja hrana',
                style: kHeading2,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildTabBar()),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _isDavatelj
                ? _buildDavateljObjaveTab(user.uid)
                : _buildPrevzetoTab(user.uid),
            _isDavatelj
                ? _buildDavateljArhivTab(user.uid)
                : _buildRezervacijeTab(user.uid),
            _buildShranjeniTab(user.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _displayName.isEmpty ? 'Uporabnik' : _displayName;
    final badge = _isDavatelj ? 'Organizacija' : 'Uporabnik';
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
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(badgeIcon, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(badge,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ],
                  ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: _showEditProfile,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: kRadius12,
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _logout,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: kRadius12,
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tab1Label = _isDavatelj ? 'Aktivno' : 'Prevzeto';
    final tab2Label = _isDavatelj ? 'Arhiv' : 'Rezervirano';

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
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_outline_rounded, size: 14),
            const SizedBox(width: 4),
            Text(tab1Label)])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.bookmark_outline_rounded, size: 14),
            const SizedBox(width: 4),
            Text(tab2Label)])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.favorite_outline_rounded, size: 14),
            const SizedBox(width: 4),
            const Text('Shranjeno')])),
        ],
      ),
    );
  }

  // ── Davatelj tabovi ──────────────────────────────────────────────────────────

  Widget _buildDavateljObjaveTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('uid', isEqualTo: uid)
          .where('status', whereIn: ['naRazpolago', 'rezervirano'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreenMid));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _buildEmptyState('Ni aktivnih objav', Icons.storefront_rounded);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          itemCount: docs.length,
          itemBuilder: (_, i) => _OglasListCard(doc: docs[i], showMarkPrevzeto: true),
        );
      },
    );
  }

  Widget _buildDavateljArhivTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'prevzeto')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kGreenMid));
        }
        final docs = snap.hasData ? snap.data!.docs : [];
        if (docs.isEmpty) {
          return _buildEmptyState('Zaenkrat ni arhiviranih objav', Icons.archive_outlined);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          itemCount: docs.length,
          itemBuilder: (_, i) => _OglasListCard(doc: docs[i], showMarkPrevzeto: false),
        );
      },
    );
  }

  // ── Uporabnik tabovi ─────────────────────────────────────────────────────────

  // FIX: filtrira samo po reservedByUid, status filtriramo v kodi (izognemo composite index)
  Widget _buildPrevzetoTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('reservedByUid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kGreenMid));
        }
        // Filtriramo v kodi — ne potrebujemo composite indexa
        final docs = (snap.hasData ? snap.data!.docs : []).where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return (d['status'] as String?) == 'prevzeto';
        }).toList();

        if (docs.isEmpty) {
          return _buildEmptyState('Zaenkrat ni prevzetih obrokov', Icons.check_circle_outline_rounded);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          itemCount: docs.length,
          itemBuilder: (_, i) => _OglasListCard(doc: docs[i]),
        );
      },
    );
  }

  Widget _buildRezervacijeTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('reservedByUid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kGreenMid));
        }
        // Filtriramo v kodi — ne potrebujemo composite indexa
        final docs = (snap.hasData ? snap.data!.docs : []).where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return (d['status'] as String?) == 'rezervirano';
        }).toList();

        if (docs.isEmpty) {
          return _buildEmptyState('Zaenkrat ni aktivnih rezervacij', Icons.bookmark_outline_rounded);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          itemCount: docs.length,
          itemBuilder: (_, i) => _OglasListCard(doc: docs[i]),
        );
      },
    );
  }

  // ── Shranjeni oglasi tab ──────────────────────────────────────────────────

  Widget _buildShranjeniTab(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreenMid));
        }
        final userData = userSnap.data!.data() as Map<String, dynamic>?;
        final savedIds = List<String>.from(userData?['savedOglasi'] ?? []);

        if (savedIds.isEmpty) {
          return _buildEmptyState('Ni shranjenih oglasov', Icons.favorite_outline_rounded);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('oglasi')
              .where(FieldPath.documentId, whereIn: savedIds)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(color: kGreenMid));
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return _buildEmptyState('Ni shranjenih oglasov', Icons.favorite_outline_rounded);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
              itemCount: docs.length,
              itemBuilder: (_, i) => _ShranjeniOglasCard(
                doc: docs[i],
                onUnsave: () async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({'savedOglasi': FieldValue.arrayRemove([docs[i].id])});
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String label, IconData icon) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 48, color: kBorder),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: kTextLight, fontSize: 14)),
      ]),
    );
  }
}

// ── Oglas card za profil ──────────────────────────────────────────────────────

// Helper: Firestore doc → FoodOglas (kopija iz home_screen)
FoodOglas _docToOglasProfile(DocumentSnapshot doc) {
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
    case 'Kuhano': icon = Icons.soup_kitchen_rounded; color = const Color(0xFFFFE0B2); break;
    case 'Peka': icon = Icons.bakery_dining_rounded; color = const Color(0xFFEFEBE9); break;
    case 'Sadje & zelenjava': icon = Icons.apple_rounded; color = const Color(0xFFE8F5E9); break;
    case 'Ostalo': icon = Icons.more_horiz_rounded; color = const Color(0xFFE8EAF6); break;
    default: icon = Icons.grass_rounded; color = const Color(0xFFF1F8E9);
  }
  final lat = (d['lat'] as num?)?.toDouble();
  final lng = (d['lng'] as num?)?.toDouble();
  final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
  final expiryDate = (d['expiryDate'] as Timestamp?)?.toDate();
  String timeAgo(DateTime? dt) {
    if (dt == null) return 'Pravkar';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Pred ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Pred ${diff.inHours} ur';
    return 'Pred ${diff.inDays} dni';
  }
  final waitlistRaw = d['waitlist'];
  final waitlist = (waitlistRaw is List) ? waitlistRaw.map((e) => e.toString()).toList() : <String>[];
  return FoodOglas(
    id: doc.id,
    uid: d['uid'] as String?,
    title: d['title'] as String? ?? '',
    description: d['description'] as String? ?? '',
    location: d['location'] as String? ?? '',
    time: timeAgo(createdAt),
    status: status,
    username: d['username'] as String?,
    imageColor: color,
    category: category,
    isFree: d['isFree'] as bool? ?? true,
    isExpiringSoon: false,
    distanceKm: 0,
    icon: icon,
    latLng: (lat != null && lng != null) ? LatLng(lat, lng) : null,
    imageBase64: d['imageBase64'] as String?,
    reservedByUid: d['reservedByUid'] as String?,
    expiryDate: expiryDate,
    waitlist: waitlist,
  );
}

class _OglasListCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final bool showMarkPrevzeto;
  const _OglasListCard({required this.doc, this.showMarkPrevzeto = false});

  Future<void> _markPrevzeto(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: kRadius12),
        title: const Text('Označi kot prevzeto', style: kHeading2),
        content: const Text('Ali je bila hrana uspešno prevzeta?', style: kBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Prekliči', style: TextStyle(color: kTextLight, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreenMid, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: kRadius8),
            ),
            child: const Text('Potrdi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('oglasi')
          .doc(doc.id)
          .update({'status': 'prevzeto'});
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final title = d['title'] as String? ?? '—';
    final category = d['category'] as String? ?? '';
    final location = d['location'] as String? ?? '';
    final statusStr = d['status'] as String? ?? 'naRazpolago';

    OglasStatus status;
    switch (statusStr) {
      case 'rezervirano': status = OglasStatus.rezervirano; break;
      case 'prevzeto': status = OglasStatus.prevzeto; break;
      default: status = OglasStatus.naRazpolago;
    }

    final color = statusColor(status);

    final IconData icon;
    final Color bgColor;
    switch (category) {
      case 'Kuhano': icon = Icons.soup_kitchen_rounded; bgColor = const Color(0xFFFFE0B2); break;
      case 'Peka': icon = Icons.bakery_dining_rounded; bgColor = const Color(0xFFEFEBE9); break;
      case 'Sadje & zelenjava': icon = Icons.apple_rounded; bgColor = const Color(0xFFE8F5E9); break;
      case 'Ostalo': icon = Icons.more_horiz_rounded; bgColor = const Color(0xFFE8EAF6); break;
      default: icon = Icons.grass_rounded; bgColor = const Color(0xFFF1F8E9);
    }

    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    String timeStr = 'Pravkar';
    if (createdAt != null) {
      final diff = DateTime.now().difference(createdAt);
      if (diff.inMinutes < 60) timeStr = 'Pred ${diff.inMinutes} min';
      else if (diff.inHours < 24) timeStr = 'Pred ${diff.inHours} ur';
      else timeStr = 'Pred ${diff.inDays} dni';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: bgColor, borderRadius: kRadius12),
              child: Icon(icon, color: kGreenMid, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: kBodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 11, color: kTextLight),
                const SizedBox(width: 3),
                Expanded(child: Text(location, style: kCaption,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 2),
              Text(timeStr, style: kCaption.copyWith(fontSize: 14)),
            ])),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: kRadiusFull,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(statusLabel(status),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          // "Označi kot prevzeto" gumb — samo za davatelja, samo ako je rezervirano
          if (showMarkPrevzeto && status == OglasStatus.rezervirano) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _markPrevzeto(context),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                label: const Text('Označi kot prevzeto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGreenMid,
                  side: const BorderSide(color: kGreenMid, width: 1.5),
                  shape: const RoundedRectangleBorder(borderRadius: kRadius8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const _EditField({
    required this.ctrl, required this.label, required this.icon,
    this.obscure = false, this.keyboardType, this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface, borderRadius: kRadius12, border: Border.all(color: kBorder)),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: kTextDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kTextMid, fontSize: 13),
          prefixIcon: Icon(icon, color: kTextLight, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
// ── Shranjeni oglas card ──────────────────────────────────────────────────────
class _ShranjeniOglasCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final VoidCallback onUnsave;
  const _ShranjeniOglasCard({required this.doc, required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final title = d['title'] as String? ?? '—';
    final category = d['category'] as String? ?? '';
    final location = d['location'] as String? ?? '';
    final statusStr = d['status'] as String? ?? 'naRazpolago';

    OglasStatus status;
    switch (statusStr) {
      case 'rezervirano': status = OglasStatus.rezervirano; break;
      case 'prevzeto': status = OglasStatus.prevzeto; break;
      default: status = OglasStatus.naRazpolago;
    }

    final color = statusColor(status);

    final IconData icon;
    final Color bgColor;
    switch (category) {
      case 'Kuhano': icon = Icons.soup_kitchen_rounded; bgColor = const Color(0xFFFFE0B2); break;
      case 'Peka': icon = Icons.bakery_dining_rounded; bgColor = const Color(0xFFEFEBE9); break;
      case 'Sadje & zelenjava': icon = Icons.apple_rounded; bgColor = const Color(0xFFE8F5E9); break;
      case 'Ostalo': icon = Icons.more_horiz_rounded; bgColor = const Color(0xFFE8EAF6); break;
      default: icon = Icons.grass_rounded; bgColor = const Color(0xFFF1F8E9);
    }

    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    String timeStr = 'Pravkar';
    if (createdAt != null) {
      final diff = DateTime.now().difference(createdAt);
      if (diff.inMinutes < 60) timeStr = 'Pred ${diff.inMinutes} min';
      else if (diff.inHours < 24) timeStr = 'Pred ${diff.inHours} ur';
      else timeStr = 'Pred ${diff.inDays} dni';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        boxShadow: kCardShadow,
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: bgColor, borderRadius: kRadius12),
          child: Icon(icon, color: kGreenMid, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: kBodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.location_on_outlined, size: 11, color: kTextLight),
            const SizedBox(width: 3),
            Expanded(child: Text(location, style: kCaption,
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 2),
          Text(timeStr, style: kCaption.copyWith(fontSize: 11)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: kRadiusFull,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(statusLabel(status),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onUnsave,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3F3),
              borderRadius: kRadius8,
            ),
            child: const Icon(Icons.bookmark_remove_rounded, color: Colors.redAccent, size: 18),
          ),
        ),
      ]),
    );
  }
}