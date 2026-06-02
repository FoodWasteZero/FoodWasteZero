import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../cards/org_stat_sheet.dart';
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
        final data = doc.data();
        final userType = data?['userType'] ?? 'uporabnik';
        
        // Za uporabnike: firstName + surname, za organizacije: organizationName
        String displayName = _displayName;
        if (userType == 'uporabnik') {
          final firstName = data?['firstName'] as String? ?? '';
          final surname = data?['surname'] as String? ?? '';
          if (firstName.isNotEmpty || surname.isNotEmpty) {
            displayName = '$firstName $surname'.trim();
          }
        } else {
          final orgName = data?['organizationName'] as String?;
          if (orgName != null && orgName.isNotEmpty) {
            displayName = orgName;
          }
        }
        
        setState(() {
          _displayName = displayName;
          _userType = userType;
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
          SnackBar(
              content: Text('Napaka pri odjavi: $e'),
              backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _showEditProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Učita korisnikove podatke iz Firestora
    String firstName = '';
    String surname = '';
    String organizationName = '';
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (_userType == 'davatelj') {
          organizationName = data?['organizationName'] as String? ?? '';
        } else {
          firstName = data?['firstName'] as String? ?? '';
          surname = data?['surname'] as String? ?? '';
        }
      }
    } catch (_) {}

    final firstNameCtrl = TextEditingController(text: firstName);
    final surnameCtrl = TextEditingController(text: surname);
    final orgNameCtrl = TextEditingController(text: organizationName);
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
        builder: (ctx, setModal) {
          final mq = MediaQuery.of(ctx);
          final bottomInset = mq.viewInsets.bottom;
          final safeBottom = mq.padding.bottom;
          // Ko je tipkovnica odprta, viewInsets.bottom že vključuje prostor zanjo;
          // ko je zaprta, dodamo safe area (npr. home indicator na iPhoneu).
          final extraBottom = bottomInset > 0 ? 0.0 : safeBottom;
          return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + extraBottom),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Uredi profil',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: kTextDark)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: kTextMid),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_userType == 'davatelj') ...[
                  _EditField(
                      ctrl: orgNameCtrl,
                      label: 'Ime organizacije',
                      icon: Icons.store_rounded),
                ] else ...[
                  _EditField(
                      ctrl: firstNameCtrl,
                      label: 'Prvo ime',
                      icon: Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _EditField(
                      ctrl: surnameCtrl,
                      label: 'Priimek',
                      icon: Icons.person_outline_rounded),
                ],
                const SizedBox(height: 12),
                _EditField(
                    ctrl: emailCtrl,
                    label: 'E-pošta',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),
                const Text('Novo geslo (pustite prazno, če ne menjate)',
                    style: TextStyle(
                        fontSize: 12,
                        color: kTextMid,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _EditField(
                  ctrl: pwCtrl,
                  label: 'Novo geslo',
                  icon: Icons.lock_outline_rounded,
                  obscure: obscurePw,
                  suffix: IconButton(
                    onPressed: () =>
                        setModal(() => obscurePw = !obscurePw),
                    icon: Icon(
                        obscurePw
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: kTextLight,
                        size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                _EditField(
                  ctrl: pw2Ctrl,
                  label: 'Ponovi geslo',
                  icon: Icons.lock_outline_rounded,
                  obscure: obscurePw2,
                  suffix: IconButton(
                    onPressed: () =>
                        setModal(() => obscurePw2 = !obscurePw2),
                    icon: Icon(
                        obscurePw2
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: kTextLight,
                        size: 20),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final newFirstName = firstNameCtrl.text.trim();
                            final newSurname = surnameCtrl.text.trim();
                            final newOrgName = orgNameCtrl.text.trim();
                            final newEmail = emailCtrl.text.trim();
                            final newPw = pwCtrl.text.trim();
                            final newPw2 = pw2Ctrl.text.trim();
                            
                            if (newPw.isNotEmpty && newPw != newPw2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Gesli se ne ujemata'),
                                    backgroundColor: Colors.red),
                              );
                              return;
                            }
                            setModal(() => saving = true);
                            try {
                              final user =
                                  FirebaseAuth.instance.currentUser!;
                              
                              // Update imena
                              String displayNameToSave = '';
                              final updateData = <String, dynamic>{};
                              
                              if (_userType == 'davatelj') {
                                if (newOrgName != organizationName) {
                                  displayNameToSave = newOrgName;
                                  updateData['organizationName'] = newOrgName;
                                  updateData['ime'] = newOrgName;
                                }
                              } else {
                                if (newFirstName != firstName || newSurname != surname) {
                                  displayNameToSave = '$newFirstName $newSurname'.trim();
                                  updateData['firstName'] = newFirstName;
                                  updateData['surname'] = newSurname;
                                  updateData['ime'] = displayNameToSave;
                                }
                              }
                              
                              if (displayNameToSave.isNotEmpty) {
                                await user.updateDisplayName(displayNameToSave);
                                updateData.forEach((key, value) async {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .update({key: value});
                                });
                              }
                              
                              if (newEmail != _email && newEmail.isNotEmpty) {
                                await user.verifyBeforeUpdateEmail(newEmail);
                              }
                              if (newPw.isNotEmpty) {
                                await user.updatePassword(newPw);
                              }
                              if (mounted) {
                                setState(() {
                                  _displayName = displayNameToSave.isNotEmpty
                                      ? displayNameToSave
                                      : _displayName;
                                  _email = newEmail;
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Profil posodobljen ✓')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Napaka: $e'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              setModal(() => saving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreenMid,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(14))),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Shrani spremembe',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                  ),
                ),
              ],
            ),
            ),
          ),
        );
        },
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
  bool get _isGuest =>
      isAppGuest(FirebaseAuth.instance.currentUser);

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
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
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
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                      color: kGreenPale, borderRadius: kRadiusFull),
                  child: const Icon(Icons.person_outline_rounded,
                      size: 52, color: kGreenMid),
                ),
                const SizedBox(height: 24),
                const Text('Niste prijavljeni',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kTextDark)),
                const SizedBox(height: 10),
                const Text(
                  'Prijavite se ali se registrirajte, da dostopate do profila in svojih oglasov.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: kTextMid, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _showAuthPopup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreenMid,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                          borderRadius: kRadius12),
                    ),
                    child: const Text('Prijava / Registracija',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white)),
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
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileHeader(),
                  _UporabnikStatsRow(uid: user.uid),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                tabBar: _buildTabBar(),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildRezervacijeTab(user.uid),
              _buildPrevzetoTab(user.uid),
              _buildAccountTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius16,
        boxShadow: kCardShadow,
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
          ),
          borderRadius: kRadius12,
          boxShadow: [
            BoxShadow(
              color: kGreenMid.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: kTextMid,
        labelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: [
          Tab(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_rounded, size: 15),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'Rezervirano',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle_rounded, size: 15),
                SizedBox(width: 5),
                Text('Prevzeto'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.person_rounded, size: 15),
                SizedBox(width: 5),
                Text('Oddaje'),
              ],
            ),
          ),
        ],
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
            const SizedBox(height: 4),
            Expanded(
              child: _buildDavateljOglasi(user.uid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDavateljOglasi(String uid) {
    return _buildDavateljContent(uid);
  }

  Widget _buildDavateljContent(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: kGreenMid));
        }
        if (snap.hasError) {
          return _buildEmptyState(
              'Napaka pri nalaganju', Icons.error_outline_rounded,
              subtitle: 'Preverite internetno povezavo.');
        }

        final allDocs = snap.data?.docs ?? [];

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
        final steviloRezerviranih = allDocs
            .where((d) {
              final s = (d.data() as Map)['status'] as String? ?? '';
              return s == 'rezervirano';
            })
            .length;

        // Izračunaj grame in CO₂ iz vseh prevzetih objav organizacije
        int totalGrams = 0;
        int totalPorcij = 0;
        final Map<String, int> gramsPerCat = {
          'Kuhano': 350, 'Peka': 200, 'Sadje & zelenjava': 500,
          'Sestavine': 400, 'Ostalo': 300,
        };
        for (final doc in arhiv) {
          final d = doc.data() as Map<String, dynamic>;
          final cat = d['category'] as String? ?? 'Ostalo';
          final portions = (d['portions'] as num?)?.toInt() ?? 1;
          final gramsPerUnit = gramsPerCat[cat] ?? 300;
          totalGrams += gramsPerUnit * portions;
          totalPorcij += portions;
        }
        final co2Kg = (totalGrams / 1000) * 2.5;

        // Trend: objave v zadnjih 7 dneh
        final now7 = DateTime.now();
        final thisWeek = allDocs.where((d) {
          final ts = (d.data() as Map)['createdAt'] as Timestamp?;
          if (ts == null) return false;
          return now7.difference(ts.toDate()).inDays <= 7;
        }).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          children: [
            _DavateljAnalyticsSection(
              totalObjav: totalObjav,
              prevzetih: steviloPrevzetih,
              rezerviranih: steviloRezerviranih,
              totalGrams: totalGrams,
              totalPorcij: totalPorcij,
              co2Kg: co2Kg,
              thisWeek: thisWeek,
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                    color: kGreenMid, borderRadius: kRadiusFull),
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
              // Do not show the inline "Prevzeto" button in the org profile list
              showMarkPrevzeto: false,
              onTap: () => FoodDetailSheet.show(
                  context, _docToOglasProfile(doc)),
                )),
            if (arhiv.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                      color: kTextLight, borderRadius: kRadiusFull),
                ),
                const SizedBox(width: 8),
                Text('Arhiv — prevzeto (${arhiv.length})',
                    style: kHeading3.copyWith(
                        fontSize: 15, color: kTextMid)),
              ]),
              const SizedBox(height: 10),
              ...arhiv.map((doc) => _DavateljOglasCard(
                    doc: doc,
                    showMarkPrevzeto: false,
                    onTap: () => FoodDetailSheet.show(
                        context, _docToOglasProfile(doc)),
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
          .collection('rezervacije')
          .where('userId', isEqualTo: uid)
          .where('status', whereIn: ['rezervirano', 'na_voljo'])
          .snapshots(),
      builder: (context, rezSnap) {
        if (rezSnap.connectionState == ConnectionState.waiting &&
            !rezSnap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: kGreenMid));
        }
        if (rezSnap.hasError) {
          return _buildEmptyState(
              'Napaka pri nalaganju', Icons.error_outline_rounded);
        }
        final rezDocs = rezSnap.data?.docs ?? [];
        if (rezDocs.isEmpty) {
          return _buildEmptyState(
            'Ni aktivnih rezervacij',
            Icons.bookmark_outline_rounded,
            subtitle:
                'Ko si rezervirate oglas na domači strani, se bo prikazal tukaj.',
          );
        }
        final oglasIds = rezDocs
            .map((d) => (d.data() as Map)['oglasId'] as String? ?? '')
            .toSet()
            .toList();
        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(
            oglasIds.map((id) =>
                FirebaseFirestore.instance.collection('oglasi').doc(id).get()),
          ),
          builder: (context, oglasSnap) {
            final oglasMap = <String, DocumentSnapshot>{};
            if (oglasSnap.hasData) {
              for (final doc in oglasSnap.data!) {
                if (doc.exists) oglasMap[doc.id] = doc;
              }
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
              itemCount: rezDocs.length,
              itemBuilder: (_, i) {
                final rezData = rezDocs[i].data() as Map<String, dynamic>;
                final oglasId = rezData['oglasId'] as String? ?? '';
                final oglasDoc = oglasMap[oglasId];
                return _RezervacijaCard(
                  rezData: rezData,
                  oglasDoc: oglasDoc,
                  onTap: oglasDoc == null
                      ? null
                      : () => FoodDetailSheet.show(
                          context, _docToOglasProfile(oglasDoc)),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPrevzetoTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rezervacije')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'prevzeto')
          .snapshots(),
      builder: (context, rezSnap) {
        if (rezSnap.connectionState == ConnectionState.waiting &&
            !rezSnap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: kGreenMid));
        }
        if (rezSnap.hasError) {
          return _buildEmptyState(
              'Napaka pri nalaganju', Icons.error_outline_rounded);
        }
        final rezDocs = rezSnap.data?.docs ?? [];
        if (rezDocs.isEmpty) {
          return _buildEmptyState(
            'Ni prevzetih obrokov',
            Icons.check_circle_outline_rounded,
            subtitle:
                'Tukaj se bodo prikazali oglasi, ki ste jih že prevzeli.',
          );
        }
        final oglasIds = rezDocs
            .map((d) => (d.data() as Map)['oglasId'] as String? ?? '')
            .toSet()
            .toList();
        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(
            oglasIds.map((id) =>
                FirebaseFirestore.instance.collection('oglasi').doc(id).get()),
          ),
          builder: (context, oglasSnap) {
            final oglasMap = <String, DocumentSnapshot>{};
            if (oglasSnap.hasData) {
              for (final doc in oglasSnap.data!) {
                if (doc.exists) oglasMap[doc.id] = doc;
              }
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
              itemCount: rezDocs.length,
              itemBuilder: (_, i) {
                final rezData = rezDocs[i].data() as Map<String, dynamic>;
                final oglasId = rezData['oglasId'] as String? ?? '';
                final oglasDoc = oglasMap[oglasId];
                return _RezervacijaCard(
                  rezData: rezData,
                  oglasDoc: oglasDoc,
                  isPrevzeto: true,
                );
              },
            );
          },
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
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: kRadiusFull,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: Icon(
                  isDav
                      ? Icons.store_rounded
                      : Icons.person_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
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
                      children: [
                        Icon(
                            isDav
                                ? Icons.volunteer_activism_rounded
                                : Icons.search_rounded,
                            color: Colors.amber,
                            size: 13),
                        const SizedBox(width: 4),
                        Text(
                          isDav ? 'Organizacija' : 'Uporabnik',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ]),
                ),
              ],
            ),
          ),
          Column(
            children: [
              _HeaderBtn(icon: Icons.edit_rounded, onTap: _showEditProfile),
              const SizedBox(height: 8),
              _HeaderBtn(
                  icon: Icons.logout_rounded, onTap: _logout, dimmed: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTab() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('oglasi').snapshots(),
      builder: (context, snapshot) {
        final allOglasi = snapshot.hasData
            ? snapshot.data!.docs.map(_docToOglasProfile).toList()
            : <FoodOglas>[];
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildUpcomingPickups(allOglasi, user?.uid),
            const SizedBox(height: 24),
          
          ],
        );
      },
    );
  }

  // ── Prihodnji prevzemi ─────────────────────────────
  Widget _buildUpcomingPickups(List<FoodOglas> allOglasi, String? uid) {
    final now = DateTime.now();
    final myOglasi = uid == null
        ? allOglasi
        : allOglasi.where((o) => o.uid == uid).toList();
    final List<_UpcomingPickup> upcoming = [];
    for (final oglas in myOglasi) {
      if (oglas.status == OglasStatus.prevzeto) continue;
      final termini = [oglas.termin1]
              .where((t) => t != null && t!.isAfter(now))
              .cast<DateTime>()
              .toList()
            ..sort();
      for (final t in termini) {
        upcoming.add(_UpcomingPickup(oglas: oglas, termin: t));
        break;
      }
    }
    upcoming.sort((a, b) => a.termin.compareTo(b.termin));
    final show = upcoming.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 17, color: kGreenMid),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Prihajajoči prevzemi',
                    style: kHeading3.copyWith(fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (show.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: kRadius12,
                border: Border.all(color: kBorder),
              ),
              child: const Center(
                child: Column(children: [
                  Icon(Icons.event_available_rounded,
                      color: kTextLight, size: 32),
                  SizedBox(height: 8),
                  Text('Ni prihodnjih prevzemov',
                      style: TextStyle(color: kTextLight, fontSize: 14)),
                ]),
              ),
            )
          else
            ...show.map((p) => _UpcomingPickupTile(
                  pickup: p,
                  onTap: () => OrgStatSheet.show(context, p.oglas),
                )),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String label, IconData icon, {String? subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: kGreenPale, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: kGreenMid),
            ),
            const SizedBox(height: 16),
            Text(label, style: kHeading3, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle,
                  style: const TextStyle(
                      color: kTextLight, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
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
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label, style: kBodyBold.copyWith(color: kTextMid)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: kTextLight)),
            ])),
      ]),
    );
  }
}

