import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../common/theme.dart';
import '../models/models.dart';
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
    _tabCtrl = TabController(length: 2, vsync: this);
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

  // ── Guest view ─────────────────────────────────────────────────────────────
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

  // ── Logged in view — NestedScrollView za fix scroll buga ──────────────────
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
            _buildPrevzetoTab(user.uid),
            _buildRezervacijeTab(user.uid),
          ],
        ),
      ),
    );
  }

  // ── Profile header ─────────────────────────────────────────────────────────
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

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tab1Label = _isDavatelj ? 'Moje objave' : 'Prevzeto';
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
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_outline_rounded, size: 15),
            const SizedBox(width: 5),
            Text(tab1Label)])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.bookmark_outline_rounded, size: 15),
            const SizedBox(width: 5),
            Text(tab2Label)])),
        ],
      ),
    );
  }

  // ── Tab 1: Prevzeto (davatelj: objavljeni oglasi) ─────────────────────────
  // Za davatelje: njegovi oglasi
  // Za navadne: oglasi gdje je status=prevzeto in uid=on
  Widget _buildPrevzetoTab(String uid) {
    final query = _isDavatelj
        ? FirebaseFirestore.instance
            .collection('oglasi')
            .where('uid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
        : FirebaseFirestore.instance
            .collection('oglasi')
            .where('reservedByUid', isEqualTo: uid)
            .where('status', isEqualTo: 'prevzeto')
            .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreenMid));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _buildEmptyState(
            _isDavatelj ? 'Ni objavljenih oglasov' : 'Ni prevzetih obrokov',
            _isDavatelj ? Icons.storefront_rounded : Icons.check_circle_outline_rounded,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          itemCount: docs.length,
          itemBuilder: (_, i) => _OglasListCard(doc: docs[i]),
        );
      },
    );
  }

  // ── Tab 2: Rezervirano (davatelj: arhiv) ──────────────────────────────────
  // Za davatelje: arhivirani/prevzeti oglasi
  // Za navadne: oglasi kjer je reservedByUid == uid in status == rezervirano
  Widget _buildRezervacijeTab(String uid) {
    final query = _isDavatelj
        ? FirebaseFirestore.instance
            .collection('oglasi')
            .where('uid', isEqualTo: uid)
            .where('status', isEqualTo: 'prevzeto')
            .orderBy('createdAt', descending: true)
        : FirebaseFirestore.instance
            .collection('oglasi')
            .where('reservedByUid', isEqualTo: uid)
            .where('status', isEqualTo: 'rezervirano')
            .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreenMid));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _buildEmptyState(
            _isDavatelj ? 'Ni arhiviranih oglasov' : 'Ni aktivnih rezervacij',
            _isDavatelj ? Icons.archive_outlined : Icons.bookmark_outline_rounded,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          itemCount: docs.length,
          itemBuilder: (_, i) => _OglasListCard(doc: docs[i]),
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

// ── Oglas card za profil (iz Firestorea) ─────────────────────────────────────
class _OglasListCard extends StatelessWidget {
  final DocumentSnapshot doc;
  const _OglasListCard({required this.doc});

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
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}