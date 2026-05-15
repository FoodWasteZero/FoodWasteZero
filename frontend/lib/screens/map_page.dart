import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../models/models.dart';

// ── Map page — otvara se kad korisnik klikne "Pelji me tja" ──────────────────
// Koristi flutter_map + OpenStreetMap (bez API ključa)
// Dodaj u pubspec.yaml:
//   flutter_map: ^6.0.0
//   latlong2: ^0.9.0

// Ako još nemaš flutter_map, stranica prikazuje lijepu placeholder kartu
// s pinovima i uputama — zamijeni CustomPaint sa FlutterMap kad dodaš paket.

class MapPage extends StatefulWidget {
  final FoodOglas oglas;
  const MapPage({super.key, required this.oglas});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // Simulirana "moja lokacija" — centar Maribora
  // U produkciji zamijeni sa Geolocator.getCurrentPosition()
  static const _myLat = 46.5547;
  static const _myLng = 15.6450;

  @override
  Widget build(BuildContext context) {
    final oglas = widget.oglas;
    final dest = oglas.latLng;

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A2A),
      body: Stack(
        children: [
          // ── Mapa (CustomPaint placeholder — zamijeni sa FlutterMap)
          Positioned.fill(
            child: _MockMap(
              myLat: _myLat, myLng: _myLng,
              destLat: dest?.lat ?? _myLat,
              destLng: dest?.lng ?? _myLng,
            ),
          ),

          // ── Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _MapBtn(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: kRadius12,
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(oglas.location,
                            style: const TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kGreenAccent.withOpacity(0.85),
                            borderRadius: kRadiusFull,
                          ),
                          child: Text('${oglas.distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom card z info o oglasu
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: kBorder, borderRadius: kRadiusFull),
                  ),
                  const SizedBox(height: 20),

                  // Oglas info row
                  Row(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: oglas.imageColor,
                          borderRadius: kRadius12,
                        ),
                        child: Icon(oglas.icon, color: kGreenMid.withOpacity(0.55), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(oglas.title,
                              style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700, color: kTextDark),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: kTextLight),
                              const SizedBox(width: 3),
                              Text(oglas.location,
                                style: kCaption.copyWith(fontSize: 11)),
                            ]),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kGreenPale,
                          borderRadius: kRadius8,
                        ),
                        child: Column(
                          children: [
                            Text('${oglas.distanceKm.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w900, color: kGreenMid)),
                            const Text('km', style: TextStyle(fontSize: 10,
                              color: kGreenMid, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Koraki (mock)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: kRadius12,
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      children: [
                        _RouteStep(
                          icon: Icons.my_location_rounded,
                          color: kGreenMid,
                          label: 'Vaša lokacija',
                          sub: 'Maribor, Center',
                          isFirst: true,
                        ),
                        _RouteStep(
                          icon: Icons.location_on_rounded,
                          color: kOrange,
                          label: oglas.title,
                          sub: oglas.location,
                          isFirst: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CTA dugme
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Navigacija se zaganja...'))),
                      icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 20),
                      label: const Text('Začni navigacijo',
                        style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreenMid,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(borderRadius: kRadius12),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Route step widget ─────────────────────────────────────────────────────────
class _RouteStep extends StatelessWidget {
  final IconData icon; final Color color;
  final String label, sub; final bool isFirst;
  const _RouteStep({required this.icon, required this.color,
    required this.label, required this.sub, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          if (!isFirst) const SizedBox.shrink()
          else Container(
            width: 2, height: 24,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: kBorder,
              borderRadius: kRadiusFull,
            ),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: kTextDark),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(sub, style: kCaption),
                if (isFirst) const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Map button helper ─────────────────────────────────────────────────────────
class _MapBtn extends StatelessWidget {
  final Widget child; final VoidCallback onTap;
  const _MapBtn({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: kRadius12,
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: child,
    ),
  );
}

// ── Mock map s pinovima (zamijeni sa FlutterMap) ──────────────────────────────
class _MockMap extends StatefulWidget {
  final double myLat, myLng, destLat, destLng;
  const _MockMap({required this.myLat, required this.myLng,
    required this.destLat, required this.destLng});
  @override State<_MockMap> createState() => _MockMapState();
}

class _MockMapState extends State<_MockMap> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.8, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => CustomPaint(
        painter: _MapPainter(_pulse.value),
        child: Container(color: const Color(0xFF1A3A2A)),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final double pulse;
  _MapPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridP = Paint()..color = const Color(0xFF2A4A3A)..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 40)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridP);
    for (double x = 0; x < size.width; x += 40)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridP);

    // Ceste
    final roadP = Paint()..color = const Color(0xFF3A5A4A)..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.45), roadP);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), roadP);
    canvas.drawLine(Offset(size.width * 0.65, 0), Offset(size.width * 0.65, size.height), roadP);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.7), roadP);

    // Lokacija korisnika — plava točka s pulsirajućim ringom
    final myX = size.width * 0.35;
    final myY = size.height * 0.45;
    canvas.drawCircle(Offset(myX, myY), 22 * pulse,
      Paint()..color = const Color(0xFF2196F3).withOpacity(0.2 * pulse));
    canvas.drawCircle(Offset(myX, myY), 8,
      Paint()..color = Colors.white);
    canvas.drawCircle(Offset(myX, myY), 6,
      Paint()..color = const Color(0xFF2196F3));

    // Destinacija — zeleni pin
    final dX = size.width * 0.65;
    final dY = size.height * 0.3;

    // Linija rute (dashed)
    final routeP = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    _drawDashedLine(canvas, Offset(myX, myY), Offset(dX, dY), routeP);

    // Pin shadow
    canvas.drawCircle(Offset(dX, dY + 4), 10,
      Paint()..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // Pin body
    final pinP = Paint()..color = const Color(0xFF2E7D32);
    final pinPath = Path()
      ..moveTo(dX, dY + 14)
      ..quadraticBezierTo(dX - 14, dY, dX - 14, dY - 10)
      ..arcToPoint(Offset(dX + 14, dY - 10),
        radius: const Radius.circular(14), clockwise: true)
      ..quadraticBezierTo(dX + 14, dY, dX, dY + 14)
      ..close();
    canvas.drawPath(pinPath, pinP);
    canvas.drawCircle(Offset(dX, dY - 10), 6,
      Paint()..color = Colors.white);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 10.0;
    const gapLen = 6.0;
    final total = (end - start).distance;
    var drawn = 0.0;
    final dir = (end - start) / total;
    while (drawn < total) {
      final from = start + dir * drawn;
      final to = start + dir * (drawn + dashLen).clamp(0, total);
      canvas.drawLine(from, to, paint);
      drawn += dashLen + gapLen;
    }
  }

  @override bool shouldRepaint(_MapPainter o) => o.pulse != pulse;
}