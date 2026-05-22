import 'package:flutter/material.dart';

enum OglasStatus { naRazpolago, rezervirano, prevzeto }

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

class FoodOglas {
  final String id;
  final String? uid;          // vlasnik oglasa (davatelj)
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
  final List<String> waitlist; // NOVO

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
    this.waitlist = const [],
  });

  // Kopira oglas z novo razdaljo (za GPS sortiranje)
  FoodOglas copyWithDistance(double km) => FoodOglas(
    id: id, uid: uid, title: title, description: description,
    location: location, time: time, status: status, username: username,
    imageColor: imageColor, category: category, isFree: isFree,
    isExpiringSoon: isExpiringSoon, distanceKm: km, icon: icon,
    latLng: latLng, imageBase64: imageBase64, reservedByUid: reservedByUid,
    expiryDate: expiryDate, waitlist: waitlist,
  );
}

final List<FoodOglas> kSampleOglasi = [
  const FoodOglas(
    id: '1',
    title: 'Domača jabolka z vrta (cca 5 kg)',
    description: 'Sveža domača jabolka, sort Zlati delišes. Brez škropljenja.',
    location: 'Maribor, Center',
    time: 'Pred 32 min',
    status: OglasStatus.naRazpolago,
    imageColor: Color(0xFFE8F5E9),
    category: 'Sadje & zelenjava',
    isFree: true,
    distanceKm: 0.4,
    icon: Icons.apple,
    latLng: LatLng(46.5562, 15.6450),
  ),
  const FoodOglas(
    id: '2',
    title: 'Polna posoda Golaža',
    description: 'Domač golaž, kuhan danes zjutraj. Dovolj za 4 osebe.',
    location: 'Tezno, Maribor',
    time: 'Pred 1 uro',
    status: OglasStatus.rezervirano,
    username: '@AnaMarija',
    imageColor: Color(0xFFFFE0B2),
    category: 'Kuhano',
    isFree: true,
    isExpiringSoon: true,
    distanceKm: 1.8,
    icon: Icons.soup_kitchen,
    latLng: LatLng(46.5480, 15.6610),
  ),
  const FoodOglas(
    id: '3',
    title: 'Svež domač kmečki kruh (polovica)',
    description: 'Pol štruce domačega kruha, pečenega danes.',
    location: 'Hoče',
    time: 'Pred 2 urama',
    status: OglasStatus.prevzeto,
    username: '@LukaP',
    imageColor: Color(0xFFEFEBE9),
    category: 'Peka',
    isFree: false,
    distanceKm: 3.1,
    icon: Icons.bakery_dining,
    latLng: LatLng(46.5100, 15.6500),
  ),
  const FoodOglas(
    id: '4',
    title: 'Rižota s piščancem',
    description: 'Domača rižota s piščančjim filejem in zelenjavo.',
    location: 'Center, Maribor',
    time: 'Pred 3 urama',
    status: OglasStatus.naRazpolago,
    imageColor: Color(0xFFF9FBE7),
    category: 'Kuhano',
    isFree: true,
    distanceKm: 0.7,
    icon: Icons.rice_bowl,
    latLng: LatLng(46.5547, 15.6459),
  ),
  const FoodOglas(
    id: '5',
    title: 'Paradižnik iz vrta (2 kg)',
    description: 'Zrel domač paradižnik, različne sorte.',
    location: 'Pobrežje',
    time: 'Pred 20 min',
    status: OglasStatus.naRazpolago,
    imageColor: Color(0xFFFFEBEE),
    category: 'Sadje & zelenjava',
    isFree: true,
    isExpiringSoon: true,
    distanceKm: 2.3,
    icon: Icons.grass,
    latLng: LatLng(46.5600, 15.6700),
  ),
];

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