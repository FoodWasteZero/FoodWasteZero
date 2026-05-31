import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/theme.dart';
import '../models/models.dart';

/// Bottom sheet za organizacijo — prikaže podrobnosti paketa:
/// cena, rezervator, izbrani termin, porcije.
class OrgStatSheet extends StatefulWidget {
  final FoodOglas oglas;

  const OrgStatSheet({super.key, required this.oglas});

  static Future<void> show(BuildContext context, FoodOglas oglas) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrgStatSheet(oglas: oglas),
    );
  }

  @override
  State<OrgStatSheet> createState() => _OrgPackageDetailSheetState();
}

class _OrgPackageDetailSheetState extends State<OrgStatSheet> {
  List<Map<String, dynamic>> _rezervacije = [];
  bool _loadingRez = true;

  FoodOglas get oglas => widget.oglas;

  @override
  void initState() {
    super.initState();
    _fetchRezervacije();
  }

  Future<void> _fetchRezervacije() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rezervacije')
          .where('oglasId', isEqualTo: oglas.id)
          .where('status', whereIn: ['rezervirano', 'na_voljo'])
          .get();
      if (mounted) {
        setState(() {
          _rezervacije = snap.docs
              .map((d) => d.data() as Map<String, dynamic>)
              .toList();
          _loadingRez = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRez = false);
    }
  }

  String _formatTermin(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day. $month. ${dt.year} ob $hour:$min';
  }

  String _porcijLabel(int n) {
    if (n == 1) return 'porcija';
    if (n < 5) return 'porcije';
    return 'porcij';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final total = oglas.portions ?? 1;
    final remaining = oglas.remainingPortions ?? total;
    // Count reserved portions from loaded rezervacije
    final reserved = _rezervacije.fold<int>(
        0, (sum, r) => sum + ((r['kolicinaPorcij'] as num?)?.toInt() ?? 1));
    final hasPrice = (oglas.price ?? 0) > 0;
    final totalPrice = hasPrice ? oglas.price! * reserved : 0.0;

    // Pick the first chosenTermin from any active reservation
    final chosenTermin = _rezervacije
        .map((r) => (r['chosenTermin'] as Timestamp?)?.toDate())
        .whereType<DateTime>()
        .cast<DateTime?>()
        .firstOrNull;

    // Termini
    final termini = <DateTime?>[
      oglas.termin1, oglas.termin2, oglas.termin3, oglas.termin4,
    ].where((t) => t != null).cast<DateTime>().toList();

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: kBorder,
              borderRadius: kRadiusFull,
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable vsebina
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Glava: ikona + naslov + status ──────────────────────
                  Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: oglas.imageColor,
                        borderRadius: kRadius12,
                      ),
                      child: Icon(oglas.icon, color: kGreenMid, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            oglas.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: kTextDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _StatusBadge(oglas.status),
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  const Divider(height: 1, color: kBorder),
                  const SizedBox(height: 20),

                  // ── Cena ────────────────────────────────────────────────
                  _SectionTitle(
                    icon: Icons.euro_rounded,
                    label: 'Cena',
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: hasPrice
                          ? const Color(0xFFE8EAF6)
                          : kGreenPale,
                      borderRadius: kRadius12,
                      border: Border.all(
                        color: hasPrice
                            ? const Color(0xFF5C6BC0).withOpacity(0.25)
                            : kGreenMid.withOpacity(0.2),
                      ),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasPrice
                                  ? '${oglas.price!.toStringAsFixed(2)} € / porcija'
                                  : 'Brezplačno',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: hasPrice
                                    ? const Color(0xFF3949AB)
                                    : kGreenMid,
                              ),
                            ),
                            if (hasPrice && reserved > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Skupaj za $reserved ${_porcijLabel(reserved)}: '
                                '${totalPrice.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: kTextMid,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        hasPrice
                            ? Icons.payments_rounded
                            : Icons.volunteer_activism_rounded,
                        color: hasPrice
                            ? const Color(0xFF5C6BC0)
                            : kGreenMid,
                        size: 28,
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1, color: kBorder),
                  const SizedBox(height: 20),

