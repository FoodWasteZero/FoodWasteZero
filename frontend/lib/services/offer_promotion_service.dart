import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'email_service.dart';

/// Lightweight client-driven promotion service.
///
/// Listens for documents with `offerPending == true` and, when the
/// `offerExpiresAt` timestamp passes, runs a transaction to either
/// assign the reservation to the next user in `waitlist` or mark the
/// ad as available again. This allows a 3-hour offer window without
/// Cloud Functions (best-effort: requires at least one active client).
class OfferPromotionService {
  OfferPromotionService._();
  static final OfferPromotionService instance = OfferPromotionService._();

  StreamSubscription<QuerySnapshot>? _sub;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    _sub = FirebaseFirestore.instance
        .collection('oglasi')
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
        final offerExpiresTs = data['offerExpiresAt'] as Timestamp?;
        if (offerExpiresTs == null) continue;
        final offerExpires = offerExpiresTs.toDate();
        if (offerExpires.isAfter(now)) continue;

        final waitRaw = data['waitlist'] as List<dynamic>? ?? [];
        final waitlist = waitRaw.map((e) => e.toString()).toList();
        if (waitlist.isNotEmpty) {
          await promoteNextUser(
            docId: doc.reference.id,
            nextUid: waitlist.first,
            remainingWaitlist: waitlist.skip(1).toList(),
            title: data['title'] as String? ?? '',
            termin1: data['termin1'] as Timestamp?,
            termin2: data['termin2'] as Timestamp?,
            termin3: data['termin3'] as Timestamp?,
            termin4: data['termin4'] as Timestamp?,
          );
        } else {
          await doc.reference.update({
            'status': 'naRazpolago',
            'reservedByUid': FieldValue.delete(),
            'offerPending': false,
            'offerExpiresAt': FieldValue.delete(),
            'offeredUid': FieldValue.delete(),
            'offerToken': FieldValue.delete(),
            'chosenTermin': FieldValue.delete(),
              'pickupToken': FieldValue.delete(),
          });
        }
      } catch (_) {
        // Best-effort; ignore transient failures.
      }
    }
  }

  Future<void> promoteNextUser({
    required String docId,
    required String nextUid,
    required List<String> remainingWaitlist,
    required String title,
    required Timestamp? termin1,
    required Timestamp? termin2,
    required Timestamp? termin3,
    required Timestamp? termin4,
  }) async {
    final offerToken = _createToken();
    debugPrint('OfferPromotion: promoteNextUser doc=$docId nextUid=$nextUid token=$offerToken');
    final ref = FirebaseFirestore.instance.collection('oglasi').doc(docId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapDoc = await tx.get(ref);
      final d = snapDoc.data() as Map<String, dynamic>?;
      if (d == null) return;
      tx.update(ref, {
        'status': 'rezervirano',
        'reservedByUid': nextUid,
        'waitlist': remainingWaitlist,
        'offerPending': true,
        'offeredUid': nextUid,
        'offerExpiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 3))),
        'offerToken': offerToken,
        'offerNotifiedAt': FieldValue.delete(),
        'chosenTermin': FieldValue.delete(),
        'pickupToken': FieldValue.delete(),
        'reservedAt': FieldValue.serverTimestamp(),
      });
    });

    // Schedule sending the offer email asynchronously so callers (e.g. the
    // cancelling user) don't have to wait for the external HTTP request to
    // complete. The transaction above is the important part and completes
    // before we return.
    _sendOfferEmail(docId, nextUid, title, offerToken, termin1, termin2, termin3, termin4)
      .catchError((e) => debugPrint('OfferPromotion: async email send failed: $e'));
    debugPrint('OfferPromotion: email send scheduled (async) for doc=$docId');
  }

  Future<void> _sendOfferEmail(
    String docId,
    String uid,
    String title,
    String offerToken,
    Timestamp? termin1,
    Timestamp? termin2,
    Timestamp? termin3,
    Timestamp? termin4,
  ) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final email = userDoc.data()?['email'] as String?;
      if (email == null || email.isEmpty) return;
      debugPrint('OfferPromotion: preparing to send offer email to $email for doc $docId');
      final baseUrl = _baseUrl();
      final claimUrl = '$baseUrl/?claim=$docId&uid=$uid&token=$offerToken';

      final selectedTerm = [termin1, termin2, termin3, termin4]
          .whereType<Timestamp>()
          .map((t) => t.toDate())
          .toList();
      final termLabel = selectedTerm.isNotEmpty ? _formatDateTime(selectedTerm.first) : null;

      await EmailService.sendClaimEmail(
        to: email,
        title: title,
        claimUrl: claimUrl,
        selectedTermLabel: termLabel,
      );

      await FirebaseFirestore.instance.collection('oglasi').doc(docId).update({
        'offerNotifiedAt': FieldValue.serverTimestamp(),
        'offerEmailTo': email,
      });
    } catch (e) {
      debugPrint('Failed to send offer email: $e');
    }
  }

  String _createToken() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(24, (_) => rnd.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  String _baseUrl() {
    final custom = dotenv.maybeGet('WEB_BASE_URL');
    if (custom != null && custom.trim().isNotEmpty) {
      return custom.trim().replaceAll(RegExp(r'/$'), '');
    }
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') {
      return base.origin;
    }
    return 'https://foodwastezero.web.app';
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.${dt.year} $hour:$minute';
  }
}
