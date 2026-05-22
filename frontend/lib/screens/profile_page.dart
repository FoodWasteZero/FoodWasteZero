import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../cards/food_detail_sheet.dart';
import 'auth_screen.dart';
import '../common/auth_helpers.dart';

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
      await ensureFirestoreAccess();
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
                            backgroundColor: Colors.red));
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
  bool get _isGuest => isAppGuest(FirebaseAuth.instance.currentUser);

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
    if (_isGuest) return _buildGuestView();
    return _isDavatelj ? _buildDavateljView() : _buildUporabnikView();
  }

  // ─── GUEST ────────────────────────────────────────────────────────────────

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

  // ─── UPORABNIK ────────────────────────────────────────────────────────────

  Widget _buildUporabnikView() {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 4),
            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.bookmark_rounded, size: 15),
                      SizedBox(width: 5),
                      Text('Rezervirano'),
                    ]),
                  ),
                  Tab(
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.check_circle_rounded, size: 15),
                      SizedBox(width: 5),
                      Text('Prevzeto'),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildRezervacijeTab(user.uid),
                  _buildPrevzetoTab(user.uid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DAVATELJ (ORGANIZACIJA) ──────────────────────────────────────────────

  Widget _buildDavateljView() {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileHeader(),
            Expanded(child: _buildDavateljContent(user.uid)),
          ],
        ),
      ),
    );
  }

  Widget _buildDavateljContent(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreenMid));
        }
        if (snap.hasError) {
          return _buildEmptyState('Napaka pri nalaganju', Icons.error_outline_rounded,
              subtitle: 'Preverite internetno povezavo.');
        }

        final allDocs = snap.data?.docs ?? [];

        // Sortiraj po createdAt
        allDocs.sort((a, b) {
          final ta = (a.data() as Map)['createdAt'] as Timestamp?;
          final tb = (b.data() as Map)['createdAt'] as Timestamp?;
          final ma = ta?.millisecondsSinceEpoch ?? 0;
          final mb = tb?.millisecondsSinceEpoch ?? 0;
          return mb.compareTo(ma);
        });

        final aktivni = allDocs.where((d) {
          final s = (d.data() as Map)['status'] as String? ?? '';
          return s == 'naRazpolago' || s == 'rezervirano';
        }).toList();

        final arhiv = allDocs.where((d) {
          final s = (d.data() as Map)['status'] as String? ?? '';
          return s == 'prevzeto';
        }).toList();

        final totalObjav = allDocs.length;
        final steviloPrevzetih = arhiv.length;
        final steviloRezerviranih = aktivni
            .where((d) => (d.data() as Map)['status'] == 'rezervirano')
            .length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          children: [
            // Statistike
            _DavateljStatsRow(
              totalObjav: totalObjav,
              prevzetih: steviloPrevzetih,
              rezerviranih: steviloRezerviranih,
            ),
            const SizedBox(height: 20),

            // Aktivne objave
            Row(children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(color: kGreenMid, borderRadius: kRadiusFull),
              ),
              const SizedBox(width: 8),
              Text('Aktivne objave (${aktivni.length})',
                style: kHeading3.copyWith(fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            if (aktivni.isEmpty)
              _buildInlineEmpty('Ni aktivnih objav',
                  'Kliknite + za dodajanje novega oglasa.'),
            ...aktivni.map((doc) => _DavateljOglasCard(
              doc: doc,
              showMarkPrevzeto: true,
              onTap: () => FoodDetailSheet.show(context, _docToOglasProfile(doc)),
            )),

            if (arhiv.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 4, height: 18,
                  decoration: BoxDecoration(color: kTextLight, borderRadius: kRadiusFull),
                ),
                const SizedBox(width: 8),
                Text('Arhiv — prevzeto (${arhiv.length})',
                  style: kHeading3.copyWith(fontSize: 15, color: kTextMid)),
              ]),
              const SizedBox(height: 10),
              ...arhiv.map((doc) => _DavateljOglasCard(
                doc: doc,
                showMarkPrevzeto: false,
                onTap: () => FoodDetailSheet.show(context, _docToOglasProfile(doc)),
              )),
            ],
          ],
        );
      },
    );
  }

  // ─── UPORABNIK TABOVI ─────────────────────────────────────────────────────

  Widget _buildRezervacijeTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('reservedByUid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreenMid));
        }
        if (snap.hasError) {
          return _buildEmptyState('Napaka pri nalaganju', Icons.error_outline_rounded);
        }
        final docs = (snap.data?.docs ?? []).where((doc) {
          return (doc.data() as Map)['status'] == 'rezervirano';
        }).toList();
        if (docs.isEmpty) {
          return _buildEmptyState(
            'Ni aktivnih rezervacij',
            Icons.bookmark_outline_rounded,
            subtitle: 'Ko si rezervirate oglas na domači strani, se bo prikazal tukaj.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          itemCount: docs.length,
          itemBuilder: (_, i) => _UporabnikOglasCard(
            doc: docs[i],
            onTap: () => FoodDetailSheet.show(context, _docToOglasProfile(docs[i])),
          ),
        );
      },
    );
  }

  Widget _buildPrevzetoTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('reservedByUid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kGreenMid));
        }
        if (snap.hasError) {
          return _buildEmptyState('Napaka pri nalaganju', Icons.error_outline_rounded);
        }
        final docs = (snap.data?.docs ?? []).where((doc) {
          return (doc.data() as Map)['status'] == 'prevzeto';
        }).toList();
        if (docs.isEmpty) {
          return _buildEmptyState(
            'Ni prevzetih obrokov',
            Icons.check_circle_outline_rounded,
            subtitle: 'Tukaj se bodo prikazali oglasi, ki ste jih že prevzeli.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          itemCount: docs.length,
          itemBuilder: (_, i) => _UporabnikOglasCard(
            doc: docs[i],
            isPrevzeto: true,
          ),
        );
      },
    );
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    final name = _displayName.isEmpty ? 'Uporabnik' : _displayName;
    final isDav = _isDavatelj;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDav
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [const Color(0xFF1565C0), const Color(0xFF1976D2)],
        ),
        borderRadius: kRadius16,
        boxShadow: kElevatedShadow,
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: kRadiusFull,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: Icon(
                  isDav ? Icons.store_rounded : Icons.person_rounded,
                  color: Colors.white, size: 30,
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: kRadiusFull,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(_email,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: kRadiusFull,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isDav ? Icons.volunteer_activism_rounded : Icons.search_rounded,
                      color: Colors.amber, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      isDav ? 'Organizacija' : 'Uporabnik',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),
          ),
          // Akcije
          Column(
            children: [
              _HeaderBtn(
                icon: Icons.edit_rounded,
                onTap: _showEditProfile,
              ),
              const SizedBox(height: 8),
              _HeaderBtn(
                icon: Icons.logout_rounded,
                onTap: _logout,
                dimmed: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String label, IconData icon, {String? subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: kGreenMid),
          ),
          const SizedBox(height: 16),
          Text(label, style: kHeading3, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle,
              style: const TextStyle(color: kTextLight, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  }

  Widget _buildInlineEmpty(String label, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Icon(Icons.inbox_rounded, size: 28, color: kBorder),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: kBodyBold.copyWith(color: kTextMid)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: kTextLight)),
        ])),
      ]),
    );
  }
}