                  // ── Porcije ─────────────────────────────────────────────
                  _SectionTitle(
                    icon: Icons.restaurant_rounded,
                    label: 'Porcije',
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _PorcijCard(
                        value: '$total',
                        label: 'Skupaj',
                        color: kTextMid,
                        bgColor: kSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PorcijCard(
                        value: '$reserved',
                        label: 'Rezervirano',
                        color: kOrange,
                        bgColor: const Color(0xFFFFF3E0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PorcijCard(
                        value: '$remaining',
                        label: 'Na voljo',
                        color: kGreenMid,
                        bgColor: kGreenPale,
                      ),
                    ),
                  ]),

                  // ── Rezervacije ─────────────────────────────────────────
                  if (_rezervacije.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: kBorder),
                    const SizedBox(height: 20),
                    _SectionTitle(
                      icon: Icons.people_rounded,
                      label: 'Aktivne rezervacije',
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: kRadius12,
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: const BoxDecoration(
                            color: kGreenPale,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${_rezervacije.length}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: kGreenMid,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _loadingRez
                              ? const Text('Nalagam...',
                                  style: TextStyle(color: kTextLight))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_rezervacije.length} ${_rezervacije.length == 1 ? 'rezervacija' : 'rezervacij'} aktivnih',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: kTextDark,
                                      ),
                                    ),
                                    if (reserved > 0)
                                      Text(
                                        '$reserved ${_porcijLabel(reserved)} rezerviranih',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: kTextMid,
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ]),
                    ),
                  ],

                  // ── Izbrani termin ───────────────────────────────────────
                  if (chosenTermin != null) ...[
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: kBorder),
                    const SizedBox(height: 20),
                    _SectionTitle(
                      icon: Icons.event_available_rounded,
                      label: 'Izbrani termin prevzema',
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: kRadius12,
                        border: Border.all(color: kGreenMid.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            color: kGreenMid, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          _formatTermin(chosenTermin!),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kGreenMid,
                          ),
                        ),
                      ]),
                    ),
                  ],

                  // ── Vsi termini ──────────────────────────────────────────
                  if (termini.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: kBorder),
                    const SizedBox(height: 20),
                    _SectionTitle(
                      icon: Icons.schedule_rounded,
                      label: 'Vsi termini prevzema',
                    ),
                    const SizedBox(height: 10),
                    ...termini.map((t) {
                      final isChosen = chosenTermin != null &&
                          t.isAtSameMomentAs(chosenTermin);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isChosen ? kGreenPale : kSurface,
                          borderRadius: kRadius12,
                          border: Border.all(
                            color: isChosen
                                ? kGreenMid.withOpacity(0.35)
                                : kBorder,
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            isChosen
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: isChosen ? kGreenMid : kTextLight,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatTermin(t),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isChosen
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isChosen ? kGreenMid : kTextMid,
                            ),
                          ),
                        ]),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),

          // ── Zapri gumb ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextMid,
                  side: const BorderSide(color: kBorder),
                  shape: const RoundedRectangleBorder(borderRadius: kRadius12),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Zapri',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pomožni widgeti ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: kGreenMid),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: kTextDark,
    )),
  ]);
}

class _PorcijCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color bgColor;
  const _PorcijCard({
    required this.value,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: kRadius12,
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: color,
      )),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(
        fontSize: 12,
        color: kTextLight,
        fontWeight: FontWeight.w500,
      )),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final OglasStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;
    switch (status) {
      case OglasStatus.rezervirano:
        color = kOrange; label = 'Rezervirano'; icon = Icons.schedule_rounded;
        break;
      case OglasStatus.prevzeto:
        color = kTextMid; label = 'Prevzeto'; icon = Icons.check_circle_outline_rounded;
        break;
      default:
        color = kGreenMid; label = 'Na razpolago'; icon = Icons.eco_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: kRadiusFull,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        )),
      ]),
    );
  }
}