// ─── HELPER FUNKCIJE ZA ANALITIKO ────────────────────────────────────────
int _gramsForCategoryA(String cat, int portions) {
  const Map<String, int> gramsPerUnit = {
    'Kuhano': 350, 'Peka': 200, 'Sadje & zelenjava': 500,
    'Sestavine': 400, 'Ostalo': 300,
  };
  return (gramsPerUnit[cat] ?? 300) * portions;
}

double _co2SavedA(int totalGrams) => (totalGrams / 1000) * 2.5;

int _computeStreakA(List<DateTime> dates) {
  if (dates.isEmpty) return 0;
  final sorted = [...dates]..sort((a, b) => b.compareTo(a));
  int streak = 0;
  DateTime cursor = DateTime.now();
  for (final d in sorted) {
    final dayOnly = DateTime(d.year, d.month, d.day);
    final cursorDay = DateTime(cursor.year, cursor.month, cursor.day);
    final diff = cursorDay.difference(dayOnly).inDays;
    if (diff <= 1) {
      streak++;
      cursor = dayOnly;
    } else {
      break;
    }
  }
  return streak;
}

// ─── UPORABNIK STATS ROW ─────────────────────────────────────────────────────
class _UporabnikStatsRow extends StatelessWidget {
  final String uid;
  const _UporabnikStatsRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rezervacije')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Center(child: CircularProgressIndicator(color: kGreenMid, strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Napaka pri nalaganju analitike.',
                style: TextStyle(color: kTextLight, fontSize: 12)),
          );
        }
        final docs = snap.data?.docs ?? [];
        final prevzetoDocs = docs.where((d) => (d.data() as Map)['status'] == 'prevzeto').toList();
        final rezerviranoDocs = docs.where((d) {
          final s = (d.data() as Map)['status'] as String? ?? '';
          return s == 'rezervirano' || s == 'na_voljo';
        }).toList();

        int totalGrams = 0;
        int totalPorcij = 0;
        final prevzetoDates = <DateTime>[];

        for (final doc in prevzetoDocs) {
          final d = doc.data() as Map<String, dynamic>;
          final portions = (d['kolicinaPorcij'] as num?)?.toInt() ?? 1;
          totalPorcij += portions;
          // Use a fixed estimate per portion for CO2/grams since category is on the oglas
          totalGrams += 350 * portions;
          final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
          if (createdAt != null) prevzetoDates.add(createdAt);
        }

        final co2 = _co2SavedA(totalGrams);
        final streak = _computeStreakA(prevzetoDates);

        final gramsLabel = totalGrams >= 1000
            ? '${(totalGrams / 1000).toStringAsFixed(1)} kg'
            : '${totalGrams} g';
        final co2Label = co2 >= 1
            ? '${co2.toStringAsFixed(1)} kg'
            : '${(co2 * 1000).toStringAsFixed(0)} g';

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(width: 4, height: 16,
                      decoration: BoxDecoration(color: kGreenMid, borderRadius: kRadiusFull)),
                  const SizedBox(width: 8),
                  const Text('Vaša analitika', style: kHeading3),
                ]),
              ),
              Row(children: [
                Expanded(child: _AnalyticCard(
                  value: gramsLabel,
                  label: 'Hrane rešeno',
                  icon: Icons.scale_rounded,
                  color: kGreenMid,
                  subtitle: '${prevzetoDocs.length} obrokov prevzeto',
                )),
                const SizedBox(width: 10),
                Expanded(child: _AnalyticCard(
                  value: co2Label,
                  label: 'CO₂ prihranek',
                  icon: Icons.eco_rounded,
                  color: const Color(0xFF00897B),
                  subtitle: 'prihranjenega CO₂',
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _AnalyticCard(
                  value: '$totalPorcij',
                  label: 'Skupaj porcij',
                  icon: Icons.restaurant_rounded,
                  color: const Color(0xFF5C6BC0),
                  subtitle: 'skupaj porcij',
                )),
                const SizedBox(width: 10),
                Expanded(child: _AnalyticCard(
                  value: '$streak',
                  label: 'Dnevi zapored',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFE53935),
                  subtitle: streak > 0 ? 'aktivni streak! 🔥' : 'začni danes',
                )),
                const SizedBox(width: 10),
                Expanded(child: _AnalyticCard(
                  value: '${rezerviranoDocs.length}',
                  label: 'Čaka prevzem',
                  icon: Icons.bookmark_rounded,
                  color: kOrange,
                  subtitle: 'aktivnih rezervacij',
                )),
              ]),
            ],
          ),
        );
      },
    );
  }
}
class _AnalyticCard extends StatelessWidget {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AnalyticCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        boxShadow: kCardShadow,
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: kRadius8,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color, height: 1)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextDark)),
          const SizedBox(height: 1),
          Text(subtitle,
              style: const TextStyle(fontSize: 10, color: kTextLight),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}


