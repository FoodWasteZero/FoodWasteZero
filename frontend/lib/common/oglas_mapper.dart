import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';

String timeAgoFromDate(DateTime? dt) {
  if (dt == null) return 'Pravkar';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Pravkar';
  if (diff.inMinutes < 60) return 'Pred ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Pred ${diff.inHours} ur';
  return 'Pred ${diff.inDays} dni';
}

// ── Oglas mapper ──────────────────────────────────────────────────────────────
FoodOglas docToFoodOglas(DocumentSnapshot doc, {double defaultDistKm = 1.0}) {
  final d = doc.data() as Map<String, dynamic>;
  final statusStr = d['status'] as String? ?? 'naRazpolago';
  final status = statusStr == 'rezervirano'
      ? OglasStatus.rezervirano
      : statusStr == 'prevzeto'
          ? OglasStatus.prevzeto
          : OglasStatus.naRazpolago;

  final category = d['category'] as String? ?? 'Sestavine';
  final IconData icon;
  final Color color;
  switch (category) {
    case 'Kuhano':
      icon = Icons.soup_kitchen_rounded;
      color = const Color(0xFFFFE0B2);
      break;
    case 'Peka':
      icon = Icons.bakery_dining_rounded;
      color = const Color(0xFFEFEBE9);
      break;
    case 'Sadje & zelenjava':
      icon = Icons.apple_rounded;
      color = const Color(0xFFE8F5E9);
      break;
    case 'Ostalo':
      icon = Icons.more_horiz_rounded;
      color = const Color(0xFFE8EAF6);
      break;
    default:
      icon = Icons.grass_rounded;
      color = const Color(0xFFF1F8E9);
  }

  double distKm = defaultDistKm;
  final lat = (d['lat'] as num?)?.toDouble();
  final lng = (d['lng'] as num?)?.toDouble();
  if (lat != null && lng != null) {
    const refLat = 46.5547;
    const refLng = 15.6459;
    final dLat = (lat - refLat) * 111.0;
    final dLng = (lng - refLng) * 111.0 * cos(refLat * pi / 180);
    distKm = sqrt(dLat * dLat + dLng * dLng);
  }

  final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
  final expiryDate = (d['expiryDate'] as Timestamp?)?.toDate();

  bool expiringSoon = d['expiringSoon'] as bool? ?? false;
  if (expiryDate != null) {
    final hoursLeft = expiryDate.difference(DateTime.now()).inHours;
    if (hoursLeft <= 24 && hoursLeft >= 0) expiringSoon = true;
  }

  final waitlistRaw = d['waitlist'];
  final waitlist = (waitlistRaw is List)
      ? waitlistRaw.map((e) => e.toString()).toList()
      : <String>[];

  return FoodOglas(
    id: doc.id,
    uid: d['uid'] as String?,
    title: d['title'] as String? ?? '',
    description: d['description'] as String? ?? '',
    location: d['location'] as String? ?? '',
    time: timeAgoFromDate(createdAt),
    status: status,
    username: d['username'] as String?,
    imageColor: color,
    category: category,
    isFree: d['isFree'] as bool? ?? true,
    isExpiringSoon: expiringSoon,
    distanceKm: distKm,
    icon: icon,
    latLng: (lat != null && lng != null) ? LatLng(lat, lng) : null,
    imageBase64: d['imageBase64'] as String?,
    expiryDate: expiryDate,
    termin1: (d['termin1'] as Timestamp?)?.toDate(),
    waitlist: waitlist,
    portions: (d['portions'] as num?)?.toInt(),
    remainingPortions: (d['remainingPortions'] as num?)?.toInt(),
    price: (d['price'] as num?)?.toDouble(),
    isDavatelj: d['isDavatelj'] as bool? ?? false,
  );
}

// ── Rezervacija mapper ────────────────────────────────────────────────────────
Rezervacija docToRezervacija(DocumentSnapshot doc) {
  final d = doc.data() as Map<String, dynamic>;
  return Rezervacija(
    id: doc.id,
    oglasId: d['oglasId'] as String? ?? '',
    userId: d['userId'] as String? ?? '',
    kolicinaPorcij: (d['kolicinaPorcij'] as num?)?.toInt() ?? 1,
    status: rezervacijaStatusFromString(d['status'] as String? ?? 'na_voljo'),
    createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    chosenTermin: (d['chosenTermin'] as Timestamp?)?.toDate(),
    offerPending: d['offerPending'] as bool? ?? false,
    offerExpiresAt: (d['offerExpiresAt'] as Timestamp?)?.toDate(),
    offerToken: d['offerToken'] as String?,
    pickupToken: d['pickupToken'] as String?,
    waitlistPosition: (d['waitlistPosition'] as num?)?.toInt(),
  );
}

void sortOglasDocsNewestFirst(List<QueryDocumentSnapshot> docs) {
  docs.sort((a, b) {
    final ta = (a.data() as Map<String, dynamic>?)?['createdAt'];
    final tb = (b.data() as Map<String, dynamic>?)?['createdAt'];
    final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
    final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
    return mb.compareTo(ma);
  });
}