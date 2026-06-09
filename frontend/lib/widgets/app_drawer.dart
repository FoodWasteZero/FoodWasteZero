import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../screens/profile_page.dart';
import '../screens/onboarding_screen.dart';
import '../screens/settings_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close() {
    _ctrl.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _navigate(Widget page) {
    _ctrl.reverse().then((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 320),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Stack(
          children: [
            GestureDetector(
              onTap: _close,
              child: Container(
                color: Colors.black.withOpacity(0.45 * _fadeAnim.value),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Transform.translate(
                offset: Offset(
                  MediaQuery.of(context).size.width * 0.78 * _slideAnim.value,
                  0,
                ),
                child: child,
              ),
            ),
          ],
        );
      },
      child: _DrawerPanel(onClose: _close, onNavigate: _navigate),
    );
  }
}

class _DrawerPanel extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(Widget) onNavigate;

  const _DrawerPanel({required this.onClose, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: MediaQuery.of(context).size.width * 0.78,
      height: double.infinity,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 40,
            offset: Offset(-8, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: kGreenPale,
                      borderRadius: kRadius8,
                    ),
                    child: const Icon(Icons.eco_rounded, color: kGreenMid, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'FoodWasteZero',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: c.textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(Icons.close_rounded, color: c.textMid, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Divider(color: c.border.withOpacity(0.6), height: 1),
            ),
            const SizedBox(height: 16),
            _MenuItem(
              icon: Icons.person_rounded,
              label: 'Profil',
              subtitle: 'Vaš račun in aktivnost',
              color: kGreenMid,
              onTap: () => onNavigate(const ProfilePage()),
            ),
            _MenuItem(
              icon: Icons.auto_stories_rounded,
              label: 'Onboarding',
              subtitle: 'Spoznajte aplikacijo',
              color: const Color(0xFF1565C0),
              onTap: () => onNavigate(const OnboardingScreen()),
            ),
            _MenuItem(
              icon: Icons.tune_rounded,
              label: 'Nastavitve',
              subtitle: 'Tema, jezik in drugo',
              color: const Color(0xFF6A1B9A),
              onTap: () => onNavigate(const SettingsScreen()),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Text(
                'FoodWasteZero v1.0',
                style: TextStyle(
                  fontSize: 12,
                  color: c.textLight.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: kRadius12,
        child: InkWell(
          borderRadius: kRadius12,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: kRadius12,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.textDark,
                        )),
                      const SizedBox(height: 2),
                      Text(subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textMid,
                        )),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textLight, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showAppDrawer(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => const AppDrawer(),
      transitionDuration: Duration.zero,
    ),
  );
}
