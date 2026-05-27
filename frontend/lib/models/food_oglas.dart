import 'package:flutter/material.dart';

enum OglasStatus { naRazpolago, rezervirano, prevzeto }

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

class FoodOglas {
  final String id;
  final String? uid;
  final String title;
  final String description;
  final String location;
  final String time;
  final OglasStatus status;
  final String? username;
  final Color imageColor;
  final String category;
  final bool isFree;
  final bool isExpiringSoon;
  final double distanceKm;
  final IconData icon;
  final LatLng? latLng;
  final String? imageBase64;
  final String? reservedByUid;
  final DateTime? expiryDate;
  final DateTime? termin1;
  final DateTime? termin2;
  final DateTime? termin3;
  final DateTime? termin4;
  final DateTime? chosenTermin;
  final bool offerPending;
  final DateTime? offerExpiresAt;
  final String? offerToken;
  final List<String> waitlist;
  final int? portions;          // NOVO: skupno število porcij
  final int? remainingPortions; // NOVO: preostale porcije
  final double? price;          // NOVO: cena (0 ali null = brezplačno)
  final bool isDavatelj;        // NOVO: true = oglas od organizacije

  const FoodOglas({
    required this.id,
    this.uid,
    required this.title,
    this.description = '',
    required this.location,
    required this.time,
    required this.status,
    this.username,
    required this.imageColor,
    required this.category,
    this.isFree = true,
    this.isExpiringSoon = false,
    this.distanceKm = 1.2,
    required this.icon,
    this.latLng,
    this.imageBase64,
    this.reservedByUid,
    this.expiryDate,
    this.termin1,
    this.termin2,
    this.termin3,
    this.termin4,
    this.chosenTermin,
    this.offerPending = false,
    this.offerExpiresAt,
    this.offerToken,
    this.waitlist = const [],
    this.portions,
    this.remainingPortions,
    this.price,
    this.isDavatelj = false,
  });

  FoodOglas copyWithDistance(double km) => FoodOglas(
    id: id, uid: uid, title: title, description: description,
    location: location, time: time, status: status, username: username,
    imageColor: imageColor, category: category, isFree: isFree,
    isExpiringSoon: isExpiringSoon, distanceKm: km, icon: icon,
    latLng: latLng, imageBase64: imageBase64, reservedByUid: reservedByUid,
    expiryDate: expiryDate, termin1: termin1, termin2: termin2,
    termin3: termin3, termin4: termin4, chosenTermin: chosenTermin,
    offerPending: offerPending, offerExpiresAt: offerExpiresAt,
    offerToken: offerToken, waitlist: waitlist,
    portions: portions, remainingPortions: remainingPortions,
    price: price, isDavatelj: isDavatelj,
  );
}

Color statusColor(OglasStatus s) {
  switch (s) {
    case OglasStatus.naRazpolago: return const Color(0xFF4CAF50);
    case OglasStatus.rezervirano: return const Color(0xFFFFA726);
    case OglasStatus.prevzeto:    return const Color(0xFF78909C);
  }
}

String statusLabel(OglasStatus s) {
  switch (s) {
    case OglasStatus.naRazpolago: return 'NA RAZPOLAGO';
    case OglasStatus.rezervirano: return 'REZERVIRANO';
    case OglasStatus.prevzeto:    return 'PREVZETO';
  }
}