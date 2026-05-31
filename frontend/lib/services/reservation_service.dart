import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/models.dart';
import '../common/oglas_mapper.dart';
import 'email_service.dart';
import 'offer_promotion_service.dart';

/// Centralizirana storitev za upravljanje z rezervacijami.
class ReservationService {
  ReservationService._();
  static final ReservationService instance = ReservationService._();

  final _db = FirebaseFirestore.instance;

  // ── Ustvari novo rezervacijo ───────────────────────────────────────────────
  Future<String> ustvariRezervacijo({
    required String oglasId,
    required String userId,
    required int kolicinaPorcij,
    required DateTime chosenTermin,
    required int totalPortions,
  }) async {
    final oglasRef = _db.collection('oglasi').doc(oglasId);
    final rezervacijeRef = _db.collection('rezervacije');
    final pickupToken = _createToken();
    late String rezervacijaId;

    await _db.runTransaction((tx) async {
      final oglasSnap = await tx.get(oglasRef);
      if (!oglasSnap.exists) throw Exception('Oglas ne obstaja več.');

      final data = oglasSnap.data()!;
      final currentRemaining = (data['remainingPortions'] as num?)?.toInt()
          ?? (data['portions'] as num?)?.toInt()
          ?? 0;

      if (kolicinaPorcij > currentRemaining) {
        throw Exception(
          'Na voljo je samo $currentRemaining '
          '${currentRemaining == 1 ? 'porcija' : 'porcije'}.',
        );
      }

      final newRemaining = currentRemaining - kolicinaPorcij;

      tx.update(oglasRef, {
        'remainingPortions': newRemaining,
        'status': newRemaining == 0 ? 'rezervirano' : 'naRazpolago',
      });

      final newDocRef = rezervacijeRef.doc();
      rezervacijaId = newDocRef.id;
      tx.set(newDocRef, {
        'oglasId': oglasId,
        'userId': userId,
        'kolicinaPorcij': kolicinaPorcij,
        'status': 'rezervirano',
        'createdAt': FieldValue.serverTimestamp(),
        'chosenTermin': Timestamp.fromDate(chosenTermin),
        'offerPending': false,
        'pickupToken': pickupToken,
      });
    });

    return rezervacijaId;
  }

  // ── Prekliči rezervacijo ──────────────────────────────────────────────────
  Future<void> prekliciRezervacijo({
    required String rezervacijaId,
    required String oglasId,
    required int kolicinaPorcij,
    required FoodOglas oglas,
  }) async {
    final oglasRef = _db.collection('oglasi').doc(oglasId);
    final rezervacijaRef = _db.collection('rezervacije').doc(rezervacijaId);

    if (oglas.waitlist.isNotEmpty) {
      await rezervacijaRef.update({'status': 'preklicano'});
      await OfferPromotionService.instance.promoteNextUser(
        docId: oglasId,
        nextUid: oglas.waitlist.first,
        remainingWaitlist: oglas.waitlist.skip(1).toList(),
        kolicinaPorcij: kolicinaPorcij,
        title: oglas.title,
        termin1: oglas.termin1 != null ? Timestamp.fromDate(oglas.termin1!) : null,
        termin2: oglas.termin2 != null ? Timestamp.fromDate(oglas.termin2!) : null,
        termin3: oglas.termin3 != null ? Timestamp.fromDate(oglas.termin3!) : null,
        termin4: oglas.termin4 != null ? Timestamp.fromDate(oglas.termin4!) : null,
      );
    } else {
      await _db.runTransaction((tx) async {
        final oglasSnap = await tx.get(oglasRef);
        if (!oglasSnap.exists) throw Exception('Oglas ne obstaja več.');
        final data = oglasSnap.data()!;

        final totalPortions = (data['portions'] as num?)?.toInt() ?? 1;
        final currentRemaining = (data['remainingPortions'] as num?)?.toInt() ?? 0;
        final restored = (currentRemaining + kolicinaPorcij).clamp(0, totalPortions);

        tx.update(oglasRef, {
          'remainingPortions': restored,
          'status': 'naRazpolago',
        });
        tx.update(rezervacijaRef, {'status': 'preklicano'});
      });
    }
  }

