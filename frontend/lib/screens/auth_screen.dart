import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/theme.dart';
import '../common/auth_helpers.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool isModal;
  const AuthScreen({super.key, this.isModal = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  AppColors get c => AppColors.of(context);

  late final AnimationController _animCtrl;
  late final Animation<double> _blurAnim;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  late TabController _tabController;
  bool _isLoading = false;

  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl  = TextEditingController();
  bool _loginPassVisible = false;

  // Login inline error
  String? _loginError;

  // Register inline error
  String? _regError;

  final _regNameCtrl    = TextEditingController();
  final _regSurnameCtrl = TextEditingController();
  final _regEmailCtrl   = TextEditingController();
  final _regPassCtrl    = TextEditingController();
  final _regPass2Ctrl   = TextEditingController();
  bool _regPassVisible = false;
  String _userType = 'uporabnik';

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Clear errors when switching tabs
      if (_loginError != null || _regError != null) {
        setState(() { _loginError = null; _regError = null; });
      }
    });

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _blurAnim = Tween<double>(begin: 0, end: 16).animate(
      CurvedAnimation(parent: _animCtrl,
          curve: const Interval(0.0, 0.65, curve: Curves.easeOut)));

    _slideAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animCtrl,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl,
          curve: const Interval(0.2, 0.75, curve: Curves.easeOut)));

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
    _regSurnameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _regPass2Ctrl.dispose();
    super.dispose();
  }

  // ── Snackbar error (register) ─────────────────────────────────────────────
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

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    final email = _loginEmailCtrl.text.trim();
    final pass  = _loginPassCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _loginError = 'Vnesite e-mail in geslo.');
      return;
    }
    setState(() { _isLoading = true; _loginError = null; });
    try {
      await signOutAnonymousIfNeeded();
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, password: pass);
      if (mounted && widget.isModal) {
        Navigator.of(context).pop();
      } else if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _loginError = _authError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────
  Future<void> _register() async {
    final firstName = _regNameCtrl.text.trim();
    final surname   = _regSurnameCtrl.text.trim();
    final email     = _regEmailCtrl.text.trim();
    final pass      = _regPassCtrl.text.trim();
    final pass2     = _regPass2Ctrl.text.trim();

    // Validation za uporabnike: prvo ime + priimek
    // Validation za organizacije: samo ime
    if (_userType == 'uporabnik') {
      if (firstName.isEmpty || surname.isEmpty || email.isEmpty || pass.isEmpty) {
        setState(() => _regError = 'Izpolnite vsa polja.');
        return;
      }
    } else {
      if (firstName.isEmpty || email.isEmpty || pass.isEmpty) {
        setState(() => _regError = 'Izpolnite vsa polja.');
        return;
      }
    }
    
    if (pass != pass2) {
      setState(() => _regError = 'Gesli se ne ujemata.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _regError = 'Geslo mora imeti vsaj 6 znakov.');
      return;
    }

    setState(() { _isLoading = true; _regError = null; });
    try {
      await signOutAnonymousIfNeeded();
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, password: pass);

      // Za uporabnike: shrani firstName in surname
      // Za organizacije: shrani organizationName
      final userData = {
        'uid':       cred.user!.uid,
        'email':     email,
        'userType':  _userType,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      if (_userType == 'uporabnik') {
        userData['firstName'] = firstName;
        userData['surname'] = surname;
        userData['ime'] = '$firstName $surname'; // Backwards compatibility
      } else {
        userData['organizationName'] = firstName;
        userData['ime'] = firstName;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set(userData);

      final displayName = _userType == 'uporabnik' 
          ? '$firstName $surname' 
          : firstName;
      await cred.user!.updateDisplayName(displayName);
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registracija uspešna! Prijavite se. ✓'),
          backgroundColor: kGreenMid,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: kRadius12),
          duration: const Duration(seconds: 3),
        ),
      );
      _regNameCtrl.clear();
      _regSurnameCtrl.clear();
      _regEmailCtrl.clear();
      _regPassCtrl.clear();
      _regPass2Ctrl.clear();
      // Reset userType back to default
      setState(() => _userType = 'uporabnik');
      _tabController.animateTo(0);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _regError = _authError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':       return 'Uporabnik ne obstaja.';
      case 'wrong-password':       return 'Napačno geslo.';
      case 'invalid-email':        return 'Neveljaven e-mail.';
      case 'email-already-in-use': return 'E-mail je že v uporabi.';
      case 'weak-password':        return 'Geslo je prešibko.';
      case 'invalid-credential':   return 'Napačen e-mail ali geslo.';
      default:                     return 'Napaka: $code';
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (widget.isModal) return _buildCard(context);

    final screenH = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        const IgnorePointer(child: Material(child: HomeScreen())),

        AnimatedBuilder(
          animation: _blurAnim,
          builder: (_, __) {
            if (_blurAnim.value < 0.01) return const SizedBox.shrink();
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _blurAnim.value, sigmaY: _blurAnim.value),
              child: Container(
                color: Colors.black.withOpacity(0.22 * (_blurAnim.value / 16)),
              ),
            );
          },
        ),

        AnimatedBuilder(
          animation: _animCtrl,
          builder: (context, _) {
            return Positioned(
              left: 0, right: 0, bottom: 0,
              child: Transform.translate(
                offset: Offset(0, screenH * 0.6 * _slideAnim.value),
                child: Opacity(
                  opacity: _fadeAnim.value,
                  child: Material(color: Colors.transparent, child: _buildCard(context)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Color(0x40000000), blurRadius: 48, offset: Offset(0, -8)),
          BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 14),
          Center(
            child: Container(
              width: 44, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          SizedBox(height: 16),

          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withOpacity(0.4),
                      blurRadius: 14, offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(Icons.eco_rounded, color: c.card, size: 22),
              ),
              SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('FoodWasteZero',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                        color: Color(0xFF1A2E1A), letterSpacing: -0.3)),
                Text('Reši hrano. Pomagaj skupnosti.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF78909C))),
              ]),
            ]),
          ),
          SizedBox(height: 16),

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
                  BoxShadow(color: kGreenMid.withOpacity(0.4),
                      blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [Tab(text: 'Prijava'), Tab(text: 'Registracija')],
            ),
          ),
          SizedBox(height: 4),

          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [_buildLoginTab(), _buildRegisterTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Login tab ──────────────────────────────────────────────────────────────
  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 16, 24,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prijavi se', style: kHeading2),
          SizedBox(height: 4),
          Text('Vnesite svoje podatke za prijavo.', style: kBody),
          SizedBox(height: 20),

          _InputField(
            label: 'E-mail',
            icon: Icons.email_outlined,
            controller: _loginEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            hasError: _loginError != null,
            onChanged: (_) { if (_loginError != null) setState(() => _loginError = null); },
          ),
          SizedBox(height: 12),
          _InputField(
            label: 'Geslo',
            icon: Icons.lock_outline_rounded,
            controller: _loginPassCtrl,
            obscure: !_loginPassVisible,
            hasError: _loginError != null,
            onChanged: (_) { if (_loginError != null) setState(() => _loginError = null); },
            suffix: IconButton(
              icon: Icon(
                _loginPassVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20, color: c.textLight,
              ),
              onPressed: () => setState(() => _loginPassVisible = !_loginPassVisible),
            ),
          ),

          // Inline error message
          if (_loginError != null) ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: kRadius8,
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade600, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _loginError!,
                    style: TextStyle(color: Colors.red.shade700,
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
          ],

          SizedBox(height: 22),

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
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: c.card, strokeWidth: 2))
                  : Text('Prijava',
                      style: TextStyle(color: c.card,
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: Text('Nimate računa? Registrirajte se',
                  style: TextStyle(color: kGreenMid, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Register tab ───────────────────────────────────────────────────────────
  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 16, 24,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ustvari račun', style: kHeading2),
          SizedBox(height: 4),
          Text('Izpolnite podatke za registracijo.', style: kBody),
          SizedBox(height: 20),

          _InputField(
            label: _userType == 'uporabnik' ? 'Ime' : 'Ime organizacije',
            icon: Icons.person_outline_rounded,
            controller: _regNameCtrl,
          ),
          SizedBox(height: 12),
          if (_userType == 'uporabnik') ...[
            _InputField(
              label: 'Priimek',
              icon: Icons.person_outline_rounded,
              controller: _regSurnameCtrl,
            ),
            SizedBox(height: 12),
          ],
          _InputField(
            label: 'E-mail',
            icon: Icons.email_outlined,
            controller: _regEmailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 12),
          _InputField(
            label: 'Geslo',
            icon: Icons.lock_outline_rounded,
            controller: _regPassCtrl,
            obscure: !_regPassVisible,
            hasError: _regError != null,
            onChanged: (_) { if (_regError != null) setState(() => _regError = null); },
            suffix: IconButton(
              icon: Icon(
                _regPassVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20, color: c.textLight,
              ),
              onPressed: () => setState(() => _regPassVisible = !_regPassVisible),
            ),
          ),
          SizedBox(height: 12),
          _InputField(
            label: 'Ponovite geslo',
            icon: Icons.lock_outline_rounded,
            controller: _regPass2Ctrl,
            obscure: true,
            hasError: _regError != null,
            onChanged: (_) { if (_regError != null) setState(() => _regError = null); },
          ),

          // Inline error message
          if (_regError != null) ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: kRadius8,
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade600, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _regError!,
                    style: TextStyle(color: Colors.red.shade700,
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
          ],
          Text('Sem...', style: kHeading3),
          SizedBox(height: 10),
          Row(children: [
            Expanded(child: _UserTypeCard(
              icon: Icons.person_rounded,
              title: 'Uporabnik',
              subtitle: 'Pregledavam in rezerviram oglase',
              selected: _userType == 'uporabnik',
              isOrg: false,
              onTap: () => setState(() => _userType = 'uporabnik'),
            )),
            SizedBox(width: 12),
            Expanded(child: _UserTypeCard(
              icon: Icons.store_rounded,
              title: 'Organizacija',
              subtitle: 'Objavljam odvečno hrano',
              selected: _userType == 'davatelj',
              isOrg: true,
              onTap: () => setState(() => _userType = 'davatelj'),
            )),
          ]),

          SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: _userType == 'davatelj' ? kGreenDark : kGreenMid,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: const RoundedRectangleBorder(borderRadius: kRadius12),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: c.card, strokeWidth: 2))
                  : Text('Registracija',
                      style: TextStyle(color: c.card,
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _tabController.animateTo(0),
              child: Text('Že imate račun? Prijavite se',
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
  final bool hasError;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.label,
    required this.icon,
    required this.controller,
    this.obscure = false,
    this.hasError = false,
    this.keyboardType,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
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
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: c.textDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: c.textLight, fontSize: 14),
          prefixIcon: Icon(icon, size: 20,
              color: hasError ? Colors.red.shade400 : kTextLight),
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: kRadius12,
            borderSide: BorderSide(color: hasError ? Colors.red.shade300 : kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: kRadius12,
            borderSide: BorderSide(
                color: hasError ? Colors.red.shade300 : kBorder,
                width: hasError ? 1.5 : 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: kRadius12,
            borderSide: BorderSide(
                color: hasError ? Colors.red.shade400 : kGreenMid, width: 1.5),
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
  final bool isOrg;
  final VoidCallback onTap;

  const _UserTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.isOrg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Uporabnik: selected = light green pale bg, green text
    // Organizacija: selected = dark green bg, white text
    final Color bg;
    final Color borderColor;
    final Color titleColor;
    final Color iconBg;
    final Color iconColor;

    if (isOrg) {
      bg          = selected ? kGreenDark : Colors.white;
      borderColor = selected ? kGreenDark : kBorder;
      titleColor  = selected ? Colors.white : kTextDark;
      iconBg      = selected ? Colors.white.withOpacity(0.18) : kSurface;
      iconColor   = selected ? Colors.white : kTextMid;
    } else {
      bg          = selected ? kGreenPale : Colors.white;
      borderColor = selected ? kGreenMid : kBorder;
      titleColor  = selected ? kGreenMid : kTextDark;
      iconBg      = selected ? kGreenMid : kSurface;
      iconColor   = selected ? Colors.white : kTextMid;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: kRadius12,
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          boxShadow: selected
              ? [BoxShadow(
                  color: (isOrg ? kGreenDark : kGreenMid).withOpacity(0.22),
                  blurRadius: 14, offset: const Offset(0, 5))]
              : [BoxShadow(color: Colors.black.withOpacity(0.05),
                  blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: iconBg, borderRadius: kRadius12),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            SizedBox(height: 10),
            Text(title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleColor),
                textAlign: TextAlign.center),
            SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(fontSize: 11,
                    color: selected && isOrg ? Colors.white70 : kTextLight),
                textAlign: TextAlign.center, maxLines: 2),
            SizedBox(height: 8),
            if (selected)
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: isOrg ? Colors.white : kGreenMid,
                  shape: BoxShape.circle),
                child: Icon(Icons.check,
                    color: isOrg ? kGreenDark : Colors.white, size: 13),
              )
            else
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border, width: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}