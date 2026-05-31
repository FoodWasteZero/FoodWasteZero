import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/models.dart';
import 'email_service.dart';
import 'reservation_service.dart';

/// Prenovljeni OfferPromotionService.
///
/// Posluša kolekcijo 'rezervacije' (ne več 'oglasi') za dokumente z
/// offerPending == true. Ko offerExpiresAt poteče, označi rezervacijo kot
/// preklicano in promovira naslednjega iz waitliste oglasa ali sprosti porcije.
class OfferPromotionService {
  OfferPromotionService._();
  static final OfferPromotionService instance = OfferPromotionService._();

  StreamSubscription<QuerySnapshot>? _sub;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    _sub = FirebaseFirestore.instance
        .collection('rezervacije')
        .where('offerPending', isEqualTo: true)
        .snapshots()
        .listen(_handleSnapshot, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _running = false;
  }

  Future<void> _handleSnapshot(QuerySnapshot snap) async {
    final now = DateTime.now();
    for (final doc in snap.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final expiresTs = data['offerExpiresAt'] as Timestamp?;
        if (expiresTs == null) continue;
        if (expiresTs.toDate().isAfter(now)) continue;

        final oglasId = data['oglasId'] as String? ?? '';
        final kolicinaPorcij = (data['kolicinaPorcij'] as num?)?.toInt() ?? 1;

        // Označi to rezervacijo kot preklicano
        await doc.reference.update({
          'status': 'preklicano',
          'offerPending': false,
          'offerExpiresAt': FieldValue.delete(),
          'offerToken': FieldValue.delete(),
        });

        // Preveri čakalno vrsto in stanje oglasa
        final oglasSnap = await FirebaseFirestore.instance
            .collection('oglasi')
            .doc(oglasId)
            .get();
        if (!oglasSnap.exists) continue;
        final oglasData = oglasSnap.data()!;

        final waitRaw = oglasData['waitlist'] as List<dynamic>? ?? [];
        final waitlist = waitRaw.map((e) => e.toString()).toList();

        if (waitlist.isNotEmpty) {
          await promoteNextUser(
            docId: oglasId,
            nextUid: waitlist.first,
            remainingWaitlist: waitlist.skip(1).toList(),
            kolicinaPorcij: kolicinaPorcij,
            title: oglasData['title'] as String? ?? '',
            termin1: oglasData['termin1'] as Timestamp?,
            termin2: oglasData['termin2'] as Timestamp?,
            termin3: oglasData['termin3'] as Timestamp?,
            termin4: oglasData['termin4'] as Timestamp?,
          );
        } else {
          // Ni čakalne vrste — vrni porcije oglasu
          final totalPortions = (oglasData['portions'] as num?)?.toInt() ?? 1;
          final currentRemaining =
              (oglasData['remainingPortions'] as num?)?.toInt() ?? 0;
          final restored =
              (currentRemaining + kolicinaPorcij).clamp(0, totalPortions);
          await FirebaseFirestore.instance
              .collection('oglasi')
              .doc(oglasId)
              .update({
            'remainingPortions': restored,
            'status': 'naRazpolago',
            'waitlist': [],
          });
        }
      } catch (e) {
        debugPrint('OfferPromotion: error processing doc ${doc.id}: $e');
      }
    }
  }

  /// Ustvari novo rezervacijo za naslednjega v čakalni vrsti z offerPending = true
  /// in posodobi waitlist na oglasu.
  Future<void> promoteNextUser({
    required String docId,
    required String nextUid,
    required List<String> remainingWaitlist,
    required int kolicinaPorcij,
    required String title,
    required Timestamp? termin1,
    required Timestamp? termin2,
    required Timestamp? termin3,
    required Timestamp? termin4,
  }) async {
    final offerToken = _createToken();
    final oglasRef =
        FirebaseFirestore.instance.collection('oglasi').doc(docId);
    final rezervacijeRef =
        FirebaseFirestore.instance.collection('rezervacije');

    late String novRezId;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final oglasSnap = await tx.get(oglasRef);
      if (!oglasSnap.exists) return;

      // Posodobi waitlist na oglasu
      tx.update(oglasRef, {'waitlist': remainingWaitlist});

      // Ustvari novo rezervacijo za naslednjega
      final novRezRef = rezervacijeRef.doc();
      novRezId = novRezRef.id;
      tx.set(novRezRef, {
        'oglasId': docId,
        'userId': nextUid,
        'kolicinaPorcij': kolicinaPorcij,
        'status': 'rezervirano',
        'createdAt': FieldValue.serverTimestamp(),
        'offerPending': true,
        'offerExpiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 3)),
        ),
        'offerToken': offerToken,
      });
    });

    debugPrint(
        'OfferPromotion: promoteNextUser doc=$docId nextUid=$nextUid rezId=$novRezId');

    // Pošlji email asinhrono
    _sendOfferEmail(
      docId: docId,
      rezId: novRezId,
      uid: nextUid,
      title: title,
      offerToken: offerToken,
      termin1: termin1,
      termin2: termin2,
      termin3: termin3,
      termin4: termin4,
    ).catchError(
        (e) => debugPrint('OfferPromotion: async email send failed: $e'));
  }

  Future<void> _sendOfferEmail({
    required String docId,
    required String rezId,
    required String uid,
    required String title,
    required String offerToken,
    required Timestamp? termin1,
    required Timestamp? termin2,
    required Timestamp? termin3,
    required Timestamp? termin4,
  }) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final email = userDoc.data()?['email'] as String?;
      if (email == null || email.isEmpty) return;

      final baseUrl = ReservationService.instance.baseUrl();
      // Claim URL vsebuje rezervacijaId za direkten dostop
      final claimUrl =
          '$baseUrl/?claim=$docId&rez=$rezId&uid=$uid&token=$offerToken';

      final terms = [termin1, termin2, termin3, termin4]
          .whereType<Timestamp>()
          .map((t) => t.toDate())
          .toList();
      final termLabel =
          terms.isNotEmpty ? _formatDateTime(terms.first) : null;

      await EmailService.sendClaimEmail(
        to: email,
        title: title,
        claimUrl: claimUrl,
        selectedTermLabel: termLabel,
      );

      debugPrint(
          'OfferPromotion: offer email sent to $email for doc=$docId rez=$rezId');
    } catch (e) {
      debugPrint('OfferPromotion: Failed to send offer email: $e');
    }
  }

  String _createToken() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(24, (_) => rnd.nextInt(256));
    return bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year} $h:$min';
  }
}