// ─── DAVATELJ ANALYTICS SECTION ──────────────────────────────────────────────

class _DavateljAnalyticsSection extends StatelessWidget {
  final int totalObjav;
  final int prevzetih;
  final int rezerviranih;
  final int totalGrams;
  final int totalPorcij;
  final double co2Kg;
  final int thisWeek;

  const _DavateljAnalyticsSection({
    required this.totalObjav,
    required this.prevzetih,
    required this.rezerviranih,
    required this.totalGrams,
    required this.totalPorcij,
    required this.co2Kg,
    required this.thisWeek,
  });

  @override
  Widget build(BuildContext context) {
    final gramsLabel = totalGrams >= 1000
        ? '${(totalGrams / 1000).toStringAsFixed(1)} kg'
        : '${totalGrams} g';
    final co2Label = co2Kg >= 1
        ? '${co2Kg.toStringAsFixed(1)} kg'
        : '${(co2Kg * 1000).toStringAsFixed(0)} g';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(width: 4, height: 16,
                decoration: BoxDecoration(color: kGreenMid, borderRadius: kRadiusFull)),
            const SizedBox(width: 8),
            const Text('Analitika organizacije', style: kHeading3),
          ]),
        ),
        Row(children: [
          Expanded(child: _AnalyticCard(
            value: '$totalObjav',
            label: 'Skupaj objav',
            icon: Icons.storefront_rounded,
            color: kGreenMid,
            subtitle: '$thisWeek ta teden',
          )),
          const SizedBox(width: 10),
          Expanded(child: _AnalyticCard(
            value: '$rezerviranih',
            label: 'Rezervirano',
            icon: Icons.bookmark_rounded,
            color: const Color(0xFFFF6F00),
            subtitle: 'čaka prevzem',
          )),
          const SizedBox(width: 10),
          Expanded(child: _AnalyticCard(
            value: '$prevzetih',
            label: 'Prevzeto',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF1565C0),
            subtitle: 'uspešnih dostav',
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _AnalyticCard(
            value: gramsLabel,
            label: 'Hrane rešeno',
            icon: Icons.scale_rounded,
            color: const Color(0xFF2E7D32),
            subtitle: 'skupaj rešene hrane',
          )),
          const SizedBox(width: 10),
          Expanded(child: _AnalyticCard(
            value: '$totalPorcij',
            label: 'Porcij oddano',
            icon: Icons.restaurant_rounded,
            color: const Color(0xFF5C6BC0),
            subtitle: 'skupaj porcij',
          )),
          const SizedBox(width: 10),
          Expanded(child: _AnalyticCard(
            value: co2Label,
            label: 'CO₂ prihranek',
            icon: Icons.eco_rounded,
            color: const Color(0xFF00897B),
            subtitle: 'skupaj prihranjenega',
          )),
        ]),
      ],
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
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: kTextDark)),
        content: const Text(
            'Ali je bila hrana uspešno prevzeta pri donatorju?',
            style: TextStyle(color: kTextMid, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Prekliči',
                style: TextStyle(color: kTextLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: kGreenMid,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: kRadius8)),
            child: const Text('Potrdi',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
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
    final imageBase64 = d['imageBase64'] as String?;
    final statusStr = d['status'] as String? ?? 'naRazpolago';
    final waitlistRaw = d['waitlist'];
    final waitlistLen =
        (waitlistRaw is List) ? waitlistRaw.length : 0;

    OglasStatus status;
    switch (statusStr) {
      case 'rezervirano':
        status = OglasStatus.rezervirano;
        break;
      case 'prevzeto':
        status = OglasStatus.prevzeto;
        break;
      default:
        status = OglasStatus.naRazpolago;
    }
    final statusClr = statusColor(status);

    final IconData icon;
    final Color bgColor;
    switch (category) {
      case 'Kuhano':
        icon = Icons.soup_kitchen_rounded;
        bgColor = const Color(0xFFFFE0B2);
        break;
      case 'Peka':
        icon = Icons.bakery_dining_rounded;
        bgColor = const Color(0xFFEFEBE9);
        break;
      case 'Sadje & zelenjava':
        icon = Icons.apple_rounded;
        bgColor = const Color(0xFFE8F5E9);
        break;
      case 'Ostalo':
        icon = Icons.more_horiz_rounded;
        bgColor = const Color(0xFFE8EAF6);
        break;
      default:
        icon = Icons.grass_rounded;
        bgColor = const Color(0xFFF1F8E9);
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
        child: ClipRRect(
          borderRadius: kRadius12,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Status accent strip ──────────────────────────
                Container(width: 4, color: statusClr),
                // ── Content ──────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                color: bgColor, borderRadius: kRadius12),
                            child: ClipRRect(
                              borderRadius: kRadius12,
                              child: imageBase64 != null
                                  ? _ProfileBase64Image(base64: imageBase64)
                                  : Icon(icon, color: kGreenMid, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                Text(title,
                                    style: kBodyBold,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 3),
                                Row(children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 12, color: kTextLight),
                                  const SizedBox(width: 3),
                                  Expanded(
                                      child: Text(location,
                                          style: kCaption,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis)),
                                ]),
                                const SizedBox(height: 3),
                                Row(children: [
                                  Icon(Icons.access_time_outlined,
                                      size: 12, color: kTextLight),
                                  const SizedBox(width: 3),
                                  Text(timeStr, style: kCaption),
                                ]),
                              ])),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusClr.withOpacity(0.1),
                              borderRadius: kRadiusFull,
                              border: Border.all(
                                  color: statusClr.withOpacity(0.3)),
                            ),
                            child: Text(statusLabel(status),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: statusClr)),
                          ),
                        ]),
                      ),

                      if (status == OglasStatus.rezervirano ||
                          waitlistLen > 0) ...[
                        Divider(
                            height: 1,
                            color: kBorder.withOpacity(0.6)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Row(children: [
                            if (status == OglasStatus.rezervirano) ...[
                              const Icon(
                                  Icons.person_outline_rounded,
                                  size: 13,
                                  color: kTextMid),
                              const SizedBox(width: 4),
                              const Text('Rezervirano',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: kTextMid,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(width: 12),
                            ],
                            if (waitlistLen > 0) ...[
                              const Icon(Icons.queue_rounded,
                                  size: 13,
                                  color: Color(0xFF5C6BC0)),
                              const SizedBox(width: 4),
                              Text('$waitlistLen v čakalni vrsti',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF5C6BC0),
                                      fontWeight: FontWeight.w600)),
                            ],
                            const Spacer(),
                            if (showMarkPrevzeto &&
                                status == OglasStatus.rezervirano)
                              GestureDetector(
                                onTap: () => _markPrevzeto(context),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5),
                                  decoration: BoxDecoration(
                                    color: kGreenMid,
                                    borderRadius: kRadius8,
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.check_rounded,
                                            size: 13,
                                            color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Prevzeto',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight:
                                                    FontWeight.w700)),
                                      ]),
                                ),
                              ),
                          ]),
                        ),
                      ],

                      if (showMarkPrevzeto &&
                          status == OglasStatus.naRazpolago) ...[
                        Divider(
                            height: 1,
                            color: kBorder.withOpacity(0.6)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              14, 8, 14, 10),
                          child: GestureDetector(
                            onTap: () => _markPrevzeto(context),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 9),
                              decoration: BoxDecoration(
                                color: kGreenPale,
                                borderRadius: kRadius8,
                                border: Border.all(
                                    color:
                                        kGreenMid.withOpacity(0.3)),
                              ),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                        Icons
                                            .check_circle_outline_rounded,
                                        size: 15,
                                        color: kGreenMid),
                                    SizedBox(width: 6),
                                    Text('Označi kot prevzeto',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: kGreenMid,
                                            fontWeight:
                                                FontWeight.w700)),
                                  ]),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── REZERVACIJA CARD (za uporabnikove rezervacije iz kolekcije 'rezervacije') ──

