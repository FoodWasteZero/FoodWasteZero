import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../common/auth_helpers.dart';
import '../common/theme.dart';
import 'auth_screen.dart';

/// Stran za potrditev rezervacije iz čakalne vrste.
///
/// URL parametri: claim=<oglasId>&rez=<rezervacijaId>&uid=<userId>&token=<offerToken>
/// Bere iz kolekcije 'rezervacije' (ne več iz 'oglasi').
class OfferClaimPage extends StatefulWidget {
  final String adId;          // oglasId
  final String rezervacijaId; // id dokumenta v 'rezervacije'
  final String expectedUid;
  final String token;

  const OfferClaimPage({
    super.key,
    required this.adId,
    required this.rezervacijaId,
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
  Map<String, dynamic>? _rezData;   // rezervacija dokument
  Map<String, dynamic>? _oglasData; // oglas dokument (za termine)
  DateTime? _selectedTerm;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Naloži rezervacijo
      final rezDoc = await FirebaseFirestore.instance
          .collection('rezervacije')
          .doc(widget.rezervacijaId)
          .get();
      if (!rezDoc.exists) {
        setState(() {
          _error = 'Rezervacija ne obstaja več.';
          _loading = false;
        });
        return;
      }
      final rezData = rezDoc.data() as Map<String, dynamic>;

      // Preveri da rezervacija pripada temu oglasu
      if ((rezData['oglasId'] as String?) != widget.adId) {
        setState(() {
          _error = 'Neveljavna povezava.';
          _loading = false;
        });
        return;
      }

      // Naloži oglas za termine
      final oglasDoc = await FirebaseFirestore.instance
          .collection('oglasi')
          .doc(widget.adId)
          .get();

      setState(() {
        _rezData = rezData;
        _oglasData = oglasDoc.exists
            ? oglasDoc.data() as Map<String, dynamic>
            : null;
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
    ).then((_) => _loadData());
  }

  List<DateTime> get _terms {
    final oglas = _oglasData;
    if (oglas == null) return const [];
    return [
      (oglas['termin1'] as Timestamp?)?.toDate(),
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

    final rezData = _rezData;
    if (rezData == null) return;

    // Preveri token
    final token = rezData['offerToken'] as String?;
    if (token != widget.token) {
      setState(() => _error = 'Povezava je neveljavna ali je potekla.');
      return;
    }

    // Preveri da je ponudba še aktivna
    final pending = rezData['offerPending'] as bool? ?? false;
    if (!pending) {
      setState(() => _error = 'Ponudba je že bila potrjena ali preusmerjena.');
      return;
    }

    // Preveri status rezervacije
    final status = rezData['status'] as String? ?? '';
    if (status == 'preklicano') {
      setState(() => _error = 'Ponudba je potekla ali bila preklicana.');
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
      final rezRef = FirebaseFirestore.instance
          .collection('rezervacije')
          .doc(widget.rezervacijaId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(rezRef);
        final fresh = snap.data() as Map<String, dynamic>?;
        if (fresh == null) throw StateError('Rezervacija ne obstaja več.');

        if ((fresh['offerToken'] as String?) != widget.token) {
          throw StateError('Povezava je neveljavna ali je potekla.');
        }
        if ((fresh['offerPending'] as bool? ?? false) == false) {
          throw StateError('Ponudba je že bila potrjena ali preusmerjena.');
        }

        tx.update(rezRef, {
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
        setState(
            () => _error = e.toString().replaceFirst('StateError: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final title = (_oglasData?['title'] as String?) ?? 'Rezervacija';
    final kolicina =
        (_rezData?['kolicinaPorcij'] as num?)?.toInt() ?? 1;
    final canConfirm = user != null && user.uid == widget.expectedUid;

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
                      'Rezervirano: $kolicina '
                      '${kolicina == 1 ? 'porcija' : kolicina < 5 ? 'porcije' : 'porcij'}',
                      style: kBody.copyWith(
                          fontWeight: FontWeight.w700, color: kTextDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'V 3 urah izberite termin in potrdite rezervacijo prek te strani.',
                      style: kBody.copyWith(color: kTextMid),
                    ),
                    const SizedBox(height: 16),
                    if (_terms.isEmpty)
                      const Text(
                          'Za ta oglas ni nastavljenih terminov prevzema.')
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
                              onSelected: (_) =>
                                  setState(() => _selectedTerm = term),
                            ),
                        ],
                      ),
                    const Spacer(),
                    if (_error != null) ...[
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
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
                          onPressed:
                              canConfirm && !_saving ? _confirm : null,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Text('Potrdi rezervacijo'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Če ne potrdite v 3 urah, bo rezervacija prešla naslednjemu v čakalni vrsti.',
                      style:
                          TextStyle(fontSize: 12, color: kTextLight),
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