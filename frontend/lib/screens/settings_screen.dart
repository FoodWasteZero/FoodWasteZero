import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../common/app_strings.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _locationEnabled = true;
  String _radius = '5';

  // Jezik — inicijalizira se iz LocaleService
  String get _language => LocaleService.instance.code;

  @override
  void initState() {
    super.initState();
    // Slušaj promjene jezika da se UI ažurira
    LocaleService.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocaleService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageSheet(
        selected: _language,
        onSelect: (lang) async {
          await LocaleService.instance.setLocale(lang);
          if (mounted) {
            setState(() {});
            Navigator.pop(context);
          }
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

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.settingsTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextDark)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(label: s.sectionAppearance),
          _SettingsCard(children: [
            _ToggleTile(
              icon: Icons.dark_mode_rounded,
              iconColor: const Color(0xFF37474F),
              title: s.darkMode,
              subtitle: ThemeService.instance.isDark ? s.darkModeOn : s.darkModeOff,
              value: ThemeService.instance.isDark,
              onChanged: (v) => ThemeService.instance.setDark(v),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(label: s.sectionLanguage),
          _SettingsCard(children: [
            _TapTile(
              icon: Icons.language_rounded,
              iconColor: const Color(0xFF1565C0),
              title: s.appLanguage,
              value: s.labelForCode(_language),
              onTap: _showLanguagePicker,
            ),
            const _Divider(),
            _TapTile(
              icon: Icons.radar_rounded,
              iconColor: const Color(0xFF6A1B9A),
              title: s.searchRadius,
              value: '$_radius km',
              onTap: _showRadiusPicker,
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(label: s.sectionNotifications),
          _SettingsCard(children: [
            _ToggleTile(
              icon: Icons.notifications_rounded,
              iconColor: const Color(0xFFE65100),
              title: s.pushNotifications,
              subtitle: s.pushNotifSubtitle,
              value: _notifications,
              onChanged: (v) => setState(() => _notifications = v),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(label: s.sectionLocation),
          _SettingsCard(children: [
            _ToggleTile(
              icon: Icons.location_on_rounded,
              iconColor: kGreenMid,
              title: s.allowLocation,
              subtitle: s.allowLocationSubtitle,
              value: _locationEnabled,
              onChanged: (v) => setState(() => _locationEnabled = v),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(label: s.sectionAbout),
          _SettingsCard(children: [
            _InfoTile(
              icon: Icons.info_outline_rounded,
              iconColor: kTextMid,
              title: s.version,
              value: '1.0.0',
            ),
            const _Divider(),
            _InfoTile(
              icon: Icons.school_rounded,
              iconColor: kTextMid,
              title: s.project,
              value: 'Praktikum II — FERI',
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label,
        style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: kTextLight, letterSpacing: 0.8,
        )),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: kRadius16, boxShadow: kCardShadow),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 64),
      child: Divider(height: 1, color: kBorder.withOpacity(0.5)),
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
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: kTextMid)),
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark))),
            Text(value, style: const TextStyle(fontSize: 13, color: kTextMid)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: kTextLight, size: 18),
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark))),
          Text(value, style: const TextStyle(fontSize: 13, color: kTextMid)),
        ],
      ),
    );
  }
}

// ── Language picker sheet ──────────────────────────────────────────────────────

class _LanguageSheet extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _LanguageSheet({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final langs = [
      ('sl', s.langSlovenian, '🇸🇮'),
      ('bs', s.langBosnian,   '🇧🇦'),
      ('en', s.langEnglish,   '🇬🇧'),
    ];
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: kRadius24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(s.langPickerTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextDark)),
          ),
          ...langs.map((l) => ListTile(
            leading: Text(l.$3, style: const TextStyle(fontSize: 24)),
            title: Text(l.$2,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected == l.$1 ? kGreenMid : kTextDark,
              )),
            trailing: selected == l.$1
              ? const Icon(Icons.check_circle_rounded, color: kGreenMid)
              : null,
            shape: const RoundedRectangleBorder(borderRadius: kRadius12),
            onTap: () => onSelect(l.$1),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Radius picker sheet ────────────────────────────────────────────────────────

class _RadiusSheet extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _RadiusSheet({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final radii = ['1', '2', '5', '10', '20', '50'];
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: kRadius24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(AppStrings.of(context).searchRadius,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextDark)),
          ),
          ...radii.map((r) => ListTile(
            leading: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: selected == r ? kGreenPale : kSurface,
                borderRadius: kRadius12,
              ),
              child: Icon(Icons.radar_rounded,
                color: selected == r ? kGreenMid : kTextLight, size: 20),
            ),
            title: Text('$r km',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextDark)),
            trailing: selected == r
              ? const Icon(Icons.check_circle_rounded, color: kGreenMid)
              : null,
            shape: const RoundedRectangleBorder(borderRadius: kRadius12),
            onTap: () => onSelect(r),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}