class _RezervacijaCard extends StatelessWidget {
  final Map<String, dynamic> rezData;
  final DocumentSnapshot? oglasDoc;
  final VoidCallback? onTap;
  final bool isPrevzeto;

  const _RezervacijaCard({
    required this.rezData,
    required this.oglasDoc,
    this.onTap,
    this.isPrevzeto = false,
  });

  @override
  Widget build(BuildContext context) {
    final oglasData = oglasDoc?.data() as Map<String, dynamic>?;
    final title = oglasData?['title'] as String? ?? '—';
    final category = oglasData?['category'] as String? ?? '';
    final location = oglasData?['location'] as String? ?? '';
    final username = oglasData?['username'] as String?;
    final imageBase64 = oglasData?['imageBase64'] as String?;
    final expiryDate = (oglasData?['expiryDate'] as Timestamp?)?.toDate();
    final chosenTermin = (rezData['chosenTermin'] as Timestamp?)?.toDate();
    final kolicina = (rezData['kolicinaPorcij'] as num?)?.toInt() ?? 1;
    final createdAt = (rezData['createdAt'] as Timestamp?)?.toDate();
    final statusStr = rezData['status'] as String? ?? 'rezervirano';

    final OglasStatus status;
    switch (statusStr) {
      case 'prevzeto':
        status = OglasStatus.prevzeto;
        break;
      case 'rezervirano':
        status = OglasStatus.rezervirano;
        break;
      default:
        status = OglasStatus.naRazpolago;
    }
    final statusClr = isPrevzeto ? kGreenMid.withOpacity(0.5) : statusColor(status);

    final IconData icon;
    final Color bgColor;
    switch (category) {
      case 'Kuhano':
        icon = Icons.soup_kitchen_rounded; bgColor = const Color(0xFFFFE0B2); break;
      case 'Peka':
        icon = Icons.bakery_dining_rounded; bgColor = const Color(0xFFEFEBE9); break;
      case 'Sadje & zelenjava':
        icon = Icons.apple_rounded; bgColor = const Color(0xFFE8F5E9); break;
      case 'Ostalo':
        icon = Icons.more_horiz_rounded; bgColor = const Color(0xFFE8EAF6); break;
      default:
        icon = Icons.grass_rounded; bgColor = const Color(0xFFF1F8E9);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          boxShadow: kCardShadow,
        ),
        child: ClipRRect(
          borderRadius: kRadius12,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: statusClr),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(color: bgColor, borderRadius: kRadius12),
                        child: ClipRRect(
                          borderRadius: kRadius12,
                          child: imageBase64 != null
                              ? _ProfileBase64Image(base64: imageBase64)
                              : Icon(icon, color: kGreenMid, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: kBodyBold.copyWith(fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (username != null) ...[
                              const SizedBox(height: 2),
                              Text('od $username',
                                  style: const TextStyle(
                                      fontSize: 12, color: kGreenMid, fontWeight: FontWeight.w600)),
                            ],
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.restaurant_rounded, size: 12, color: kTextLight),
                              const SizedBox(width: 3),
                              Text(
                                '$kolicina ${kolicina == 1 ? 'porcija' : kolicina < 5 ? 'porcije' : 'porcij'}',
                                style: kCaption,
                              ),
                            ]),
                            const SizedBox(height: 3),
                            Row(children: [
                              Icon(Icons.location_on_outlined, size: 12, color: kTextLight),
                              const SizedBox(width: 3),
                              Expanded(
                                  child: Text(location,
                                      style: kCaption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                            ]),
                            if (chosenTermin != null) ...[
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.event_available_rounded, size: 12, color: kGreenMid),
                                const SizedBox(width: 3),
                                Text(
                                  '${chosenTermin.day}.${chosenTermin.month}.${chosenTermin.year} '
                                  '${chosenTermin.hour.toString().padLeft(2, '0')}:${chosenTermin.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 12, color: kGreenMid, fontWeight: FontWeight.w600),
                                ),
                              ]),
                            ] else if (!isPrevzeto && expiryDate != null) ...[
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.event_outlined, size: 12, color: kTextLight),
                                const SizedBox(width: 3),
                                Text('Rok: ${expiryDate.day}. ${expiryDate.month}. ${expiryDate.year}',
                                    style: const TextStyle(fontSize: 12, color: kTextLight)),
                              ]),
                            ],
                            const SizedBox(height: 4),
                            Text(_timeAgo(createdAt),
                                style: const TextStyle(fontSize: 11, color: kTextLight)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusClr.withOpacity(0.1),
                              borderRadius: kRadiusFull,
                              border: Border.all(color: statusClr.withOpacity(0.3)),
                            ),
                            child: Text(
                              isPrevzeto ? 'PREVZETO' : statusLabel(status),
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w800, color: statusClr),
                            ),
                          ),
                          if (!isPrevzeto) ...[
                            const SizedBox(height: 8),
                            Icon(Icons.chevron_right_rounded, size: 20, color: kTextLight),
                          ],
                        ],
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
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
    final imageBase64 = d['imageBase64'] as String?;

    OglasStatus status;
    switch (statusStr) {
      case 'rezervirano':
        status = OglasStatus.rezervirano;
        break;
      case 'prevzeto':
        status = OglasStatus.prevzeto;
        break;
      default:
        status = OglasStatus.naRazpolago;
    }
    final statusClr = statusColor(status);

    final IconData icon;
    final Color bgColor;
    switch (category) {
      case 'Kuhano':
        icon = Icons.soup_kitchen_rounded;
        bgColor = const Color(0xFFFFE0B2);
        break;
      case 'Peka':
        icon = Icons.bakery_dining_rounded;
        bgColor = const Color(0xFFEFEBE9);
        break;
      case 'Sadje & zelenjava':
        icon = Icons.apple_rounded;
        bgColor = const Color(0xFFE8F5E9);
        break;
      case 'Ostalo':
        icon = Icons.more_horiz_rounded;
        bgColor = const Color(0xFFE8EAF6);
        break;
      default:
        icon = Icons.grass_rounded;
        bgColor = const Color(0xFFF1F8E9);
    }

    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    final expiryDate = (d['expiryDate'] as Timestamp?)?.toDate();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          boxShadow: kCardShadow,
        ),
        child: ClipRRect(
          borderRadius: kRadius12,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Colored left strip by status ─────────────────
                Container(
                  width: 4,
                  color: isPrevzeto
                      ? kGreenMid.withOpacity(0.4)
                      : statusClr,
                ),
                // ── Main content ─────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      // Slika ali ikona kategorije
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                            color: bgColor, borderRadius: kRadius12),
                        child: ClipRRect(
                          borderRadius: kRadius12,
                          child: imageBase64 != null
                              ? _ProfileBase64Image(base64: imageBase64)
                              : Icon(icon, color: kGreenMid, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Podatki
                      Expanded(
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: kBodyBold.copyWith(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (username != null) ...[
                            const SizedBox(height: 2),
                            Text('od $username',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: kGreenMid,
                                    fontWeight: FontWeight.w600)),
                          ],
                          const SizedBox(height: 5),
                          Row(children: [
                            Icon(Icons.location_on_outlined,
                                size: 12, color: kTextLight),
                            const SizedBox(width: 3),
                            Expanded(
                                child: Text(location,
                                    style: kCaption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          ]),
                          if (!isPrevzeto && expiryDate != null) ...[
                            const SizedBox(height: 3),
                            Row(children: [
                              Icon(Icons.event_outlined,
                                  size: 12, color: kTextLight),
                              const SizedBox(width: 3),
                              Text(
                                  'Rok: ${_formatDate(expiryDate)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: kTextLight)),
                            ]),
                          ],
                          const SizedBox(height: 4),
                          Text(_timeAgo(createdAt),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: kTextLight)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      // Desna stran — status badge + chevron
                      Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusClr.withOpacity(0.1),
                            borderRadius: kRadiusFull,
                            border: Border.all(
                                color: statusClr.withOpacity(0.3)),
                          ),
                          child: Text(statusLabel(status),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: statusClr)),
                        ),
                        if (!isPrevzeto) ...[
                          const SizedBox(height: 8),
                          Icon(Icons.chevron_right_rounded,
                              size: 20, color: kTextLight),
                        ],
                      ]),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── STICKY TAB BAR DELEGATE ────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  const _StickyTabBarDelegate({required this.tabBar});

  // 4px padding below tab bar + ~52px tab bar height + 4px top gap = ~60
  @override double get minExtent => 60;
  @override double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: kSurface,
      padding: const EdgeInsets.only(bottom: 4),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) => old.tabBar != tabBar;
}