  // ── Potrdi prevzem ────────────────────────────────────────────────────────
  Future<String> potrdiPrevzem({
    required String rezervacijaId,
    required String oglasId,
    required String pickupToken,
    required String ownerUid,
    required String currentUserUid,
  }) async {
    if (currentUserUid != ownerUid) {
      throw Exception('Ta potrditvena stran je namenjena organizaciji, ki je objavo ustvarila.');
    }

    final rezervacijaRef = _db.collection('rezervacije').doc(rezervacijaId);
    final oglasRef = _db.collection('oglasi').doc(oglasId);
    final confirmationCode = (100000 + Random().nextInt(900000)).toString();

    await _db.runTransaction((tx) async {
      final rezSnap = await tx.get(rezervacijaRef);
      if (!rezSnap.exists) throw Exception('Rezervacija ne obstaja.');
      final rezData = rezSnap.data()!;

      if ((rezData['pickupToken'] as String?) != pickupToken) {
        throw Exception('QR koda ni več veljavna.');
      }
      if ((rezData['status'] as String?) == 'prevzeto') {
        throw Exception('Prevzem je že bil potrjen.');
      }

      final oglasSnap = await tx.get(oglasRef);
      final oglasData = oglasSnap.data() as Map<String, dynamic>?;
      final remaining = (oglasData?['remainingPortions'] as num?)?.toInt() ?? 0;

      tx.update(rezervacijaRef, {
        'status': 'prevzeto',
        'pickupConfirmedAt': FieldValue.serverTimestamp(),
        'pickupToken': FieldValue.delete(),
        'pickupConfirmationCode': confirmationCode,
      });

      if (remaining == 0) {
        tx.update(oglasRef, {'status': 'prevzeto'});
      }
    });

    _posodobiStatusOglasaPoRezervaciji(oglasId).catchError(
      (e) => debugPrint('Status oglas update failed: $e'),
    );

    return confirmationCode;
  }

  // ── Dodaj v čakalno vrsto ─────────────────────────────────────────────────
  Future<void> dodajVWaitlist({required String oglasId, required String userId}) async {
    await _db.collection('oglasi').doc(oglasId).update({
      'waitlist': FieldValue.arrayUnion([userId]),
    });
  }

  // ── Zapusti čakalno vrsto ─────────────────────────────────────────────────
  Future<void> zapustiWaitlist({required String oglasId, required String userId}) async {
    await _db.collection('oglasi').doc(oglasId).update({
      'waitlist': FieldValue.arrayRemove([userId]),
    });
  }

  // ── Pridobi aktivno rezervacijo uporabnika za oglas ───────────────────────
  Future<Rezervacija?> getUserReservation({
    required String oglasId,
    required String userId,
  }) async {
    final snap = await _db
        .collection('rezervacije')
        .where('oglasId', isEqualTo: oglasId)
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['rezervirano', 'na_voljo'])
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return docToRezervacija(snap.docs.first);
  }

  // ── Pridobi vse aktivne rezervacije za oglas ──────────────────────────────
  Future<List<Rezervacija>> getActiveReservations(String oglasId) async {
    final snap = await _db
        .collection('rezervacije')
        .where('oglasId', isEqualTo: oglasId)
        .where('status', whereIn: ['rezervirano', 'na_voljo'])
        .get();

    return snap.docs.map(docToRezervacija).toList();
  }

  // ── Posodobi status oglasa glede na rezervacije ───────────────────────────
  Future<void> _posodobiStatusOglasaPoRezervaciji(String oglasId) async {
    final activeSnap = await _db
        .collection('rezervacije')
        .where('oglasId', isEqualTo: oglasId)
        .where('status', whereIn: ['rezervirano', 'na_voljo'])
        .limit(1)
        .get();

    if (activeSnap.docs.isEmpty) {
      final oglasSnap = await _db.collection('oglasi').doc(oglasId).get();
      final data = oglasSnap.data();
      if (data == null) return;
      final remaining = (data['remainingPortions'] as num?)?.toInt() ?? 0;
      if (remaining == 0) {
        await _db.collection('oglasi').doc(oglasId).update({'status': 'prevzeto'});
      }
    }
  }

  // ── Pomožne funkcije ──────────────────────────────────────────────────────
  String _createToken() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(24, (_) => rnd.nextInt(256));
    return bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }

  String baseUrl() {
    final custom = dotenv.maybeGet('WEB_BASE_URL');
    if (custom != null && custom.trim().isNotEmpty) {
      return custom.trim().replaceAll(RegExp(r'/$'), '');
    }
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') return base.origin;
    return 'https://foodwastezero.web.app';
  }
}