// ─── DAVATELJ STATS ROW ────────────────────────────────────────────────────

class _DavateljStatsRow extends StatelessWidget {
  final int totalObjav;
  final int prevzetih;
  final int rezerviranih;

  const _DavateljStatsRow({
    required this.totalObjav,
    required this.prevzetih,
    required this.rezerviranih,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatBox(
        value: '$totalObjav',
        label: 'Skupaj objav',
        icon: Icons.storefront_rounded,
        color: kGreenMid,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatBox(
        value: '$rezerviranih',
        label: 'Rezervirano',
        icon: Icons.bookmark_rounded,
        color: const Color(0xFFFF6F00),
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatBox(
        value: '$prevzetih',
        label: 'Prevzeto',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF1565C0),
      )),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        boxShadow: kCardShadow,
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: kRadius8,
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(height: 8),
        Text(value,
          style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label,
          style: const TextStyle(fontSize: 11, color: kTextMid, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center),
      ]),
    );
  }
}

// ─── DAVATELJ OGLAS CARD ───────────────────────────────────────────────────

class _DavateljOglasCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final bool showMarkPrevzeto;
  final VoidCallback? onTap;

  const _DavateljOglasCard({
    required this.doc,
    required this.showMarkPrevzeto,
    this.onTap,
  });

  Future<void> _markPrevzeto(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: kRadius12),
        title: const Text('Označi kot prevzeto',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextDark)),
        content: const Text('Ali je bila hrana uspešno prevzeta pri donatorju?',
          style: TextStyle(color: kTextMid, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Prekliči', style: TextStyle(color: kTextLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreenMid, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: kRadius8)),
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
    final reservedByUid = d['reservedByUid'] as String?;
    final waitlistRaw = d['waitlist'];
    final waitlistLen = (waitlistRaw is List) ? waitlistRaw.length : 0;

    OglasStatus status;
    switch (statusStr) {
      case 'rezervirano': status = OglasStatus.rezervirano; break;
      case 'prevzeto': status = OglasStatus.prevzeto; break;
      default: status = OglasStatus.naRazpolago;
    }
    final statusClr = statusColor(status);

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
    final timeStr = _timeAgo(createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                // Ikona
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: bgColor, borderRadius: kRadius12),
                  child: Icon(icon, color: kGreenMid, size: 24),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                    style: kBodyBold,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 12, color: kTextLight),
                    const SizedBox(width: 3),
                    Expanded(child: Text(location,
                      style: kCaption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.access_time_outlined, size: 12, color: kTextLight),
                    const SizedBox(width: 3),
                    Text(timeStr, style: kCaption),
                  ]),
                ])),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusClr.withOpacity(0.1),
                    borderRadius: kRadiusFull,
                    border: Border.all(color: statusClr.withOpacity(0.3)),
                  ),
                  child: Text(statusLabel(status),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusClr)),
                ),
              ]),
            ),

            // Info vrstica: rezerviran s strani + čakalna vrsta
            if (status == OglasStatus.rezervirano || waitlistLen > 0) ...[
              Divider(height: 1, color: kBorder.withOpacity(0.6)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  if (reservedByUid != null && status == OglasStatus.rezervirano) ...[
                    const Icon(Icons.person_outline_rounded, size: 13, color: kTextMid),
                    const SizedBox(width: 4),
                    const Text('Rezervirano',
                      style: TextStyle(fontSize: 12, color: kTextMid, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                  ],
                  if (waitlistLen > 0) ...[
                    const Icon(Icons.queue_rounded, size: 13, color: Color(0xFF5C6BC0)),
                    const SizedBox(width: 4),
                    Text('$waitlistLen v čakalni vrsti',
                      style: const TextStyle(
                        fontSize: 12, color: Color(0xFF5C6BC0), fontWeight: FontWeight.w600)),
                  ],
                  const Spacer(),
                  // Gumb Označi prevzeto
                  if (showMarkPrevzeto && status == OglasStatus.rezervirano)
                    GestureDetector(
                      onTap: () => _markPrevzeto(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: kGreenMid,
                          borderRadius: kRadius8,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [
                          Icon(Icons.check_rounded, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Prevzeto',
                            style: TextStyle(
                              fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                ]),
              ),
            ],

            // Gumb Označi prevzeto za naRazpolago brez čakalne vrste (samo davatelj)
            if (showMarkPrevzeto && status == OglasStatus.naRazpolago) ...[
              Divider(height: 1, color: kBorder.withOpacity(0.6)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: GestureDetector(
                  onTap: () => _markPrevzeto(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: kGreenPale,
                      borderRadius: kRadius8,
                      border: Border.all(color: kGreenMid.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.check_circle_outline_rounded, size: 15, color: kGreenMid),
                      SizedBox(width: 6),
                      Text('Označi kot prevzeto',
                        style: TextStyle(
                          fontSize: 13, color: kGreenMid, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── UPORABNIK OGLAS CARD ──────────────────────────────────────────────────

class _UporabnikOglasCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final VoidCallback? onTap;
  final bool isPrevzeto;

  const _UporabnikOglasCard({
    required this.doc,
    this.onTap,
    this.isPrevzeto = false,
  });

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final title = d['title'] as String? ?? '—';
    final category = d['category'] as String? ?? '';
    final location = d['location'] as String? ?? '';
    final username = d['username'] as String?;
    final statusStr = d['status'] as String? ?? 'naRazpolago';

    OglasStatus status;
    switch (statusStr) {
      case 'rezervirano': status = OglasStatus.rezervirano; break;
      case 'prevzeto': status = OglasStatus.prevzeto; break;
      default: status = OglasStatus.naRazpolago;
    }
    final statusClr = statusColor(status);

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
    final expiryDate = (d['expiryDate'] as Timestamp?)?.toDate();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          boxShadow: kCardShadow,
          border: isPrevzeto
              ? null
              : Border.all(color: statusClr.withOpacity(0.2), width: 1.5),
        ),
        child: Row(children: [
          // Ikona kategorije
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: bgColor, borderRadius: kRadius12),
            child: Icon(icon, color: kGreenMid, size: 26),
          ),
          const SizedBox(width: 12),
          // Podaci
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                style: kBodyBold.copyWith(fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              if (username != null) ...[
                const SizedBox(height: 2),
                Text('od $username',
                  style: const TextStyle(fontSize: 12, color: kGreenMid, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 12, color: kTextLight),
                const SizedBox(width: 3),
                Expanded(child: Text(location,
                  style: kCaption, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              if (!isPrevzeto && expiryDate != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.event_outlined, size: 12, color: kTextLight),
                  const SizedBox(width: 3),
                  Text('Rok: ${_formatDate(expiryDate)}',
                    style: const TextStyle(fontSize: 12, color: kTextLight)),
                ]),
              ],
              const SizedBox(height: 4),
              Text(_timeAgo(createdAt),
                style: const TextStyle(fontSize: 11, color: kTextLight)),
            ]),
          ),
          const SizedBox(width: 8),
          // Desna strana
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: statusClr.withOpacity(0.1),
                borderRadius: kRadiusFull,
                border: Border.all(color: statusClr.withOpacity(0.3)),
              ),
              child: Text(statusLabel(status),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusClr)),
            ),
            if (!isPrevzeto) ...[
              const SizedBox(height: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: kTextLight),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ─── SHARED HELPERS ────────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dimmed;

  const _HeaderBtn({required this.icon, required this.onTap, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(dimmed ? 0.12 : 0.2),
          borderRadius: kRadius12,
          border: Border.all(color: Colors.white.withOpacity(dimmed ? 0.2 : 0.35)),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }
}

String _timeAgo(DateTime? dt) {
  if (dt == null) return 'Pravkar';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Pravkar';
  if (diff.inMinutes < 60) return 'Pred ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Pred ${diff.inHours} ur';
  return 'Pred ${diff.inDays} dni';
}

String _formatDate(DateTime dt) => '${dt.day}. ${dt.month}. ${dt.year}';

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
  final waitlistRaw = d['waitlist'];
  final waitlist = (waitlistRaw is List) ? waitlistRaw.map((e) => e.toString()).toList() : <String>[];
  return FoodOglas(
    id: doc.id,
    uid: d['uid'] as String?,
    title: d['title'] as String? ?? '',
    description: d['description'] as String? ?? '',
    location: d['location'] as String? ?? '',
    time: _timeAgo(createdAt),
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