// ─── SHARED HELPERS ────────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dimmed;

  const _HeaderBtn(
      {required this.icon, required this.onTap, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(dimmed ? 0.12 : 0.2),
          borderRadius: kRadius12,
          border: Border.all(
              color:
                  Colors.white.withOpacity(dimmed ? 0.2 : 0.35)),
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

String _formatDate(DateTime dt) =>
    '${dt.day}. ${dt.month}. ${dt.year}';

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
    case 'Ostalo':
      icon = Icons.more_horiz_rounded;
      color = const Color(0xFFE8EAF6);
      break;
    default:
      icon = Icons.grass_rounded;
      color = const Color(0xFFF1F8E9);
  }
  final lat = (d['lat'] as num?)?.toDouble();
  final lng = (d['lng'] as num?)?.toDouble();
  final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
  final expiryDate = (d['expiryDate'] as Timestamp?)?.toDate();
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
    expiryDate: expiryDate,
    termin1: (d['termin1'] as Timestamp?)?.toDate(),
    waitlist: waitlist,
  );
}

// ── Prihodnji prevzemi – model & tile ────────────────────────────────────────

class _UpcomingPickup {
  final FoodOglas oglas;
  final DateTime termin;
  const _UpcomingPickup({required this.oglas, required this.termin});
}

class _UpcomingPickupTile extends StatelessWidget {
  final _UpcomingPickup pickup;
  final VoidCallback onTap;
  const _UpcomingPickupTile({required this.pickup, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = pickup;
    final timeStr =
        '${p.termin.day}. ${p.termin.month}. ${p.termin.year}  ${p.termin.hour.toString().padLeft(2, '0')}:${p.termin.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: p.oglas.imageColor, borderRadius: kRadius8),
              child: Icon(p.oglas.icon, size: 18, color: kGreenDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.oglas.title,
                      style: kBodyBold.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.schedule_rounded,
                        size: 12, color: kTextLight),
                    const SizedBox(width: 4),
                    Text(timeStr,
                        style: const TextStyle(
                            fontSize: 12, color: kTextLight)),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: kTextLight),
          ],
        ),
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
    required this.ctrl,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: kSurface,
          borderRadius: kRadius12,
          border: Border.all(color: kBorder)),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ── Base64 slika za profile kartice ───────────────────────────────────────────
class _ProfileBase64Image extends StatelessWidget {
  final String base64;
  const _ProfileBase64Image({required this.base64});

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(base64);
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}