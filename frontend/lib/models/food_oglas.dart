import 'package:flutter/material.dart';

enum OglasStatus { naRazpolago, rezervirano, prevzeto }

// Statusi rezervacije
enum RezervacijaStatus { naVoljo, rezervirano, prevzeto, preklicano }

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

// ── FoodOglas ─────────────────────────────────────────────────────────────────
// Rezervacija-specifični atributi so odstranjeni iz oglasa in živijo v
// kolekciji 'rezervacije'. Na oglasu ostanejo samo podatki o ponudbi.
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
  final DateTime? expiryDate;
  final DateTime? termin1;
  final DateTime? termin2;
  final DateTime? termin3;
  final DateTime? termin4;
  final int? portions;           // skupno število porcij
  final int? remainingPortions;  // preostale porcije (se posodablja ob rezervacijah)
  final double? price;           // cena na porcijo
  final bool isDavatelj;         // true = oglas je od organizacije (davatelja)
  // Čakalna vrsta ostane na oglasu (lista uidov ki čakajo)
  final List<String> waitlist;

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
    this.expiryDate,
    this.termin1,
    this.termin2,
    this.termin3,
    this.termin4,
    this.portions,
    this.remainingPortions,
    this.price,
    this.isDavatelj = false,
    this.waitlist = const [],
  });

  FoodOglas copyWithDistance(double km) => FoodOglas(
    id: id, uid: uid, title: title, description: description,
    location: location, time: time, status: status, username: username,
    imageColor: imageColor, category: category, isFree: isFree,
    isExpiringSoon: isExpiringSoon, distanceKm: km, icon: icon,
    latLng: latLng, imageBase64: imageBase64,
    expiryDate: expiryDate, termin1: termin1, termin2: termin2,
    termin3: termin3, termin4: termin4,
    portions: portions, remainingPortions: remainingPortions,
    price: price, isDavatelj: isDavatelj, waitlist: waitlist,
  );
}

// ── Rezervacija ───────────────────────────────────────────────────────────────
// Vsaka rezervacija je samostojen dokument v kolekciji 'rezervacije'.
// En oglas ima lahko več aktivnih rezervacij (dokler so porcije na voljo).
class Rezervacija {
  final String id;
  final String oglasId;
  final String userId;
  final int kolicinaPorcij;
  final RezervacijaStatus status;
  final DateTime createdAt;
  final DateTime? chosenTermin;    // izbrani termin prevzema
  final bool offerPending;         // true = čaka na potrditev (čakalna vrsta)
  final DateTime? offerExpiresAt;  // kdaj poteče ponudba iz čakalne vrste
  final String? offerToken;        // token za claim link (čakalna vrsta)
  final String? pickupToken;       // token za QR prevzem
  final int? waitlistPosition;     // pozicija v čakalni vrsti (null = ni v vrsti)

  const Rezervacija({
    required this.id,
    required this.oglasId,
    required this.userId,
    required this.kolicinaPorcij,
    required this.status,
    required this.createdAt,
    this.chosenTermin,
    this.offerPending = false,
    this.offerExpiresAt,
    this.offerToken,
    this.pickupToken,
    this.waitlistPosition,
  });

  bool get jeAktivna =>
      status == RezervacijaStatus.rezervirano ||
      status == RezervacijaStatus.naVoljo;

  bool get jePrevzeta => status == RezervacijaStatus.prevzeto;
  bool get jePreklicana => status == RezervacijaStatus.preklicano;
}

// ── Pomožne funkcije za prikaz statusa oglasa ─────────────────────────────────
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

// ── Pomožne funkcije za status rezervacije ────────────────────────────────────
RezervacijaStatus rezervacijaStatusFromString(String s) {
  switch (s) {
    case 'prevzeto':    return RezervacijaStatus.prevzeto;
    case 'preklicano':  return RezervacijaStatus.preklicano;
    case 'rezervirano': return RezervacijaStatus.rezervirano;
    default:            return RezervacijaStatus.naVoljo;
  }
}

String rezervacijaStatusToString(RezervacijaStatus s) {
  switch (s) {
    case RezervacijaStatus.naVoljo:    return 'na_voljo';
    case RezervacijaStatus.rezervirano: return 'rezervirano';
    case RezervacijaStatus.prevzeto:   return 'prevzeto';
    case RezervacijaStatus.preklicano: return 'preklicano';
  }
}