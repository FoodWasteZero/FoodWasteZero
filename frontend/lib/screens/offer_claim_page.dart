import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../common/auth_helpers.dart';
import '../common/theme.dart';
import 'auth_screen.dart';

class OfferClaimPage extends StatefulWidget {
  final String adId;
  final String expectedUid;
  final String token;

  const OfferClaimPage({
    super.key,
    required this.adId,
    required this.expectedUid,
    required this.token,
  });

  @override
  State<OfferClaimPage> createState() => _OfferClaimPageState();
}

class _OfferClaimPageState extends State<OfferClaimPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _data;
  DateTime? _selectedTerm;

  @override
  void initState() {
    super.initState();
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('oglasi').doc(widget.adId).get();
      if (!doc.exists) {
        setState(() {
          _error = 'Ponudba ne obstaja več.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _data = doc.data() as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Napaka pri nalaganju: $e';
        _loading = false;
      });
    }
  }

  void _showAuth() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AuthScreen(isModal: true),
    ).then((_) => _loadOffer());
  }

  List<DateTime> get _terms {
    final data = _data;
    if (data == null) return const [];
    return [
      (data['termin1'] as Timestamp?)?.toDate(),
      (data['termin2'] as Timestamp?)?.toDate(),
      (data['termin3'] as Timestamp?)?.toDate(),
      (data['termin4'] as Timestamp?)?.toDate(),
    ].whereType<DateTime>().toList();
  }

  Future<void> _confirm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (isAppGuest(user)) {
      _showAuth();
      return;
    }
    if (user == null || user.uid != widget.expectedUid) {
      setState(() => _error = 'Ta povezava ni namenjena temu uporabniku.');
      return;
    }
    final data = _data;
    if (data == null) return;
    final token = data['offerToken'] as String?;
    if (token != widget.token) {
      setState(() => _error = 'Povezava je neveljavna ali je potekla.');
      return;
    }
    final pending = data['offerPending'] as bool? ?? false;
    if (!pending) {
      setState(() => _error = 'Ponudba je že bila potrjena ali preusmerjena.');
      return;
    }
    if (_selectedTerm == null) {
      setState(() => _error = 'Najprej izberite termin.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ref = FirebaseFirestore.instance.collection('oglasi').doc(widget.adId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final fresh = snap.data() as Map<String, dynamic>?;
        if (fresh == null) throw StateError('Ponudba ne obstaja več.');
        if ((fresh['offerToken'] as String?) != widget.token) {
          throw StateError('Povezava je neveljavna ali je potekla.');
        }
        if ((fresh['offerPending'] as bool? ?? false) == false) {
          throw StateError('Ponudba je že bila potrjena ali preusmerjena.');
        }
        tx.update(ref, {
          'offerPending': false,
          'offerConfirmedAt': FieldValue.serverTimestamp(),
          'chosenTermin': Timestamp.fromDate(_selectedTerm!),
          'offerExpiresAt': FieldValue.delete(),
          'offerToken': FieldValue.delete(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rezervacija potrjena ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('StateError: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final title = (_data?['title'] as String?) ?? 'Rezervacija';
    final reservedByUid = _data?['reservedByUid'] as String?;
    final canConfirm = user != null && user.uid == widget.expectedUid && reservedByUid == widget.expectedUid;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('Potrditev rezervacije')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreenMid))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: kHeading2),
                    const SizedBox(height: 8),
                    Text(
                      'V 3 urah izberite termin in potrdite rezervacijo prek te strani.',
                      style: kBody.copyWith(color: kTextMid),
                    ),
                    const SizedBox(height: 16),
                    if (_terms.isEmpty)
                      const Text('Za ta oglas ni nastavljenih terminov prevzema.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final term in _terms)
                            ChoiceChip(
                              label: Text(_formatTerm(term)),
                              selected: _selectedTerm == term,
                              selectedColor: kGreenPale,
                              onSelected: (_) => setState(() => _selectedTerm = term),
                            ),
                        ],
                      ),
                    const Spacer(),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                    ],
                    if (user == null || user.isAnonymous)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _showAuth,
                          child: const Text('Prijavi se za potrditev'),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canConfirm && !_saving ? _confirm : null,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Potrdi rezervacijo'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Če ne potrdite v 3 urah, bo rezervacija prešla naslednjemu v čakalni vrsti.',
                      style: TextStyle(fontSize: 12, color: kTextLight),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatTerm(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.${dt.year} $hour:$minute';
  }
}
