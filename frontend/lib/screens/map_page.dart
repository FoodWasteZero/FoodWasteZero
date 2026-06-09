import 'package:flutter/material.dart';
import '../common/theme.dart';
import '../models/models.dart';

// ── Map page s obrisom Slovenije ─────────────────────────────────────────────
class MapPage extends StatefulWidget {
  final FoodOglas oglas;
  const MapPage({super.key, required this.oglas});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  // Maribor koordinate (normalizirane na [0,1] unutar bounding-boxa Slovenije)
  // Slovenia lon: 13.38–16.61, lat: 45.42–46.88
  static const _myLat = 46.5547;
  static const _myLng = 15.6450;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  late AnimationController _zoomCtrl;
  late Animation<double> _zoomAnim;
  late Animation<Offset> _panAnim;

  bool _zoomed = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _zoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _zoomAnim = Tween(begin: 1.0, end: 3.2)
        .animate(CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeInOutCubic));
    _panAnim = Tween(
      begin: Offset.zero,
      // Pan prema Mariboru (desna strana Slovenije, malo gore od centra)
      end: const Offset(-0.28, 0.08),
    ).animate(CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _zoomCtrl.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    setState(() {
      _zoomed = !_zoomed;
      if (_zoomed) {
        _zoomCtrl.forward();
      } else {
        _zoomCtrl.reverse();
      }
    });
  }

  // Normaliziraj koordinate na [0,1] unutar bounding boxa Slovenije
  static Offset _latLngToNorm(double lat, double lng) {
    const minLng = 13.38, maxLng = 16.61;
    const minLat = 45.42, maxLat = 46.88;
    return Offset(
      (lng - minLng) / (maxLng - minLng),
      1.0 - (lat - minLat) / (maxLat - minLat),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final oglas = widget.oglas;

    return Scaffold(
      backgroundColor: const Color(0xFF0D2318),
      body: Stack(
        children: [
          // ── Mapa s obrisom
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulse, _zoomCtrl]),
              builder: (context, _) {
                return GestureDetector(
                  onTap: () {
                    _toggleZoom();
                  },
                  child: ClipRect(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scale(_zoomAnim.value)
                        ..translate(
                          _panAnim.value.dx *
                              MediaQuery.of(context).size.width,
                          _panAnim.value.dy *
                              MediaQuery.of(context).size.height,
                        ),
                      child: CustomPaint(
                        painter: _SlovenijaMapPainter(
                          pulse: _pulse.value,
                          myNorm: _latLngToNorm(_myLat, _myLng),
                          destNorm: oglas.latLng != null
                              ? _latLngToNorm(
                                  oglas.latLng!.lat, oglas.latLng!.lng)
                              : _latLngToNorm(_myLat + 0.05, _myLng - 0.3),
                          zoomed: _zoomed,
                        ),
                        child: Container(
                          color: const Color(0xFF0D2318),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Hint za tap (prikaži samo kad nije zoomed)
          if (!_zoomed)
            Positioned(
              bottom: 240,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _zoomed ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: kRadiusFull,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded,
                            color: Colors.white70, size: 16),
                        SizedBox(width: 6),
                        Text('Tapni za zoom na lokaciju',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Zoom out gumb
          if (_zoomed)
            Positioned(
              top: 80,
              right: 16,
              child: SafeArea(
                child: GestureDetector(
                  onTap: _toggleZoom,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: kRadius12,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_out_rounded,
                            color: c.card, size: 16),
                        SizedBox(width: 4),
                        Text('Cijela Slovenija',
                            style: TextStyle(
                                color: c.card, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
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
                    child: Icon(Icons.arrow_back_rounded,
                        color: c.card, size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: kRadius12,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        Icon(Icons.location_on_rounded,
                            color: c.card, size: 14),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(oglas.location,
                            style: TextStyle(
                                color: c.card,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kGreenAccent.withOpacity(0.85),
                            borderRadius: kRadiusFull,
                          ),
                          child: Text(
                              '${oglas.distanceKm.toStringAsFixed(1)} km',
                              style: TextStyle(
                                  color: c.card,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ),
                  SizedBox(width: 8),
                  // ── Moja lokacija kvadratić – klik = zoom ──────────────
                  _MapBtn(
                    onTap: _toggleZoom,
                    child: Icon(
                      _zoomed
                          ? Icons.zoom_out_map_rounded
                          : Icons.my_location_rounded,
                      color: c.card,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: c.border, borderRadius: kRadiusFull),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: oglas.imageColor,
                          borderRadius: kRadius12,
                        ),
                        child: Icon(oglas.icon,
                            color: kGreenMid.withOpacity(0.55), size: 28),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(oglas.title,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: c.textDark),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                            SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.location_on_outlined,
                                  size: 12, color: c.textLight),
                              SizedBox(width: 3),
                              Text(oglas.location,
                                  style: kCaption.copyWith(fontSize: 14)),
                            ]),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kGreenPale,
                          borderRadius: kRadius8,
                        ),
                        child: Column(
                          children: [
                            Text(
                                '${oglas.distanceKm.toStringAsFixed(1)}',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: kGreenMid)),
                            Text('km',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: kGreenMid,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: kRadius12,
                      border: Border.all(color: c.border),
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
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Navigacija se zaganja...'))),
                      icon: Icon(Icons.directions_rounded,
                          color: c.card, size: 20),
                      label: Text('Začni navigacijo',
                          style: TextStyle(
                              color: c.card,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreenMid,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                            borderRadius: kRadius12),
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
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

// ── Painter s obrisom Slovenije ───────────────────────────────────────────────
class _SlovenijaMapPainter extends CustomPainter {
  final double pulse;
  final Offset myNorm;
  final Offset destNorm;
  final bool zoomed;

  _SlovenijaMapPainter({
    required this.pulse,
    required this.myNorm,
    required this.destNorm,
    required this.zoomed,
  });

  // ── Obrub Slovenije (normalizirane točke [0,1]) ───────────────────────────
  static const List<List<double>> _sloPoints = [
    [0.02, 0.72], [0.04, 0.65], [0.00, 0.58], [0.03, 0.50], [0.06, 0.45],
    [0.10, 0.40], [0.13, 0.33], [0.16, 0.28], [0.18, 0.22],
    [0.22, 0.15], [0.26, 0.08], [0.30, 0.04], [0.35, 0.01], [0.40, 0.03],
    [0.44, 0.06], [0.48, 0.02], [0.52, 0.00], [0.56, 0.03], [0.60, 0.07],
    [0.64, 0.04], [0.68, 0.02], [0.72, 0.05], [0.76, 0.08],
    [0.80, 0.12], [0.84, 0.18], [0.88, 0.22], [0.92, 0.20], [0.97, 0.25],
    [1.00, 0.30], [0.98, 0.36], [0.95, 0.42], [0.97, 0.48], [0.99, 0.55],
    [0.96, 0.60], [0.92, 0.58], [0.88, 0.62],
    [0.84, 0.68], [0.80, 0.72], [0.76, 0.75], [0.72, 0.80], [0.68, 0.84],
    [0.64, 0.88], [0.60, 0.92], [0.56, 0.96], [0.52, 0.98], [0.48, 0.95],
    [0.44, 0.90], [0.40, 0.85], [0.36, 0.88], [0.32, 0.84], [0.28, 0.80],
    [0.24, 0.76], [0.20, 0.80], [0.16, 0.84], [0.12, 0.82], [0.08, 0.78],
    [0.04, 0.76], [0.02, 0.72],
  ];

  // ── Regijske granice unutar Slovenije ────────────────────────────────────
  // Svaka lista = jedna linija granice (normalizirane točke)
  static const List<List<List<double>>> _regionBorders = [
    // Gorenjska / Ljubljana — horizontalna granica sjever-centar
    [[0.18, 0.22], [0.28, 0.30], [0.38, 0.32], [0.48, 0.30], [0.58, 0.28], [0.65, 0.30]],
    // Ljubljana / Dolenjska — granica centar-jug
    [[0.38, 0.32], [0.45, 0.42], [0.50, 0.52], [0.52, 0.62], [0.50, 0.72]],
    // Ljubljana / Štajerska — dijagonalna granica
    [[0.58, 0.28], [0.65, 0.38], [0.70, 0.48], [0.72, 0.58], [0.70, 0.68]],
    // Koroška / Štajerska — sjeverna centralna
    [[0.60, 0.07], [0.65, 0.18], [0.70, 0.28], [0.74, 0.38]],
    // Prekmurje / Štajerska — istočna vertikalna
    [[0.88, 0.22], [0.87, 0.35], [0.86, 0.48], [0.84, 0.60]],
    // Primorska / Ljubljana — zapadna dijagonala
    [[0.18, 0.22], [0.22, 0.35], [0.24, 0.48], [0.26, 0.60], [0.28, 0.72]],
    // Kras / Notranjska
    [[0.10, 0.60], [0.18, 0.65], [0.26, 0.68], [0.34, 0.72]],
    // Dolenjska / Posavje
    [[0.50, 0.72], [0.58, 0.76], [0.66, 0.78], [0.70, 0.72]],
  ];

  Path _buildSloPath(Size size, {double padX = 0.08, double padY = 0.10}) {
    final w = size.width * (1 - 2 * padX);
    final h = size.height * (1 - 2 * padY);
    final ox = size.width * padX;
    final oy = size.height * padY;

    final path = Path();
    for (int i = 0; i < _sloPoints.length; i++) {
      final x = ox + _sloPoints[i][0] * w;
      final y = oy + _sloPoints[i][1] * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Offset _normToCanvas(Offset norm, Size size,
      {double padX = 0.08, double padY = 0.10}) {
    final w = size.width * (1 - 2 * padX);
    final h = size.height * (1 - 2 * padY);
    final ox = size.width * padX;
    final oy = size.height * padY;
    return Offset(ox + norm.dx * w, oy + norm.dy * h);
  }

  void _drawRegionBorders(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFF4AFF7A).withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final border in _regionBorders) {
      final path = Path();
      for (int i = 0; i < border.length; i++) {
        final pt = _normToCanvas(Offset(border[i][0], border[i][1]), size);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sloPath = _buildSloPath(size);

    // ── Pozadina (okolica) ────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A1E13),
    );

    // Suptilna mreža
    final gridPaint = Paint()
      ..color = const Color(0xFF152E1C)
      ..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // ── Vanjska sjena obrisa (glow efekt van) ────────────────────────────
    canvas.drawPath(
      sloPath,
      Paint()
        ..color = const Color(0xFF3ABA40).withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // ── Clip na obris Slovenije ───────────────────────────────────────────
    canvas.save();
    canvas.clipPath(sloPath);

    // ── SOLID fill prvo — garantira vidljivost teritorija ─────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1E6B38),
    );

    // ── Heatmap: gradijent overlay ────────────────────────────────────────
    final baseShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF2A7A44),
        Color(0xFF348A50),
        Color(0xFF3DA060),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = baseShader
        ..blendMode = BlendMode.srcOver,
    );

    // ── Hot spot: Ljubljana — max narudžbi ────────────────────────────────
    final ljShader = RadialGradient(
      center: const Alignment(-0.12, -0.10),
      radius: 0.44,
      colors: const [
        Color(0xFFCCFF55),
        Color(0xFF99EE30),
        Color(0xFF55CC28),
        Color(0x0030882A),
      ],
      stops: const [0.0, 0.22, 0.52, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = ljShader
        ..blendMode = BlendMode.lighten,
    );

    // ── Hot spot: Maribor ─────────────────────────────────────────────────
    final mbShader = RadialGradient(
      center: const Alignment(0.72, -0.20),
      radius: 0.36,
      colors: const [
        Color(0xFFBBFF44),
        Color(0xFF77DD30),
        Color(0xFF44BB28),
        Color(0x00268818),
      ],
      stops: const [0.0, 0.25, 0.55, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = mbShader
        ..blendMode = BlendMode.lighten,
    );

    // ── Hot spot: Celje ───────────────────────────────────────────────────
    final ceShader = RadialGradient(
      center: const Alignment(0.28, 0.12),
      radius: 0.26,
      colors: const [
        Color(0xFF88EE30),
        Color(0xFF55CC28),
        Color(0x0040AA20),
      ],
      stops: const [0.0, 0.42, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = ceShader
        ..blendMode = BlendMode.lighten,
    );

    // ── Hot spot: Koper ───────────────────────────────────────────────────
    final koShader = RadialGradient(
      center: const Alignment(-0.85, 0.50),
      radius: 0.24,
      colors: const [
        Color(0xFF66DD28),
        Color(0xFF44BB22),
        Color(0x00308C18),
      ],
      stops: const [0.0, 0.42, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = koShader
        ..blendMode = BlendMode.lighten,
    );

    // ── Regijske granice (unutar clipPath) ────────────────────────────────
    _drawRegionBorders(canvas, size);

    canvas.restore();

    // ── Vanjski obrub: sjena ──────────────────────────────────────────────
    canvas.drawPath(
      sloPath,
      Paint()
        ..color = Colors.black.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── Vanjski obrub: bijela linija (vidljive granice kao na slici) ──────
    canvas.drawPath(
      sloPath,
      Paint()
        ..color = Colors.white.withOpacity(0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Svjetlozeleni inner glow obruba ───────────────────────────────────
    canvas.drawPath(
      sloPath,
      Paint()
        ..color = const Color(0xFF88FF44).withOpacity(0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 4),
    );

    // ── Legenda narudžbi ──────────────────────────────────────────────────
    if (!zoomed) {
      _drawLegend(canvas, size);
    }

    // ── Gradovi ───────────────────────────────────────────────────────────
    final cities = [
      [0.60, 0.28, 'Ljubljana'],
      [0.87, 0.22, 'Maribor'],
      [0.96, 0.15, 'Murska S.'],
      [0.14, 0.50, 'Nova Gorica'],
      [0.06, 0.75, 'Koper'],
      [0.54, 0.80, 'Novo Mesto'],
      [0.68, 0.55, 'Celje'],
    ];

    for (final c in cities) {
      final pos = _normToCanvas(Offset(c[0] as double, c[1] as double), size);
      final isMaribor = (c[2] as String) == 'Maribor';

      canvas.drawCircle(
        pos,
        isMaribor ? 5.0 : 3.5,
        Paint()
          ..color = Colors.white.withOpacity(isMaribor ? 0.0 : 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
      canvas.drawCircle(
        pos,
        isMaribor ? 0 : 2.0,
        Paint()..color = const Color(0xFF0D2318).withOpacity(isMaribor ? 0.0 : 1.0),
      );

      if (!zoomed) {
        final tp = TextPainter(
          text: TextSpan(
            text: c[2] as String,
            style: TextStyle(
              color: Colors.white.withOpacity(isMaribor ? 0.0 : 0.90),
              fontSize: isMaribor ? 0 : 9,
              fontWeight: FontWeight.w700,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 5),
                Shadow(color: Colors.black, blurRadius: 2),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pos + const Offset(5, -6));
      }
    }

    // ── Moja lokacija (Maribor) ───────────────────────────────────────────
    final myPos = _normToCanvas(myNorm, size);

    canvas.drawCircle(
      myPos,
      28 * pulse,
      Paint()
        ..color = const Color(0xFF2196F3).withOpacity(0.15 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      myPos,
      18 * pulse,
      Paint()..color = const Color(0xFF2196F3).withOpacity(0.25 * pulse),
    );

    canvas.drawCircle(
      myPos,
      11,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawCircle(myPos, 8, Paint()..color = Colors.white);
    canvas.drawCircle(myPos, 6, Paint()..color = const Color(0xFF1E88E5));
    canvas.drawCircle(myPos, 3, Paint()..color = Colors.white);

    if (zoomed) {
      final tp = TextPainter(
        text: TextSpan(
          text: '📍 Ti si ovdje',
          style: TextStyle(
            color: c.card,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, myPos + const Offset(12, -24));
    }

    // ── Destinacija pin ───────────────────────────────────────────────────
    final dPos = _normToCanvas(destNorm, size);

    _drawDashedLine(
      canvas,
      myPos,
      dPos,
      Paint()
        ..color = const Color(0xFFFFDD00).withOpacity(0.85)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      dPos + const Offset(0, 5),
      12,
      Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final pinPath = Path()
      ..moveTo(dPos.dx, dPos.dy + 16)
      ..quadraticBezierTo(dPos.dx - 14, dPos.dy + 2, dPos.dx - 14, dPos.dy - 8)
      ..arcToPoint(
        Offset(dPos.dx + 14, dPos.dy - 8),
        radius: const Radius.circular(14),
        clockwise: true,
      )
      ..quadraticBezierTo(dPos.dx + 14, dPos.dy + 2, dPos.dx, dPos.dy + 16)
      ..close();

    canvas.drawPath(pinPath, Paint()..color = const Color(0xFFE65100));
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = const Color(0xFFFF6D00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
        Offset(dPos.dx, dPos.dy - 8), 6, Paint()..color = Colors.white);
  }

  void _drawLegend(Canvas canvas, Size size) {
    // Zelena legenda narudžbi
    const colors = [
      Color(0xFFB8F04A), // max narudžbi
      Color(0xFF7ED938),
      Color(0xFF4DB838),
      Color(0xFF2D8A4A),
      Color(0xFF1B4D2E), // min narudžbi
    ];
    const labels = ['Puno', 'Više', 'Srednje', 'Manje', 'Malo'];

    final startX = size.width - 60.0;
    final startY = size.height * 0.25;
    const boxSize = 16.0;
    const gap = 4.0;

    // Pozadina legende
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX - 12, startY - 10,
            58, colors.length * (boxSize + gap) + 24),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.black.withOpacity(0.5),
    );

    for (int i = 0; i < colors.length; i++) {
      final y = startY + i * (boxSize + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(startX, y, boxSize, boxSize),
          const Radius.circular(3),
        ),
        Paint()..color = colors[i],
      );
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: c.card,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(startX + boxSize + 5, y + 2));
    }

    // Naslov legende
    final titleTp = TextPainter(
      text: const TextSpan(
        text: 'Narudžbe',
        style: TextStyle(
            color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(
        canvas,
        Offset(startX - 4,
            startY + colors.length * (boxSize + gap) + 4));
  }

  void _drawDashedLine(
      Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 10.0;
    const gapLen = 6.0;
    final total = (end - start).distance;
    var drawn = 0.0;
    final dir = (end - start) / total;
    while (drawn < total) {
      final from = start + dir * drawn;
      final to = start + dir * (drawn + dashLen).clamp(0.0, total);
      canvas.drawLine(from, to, paint);
      drawn += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_SlovenijaMapPainter o) =>
      o.pulse != pulse || o.zoomed != zoomed;
}

// ── Route step widget ─────────────────────────────────────────────────────────
class _RouteStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, sub;
  final bool isFirst;
  const _RouteStep(
      {required this.icon,
      required this.color,
      required this.label,
      required this.sub,
      required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          if (isFirst)
            Container(
              width: 2,
              height: 24,
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: kRadiusFull,
              ),
            ),
        ]),
        SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(sub, style: kCaption),
                if (isFirst) SizedBox(height: 20),
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
  final Widget child;
  final VoidCallback onTap;
  const _MapBtn({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: kRadius12,
            border:
                Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: child,
        ),
      );
}