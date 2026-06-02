import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _language = 'sl';
  bool _notifications = true;
  bool _locationEnabled = true;
  String _radius = '5';

  bool get _darkMode => ThemeService.instance.isDark;

  @override
  void initState() {
    super.initState();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageSheet(
        selected: _language,
        onSelect: (lang) {
          setState(() => _language = lang);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showRadiusPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RadiusSheet(
        selected: _radius,
        onSelect: (r) {
          setState(() => _radius = r);
          Navigator.pop(context);
        },
      ),
    );
  }

  String get _languageLabel => switch (_language) {
    'sl' => 'Slovenščina',
    'hr' => 'Hrvatski',
    'en' => 'English',
    _ => 'Slovenščina',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceBg = isDark ? kDarkSurface : kSurface;
    final cardBg = isDark ? kDarkCard : Colors.white;
    final appBarBg = isDark ? kDarkCard : Colors.white;
    final titleColor = isDark ? kDarkTextDark : kTextDark;
    final sectionColor = isDark ? kDarkTextMid : kTextLight;

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Nastavitve',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: titleColor)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(label: 'Videz', color: sectionColor),
          _SettingsCard(color: cardBg, children: [
            _ToggleTile(
              icon: Icons.dark_mode_rounded,
              iconColor: const Color(0xFF37474F),
              title: 'Temni način',
              subtitle: _darkMode ? 'Vklopljeno' : 'Izklopljeno',
              value: _darkMode,
              onChanged: (v) async {
                await ThemeService.instance.toggle(v);
              },
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(label: 'Jezik in regija', color: sectionColor),
          _SettingsCard(color: cardBg, children: [
            _TapTile(
              icon: Icons.language_rounded,
              iconColor: const Color(0xFF1565C0),
              title: 'Jezik aplikacije',
              value: _languageLabel,
              onTap: _showLanguagePicker,
            ),
            _Divider(isDark: isDark),
            _TapTile(
              icon: Icons.radar_rounded,
              iconColor: const Color(0xFF6A1B9A),
              title: 'Radij iskanja',
              value: '$_radius km',
              onTap: _showRadiusPicker,
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(label: 'Obvestila', color: sectionColor),
          _SettingsCard(color: cardBg, children: [
            _ToggleTile(
              icon: Icons.notifications_rounded,
              iconColor: const Color(0xFFE65100),
              title: 'Push obvestila',
              subtitle: 'Novi oglasi in rezervacije',
              value: _notifications,
              onChanged: (v) => setState(() => _notifications = v),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(label: 'Lokacija', color: sectionColor),
          _SettingsCard(color: cardBg, children: [
            _ToggleTile(
              icon: Icons.location_on_rounded,
              iconColor: kGreenMid,
              title: 'Dovoli lokacijo',
              subtitle: 'Za iskanje hrane blizu vas',
              value: _locationEnabled,
              onChanged: (v) => setState(() => _locationEnabled = v),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(label: 'O aplikaciji', color: sectionColor),
          _SettingsCard(color: cardBg, children: [
            _InfoTile(
              icon: Icons.info_outline_rounded,
              iconColor: isDark ? kDarkTextMid : kTextMid,
              title: 'Različica',
              value: '1.0.0',
            ),
            _Divider(isDark: isDark),
            _InfoTile(
              icon: Icons.school_rounded,
              iconColor: isDark ? kDarkTextMid : kTextMid,
              title: 'Projekt',
              value: 'Praktikum II — FERI',
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 0.8,
          )),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final Color color;
  const _SettingsCard({required this.children, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: color, borderRadius: kRadius16, boxShadow: kCardShadow),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 64),
      child: Divider(
        height: 1,
        color: (isDark ? kDarkBorder : kBorder).withOpacity(0.5),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? kDarkTextDark : kTextDark;
    final subtitleColor = isDark ? kDarkTextMid : kTextMid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1), borderRadius: kRadius12),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleColor)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: kGreenMid),
        ],
      ),
    );
  }
}

class _TapTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _TapTile({
    required this.icon, required this.iconColor,
    required this.title, required this.value, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? kDarkTextDark : kTextDark;
    final valueColor = isDark ? kDarkTextMid : kTextMid;
    final chevronColor = isDark ? kDarkTextLight : kTextLight;

    return InkWell(
      borderRadius: kRadius16,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1), borderRadius: kRadius12),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleColor))),
            Text(value, style: TextStyle(fontSize: 13, color: valueColor)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: chevronColor, size: 18),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon, required this.iconColor,
    required this.title, required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? kDarkTextDark : kTextDark;
    final valueColor = isDark ? kDarkTextMid : kTextMid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.08), borderRadius: kRadius12),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleColor))),
          Text(value, style: TextStyle(fontSize: 13, color: valueColor)),
        ],
      ),
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _LanguageSheet({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? kDarkCard : Colors.white;
    final titleColor = isDark ? kDarkTextDark : kTextDark;

    final langs = [('sl', 'Slovenščina', '🇸🇮'), ('hr', 'Hrvatski', '🇭🇷'), ('en', 'English', '🇬🇧')];
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: sheetBg, borderRadius: kRadius24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Jezik aplikacije',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: titleColor)),
          ),
          ...langs.map((l) => ListTile(
            leading: Text(l.$3, style: const TextStyle(fontSize: 24)),
            title: Text(l.$2, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: titleColor)),
            trailing: selected == l.$1 ? const Icon(Icons.check_circle_rounded, color: kGreenMid) : null,
            shape: const RoundedRectangleBorder(borderRadius: kRadius12),
            onTap: () => onSelect(l.$1),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RadiusSheet extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _RadiusSheet({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? kDarkCard : Colors.white;
    final titleColor = isDark ? kDarkTextDark : kTextDark;

    final radii = ['1', '2', '5', '10', '20', '50'];
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: sheetBg, borderRadius: kRadius24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Radij iskanja',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: titleColor)),
          ),
          ...radii.map((r) => ListTile(
            leading: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: selected == r ? kGreenPale : (isDark ? kDarkCardAlt : kSurface),
                borderRadius: kRadius12,
              ),
              child: Icon(Icons.radar_rounded,
                  color: selected == r ? kGreenMid : (isDark ? kDarkTextLight : kTextLight), size: 20),
            ),
            title: Text('$r km',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: titleColor)),
            trailing: selected == r ? const Icon(Icons.check_circle_rounded, color: kGreenMid) : null,
            shape: const RoundedRectangleBorder(borderRadius: kRadius12),
            onTap: () => onSelect(r),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}