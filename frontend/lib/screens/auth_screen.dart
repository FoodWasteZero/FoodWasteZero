// lib/screens/auth_screen.dart
// Zamijeni cijeli fajl. Sva Firebase/Firestore logika ostaje ista —
// dodat je samo blur + slide-up efekt u build().

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/theme.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {

  // ── Animacija ────────────────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double> _blurAnim;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  // ── Tab ──────────────────────────────────────────────────────────────────────
  late TabController _tabController;
  bool _isLoading = false;

  // ── Login ────────────────────────────────────────────────────────────────────
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl  = TextEditingController();
  bool _loginPassVisible = false;

  // ── Register ─────────────────────────────────────────────────────────────────
  final _regNameCtrl  = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl  = TextEditingController();
  final _regPass2Ctrl = TextEditingController();
  bool _regPassVisible = false;
  String _userType = 'uporabnik';

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _blurAnim = Tween<double>(begin: 0, end: 16).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.2, 0.75, curve: Curves.easeOut),
      ),
    );

    // Čekaj 900ms da se HomeScreen vidi, pa pokreni animaciju
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _animCtrl.forward();
      });
    });

  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _regPass2Ctrl.dispose();
    super.dispose();
  }

  // ── Error ─────────────────────────────────────────────────────────────────────
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: kRadius12),
      ),
    );
  }

  // ── Login ─────────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    final email = _loginEmailCtrl.text.trim();
    final pass  = _loginPassCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      _showError('Vnesite e-mail in geslo.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, password: pass);
    } on FirebaseAuthException catch (e) {
      _showError(_authError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────────
  Future<void> _register() async {
    final name  = _regNameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final pass  = _regPassCtrl.text.trim();
    final pass2 = _regPass2Ctrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      _showError('Izpolnite vsa polja.');
      return;
    }
    if (pass != pass2) {
      _showError('Gesli se ne ujemata.');
      return;
    }
    if (pass.length < 6) {
      _showError('Geslo mora imeti vsaj 6 znakov.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, password: pass);

      await FirebaseFirestore.instance
        .collection('users')
        .doc(cred.user!.uid)
        .set({
          'uid':       cred.user!.uid,
          'ime':       name,
          'email':     email,
          'userType':  _userType,
          'createdAt': FieldValue.serverTimestamp(),
        });

      await cred.user!.updateDisplayName(name);
    } on FirebaseAuthException catch (e) {
      _showError(_authError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':      return 'Uporabnik ne obstaja.';
      case 'wrong-password':      return 'Napačno geslo.';
      case 'invalid-email':       return 'Neveljaven e-mail.';
      case 'email-already-in-use':return 'E-mail je že v uporabi.';
      case 'weak-password':       return 'Geslo je prešibko.';
      case 'invalid-credential':  return 'Napačen e-mail ali geslo.';
      default:                    return 'Napaka: $code';
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // 1. HomeScreen u pozadini (bez interakcije)
        const IgnorePointer(
          child: Material(
            child: HomeScreen(),
          ),
        ),

        // 2. Blur overlay
        AnimatedBuilder(
          animation: _blurAnim,
          builder: (_, __) {
            if (_blurAnim.value < 0.01) return const SizedBox.shrink();
            return BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _blurAnim.value,
                sigmaY: _blurAnim.value,
              ),
              child: Container(
                color: Colors.black.withOpacity(
                  0.22 * (_blurAnim.value / 16),
                ),
              ),
            );
          },
        ),

        // 3. Auth kartica klizi odozdo
        AnimatedBuilder(
          animation: _animCtrl,
          builder: (context, _) {
            return Positioned(
              left: 0, right: 0, bottom: 0,
              child: Transform.translate(
                offset: Offset(0, screenH * 0.6 * _slideAnim.value),
                child: Opacity(
                  opacity: _fadeAnim.value,
                  child: Material(
                    color: Colors.transparent,
                    child: _buildCard(context),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

    // ── Kartica (nije fullscreen) ─────────────────────────────────────────────────
  Widget _buildCard(BuildContext context) {
    return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Color(0x40000000), blurRadius: 48, offset: Offset(0, -8)),
            BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle 
            const SizedBox(height: 14),
            Center(
              child: Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Logo + naziv
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withOpacity(0.4),
                        blurRadius: 14, offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FoodWasteZero',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                      color: Color(0xFF1A2E1A), letterSpacing: -0.3)),
                  Text('Reši hrano. Pomagaj skupnosti.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: kTextMid,
                indicator: BoxDecoration(
                  color: kGreenMid,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: kGreenMid.withOpacity(0.4),
                      blurRadius: 10, offset: const Offset(0, 3),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                tabs: const [
                  Tab(text: 'Prijava'),
                  Tab(text: 'Registracija'),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Tab content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginTab(),
                  _buildRegisterTab(),
                ],
              ),
            ),
          ],
        ),
    );
  }
  

  // ── Login tab ─────────────────────────────────────────────────────────────────
  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Prijavi se', style: kHeading2),
          const SizedBox(height: 4),
          const Text('Vnesite svoje podatke za prijavo.', style: kBody),
          const SizedBox(height: 20),

          _InputField(
            label: 'E-mail',
            icon: Icons.email_outlined,
            controller: _loginEmailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Geslo',
            icon: Icons.lock_outline_rounded,
            controller: _loginPassCtrl,
            obscure: !_loginPassVisible,
            suffix: IconButton(
              icon: Icon(
                _loginPassVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
                size: 20, color: kTextLight,
              ),
              onPressed: () => setState(() => _loginPassVisible = !_loginPassVisible),
            ),
          ),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreenMid,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: const RoundedRectangleBorder(borderRadius: kRadius12),
                elevation: 0,
              ),
              child: _isLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Prijava',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('Nimate računa? Registrirajte se',
                style: TextStyle(color: kGreenMid, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Register tab ──────────────────────────────────────────────────────────────
  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ustvari račun', style: kHeading2),
          const SizedBox(height: 4),
          const Text('Izpolnite podatke za registracijo.', style: kBody),
          const SizedBox(height: 20),

          _InputField(
            label: 'Ime in priimek',
            icon: Icons.person_outline_rounded,
            controller: _regNameCtrl,
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'E-mail',
            icon: Icons.email_outlined,
            controller: _regEmailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Geslo',
            icon: Icons.lock_outline_rounded,
            controller: _regPassCtrl,
            obscure: !_regPassVisible,
            suffix: IconButton(
              icon: Icon(
                _regPassVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
                size: 20, color: kTextLight,
              ),
              onPressed: () => setState(() => _regPassVisible = !_regPassVisible),
            ),
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Ponovite geslo',
            icon: Icons.lock_outline_rounded,
            controller: _regPass2Ctrl,
            obscure: true,
          ),

          const SizedBox(height: 20),
          const Text('Sem...', style: kHeading3),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _UserTypeCard(
              icon: Icons.search_rounded,
              title: 'Iščem hrano',
              subtitle: 'Pregledavam in rezerviram oglase',
              selected: _userType == 'uporabnik',
              onTap: () => setState(() => _userType = 'uporabnik'),
            )),
            const SizedBox(width: 12),
            Expanded(child: _UserTypeCard(
              icon: Icons.volunteer_activism_rounded,
              title: 'Dajem hrano',
              subtitle: 'Objavljam oglase z odvečno hrano',
              selected: _userType == 'davatelj',
              onTap: () => setState(() => _userType = 'davatelj'),
            )),
          ]),

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreenMid,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: const RoundedRectangleBorder(borderRadius: kRadius12),
                elevation: 0,
              ),
              child: _isLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Registracija',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Že imate račun? Prijavite se',
                style: TextStyle(color: kGreenMid, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input field ───────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const _InputField({
    required this.label,
    required this.icon,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: kTextDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kTextLight, fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: kTextLight),
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: kRadius12,
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: kRadius12,
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: kRadius12,
            borderSide: const BorderSide(color: kGreenMid, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ── User type card ────────────────────────────────────────────────────────────
class _UserTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _UserTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kGreenPale : Colors.white,
          borderRadius: kRadius12,
          border: Border.all(
            color: selected ? kGreenMid : kBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? [
            BoxShadow(color: kGreenMid.withOpacity(0.15),
              blurRadius: 12, offset: const Offset(0, 4)),
          ] : [
            BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: selected ? kGreenMid : kSurface,
                borderRadius: kRadius12,
              ),
              child: Icon(icon, color: selected ? Colors.white : kTextMid, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: selected ? kGreenMid : kTextDark),
              textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle,
              style: const TextStyle(fontSize: 10, color: kTextLight),
              textAlign: TextAlign.center, maxLines: 2),
            const SizedBox(height: 8),
            if (selected)
              Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(color: kGreenMid, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 13),
              )
            else
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorder, width: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}