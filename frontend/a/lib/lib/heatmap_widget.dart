import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';

// ── Heatmap preview card (used on home page) ──────────────────────────────────
class HeatmapPreviewCard extends StatelessWidget {
  final VoidCallback? onTap;
  const HeatmapPreviewCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _openHeatmap(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: 160,
        decoration: BoxDecoration(
          borderRadius: kRadius16,
          boxShadow: kCardShadow,
        ),
        child: ClipRRect(
          borderRadius: kRadius16,
          child: Stack(
            children: [
              // Background map texture
              const _MockMapBackground(),
              // Heatmap dots
              const _HeatmapDots(),
              // Dark gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
              ),
              // Text overlay
              Positioned(
                left: 16, bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kGreenAccent,
                            borderRadius: kRadiusFull,
                          ),
                          child: const Text('LIVE',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                        ),
                        const SizedBox(width: 8),
                        const Text('Toplotna karta hrane',
                            style: TextStyle(
                                color: Colors.white, fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('23 aktivnih oglasov v Mariboru',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11)),
                  ],
                ),
              ),
              // Arrow
              Positioned(
                right: 14, bottom: 14,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: kRadiusFull,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.open_in_full,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openHeatmap(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const HeatmapFullPage()));
  }
}

// ── Mock map grid background ──────────────────────────────────────────────────
class _MockMapBackground extends StatelessWidget {
  const _MockMapBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapGridPainter(),
      child: Container(color: const Color(0xFF1A3A2A)),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A4A3A)
      ..strokeWidth = 1;

    // Horizontal streets
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical streets
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Roads (thicker)
    final roadPaint = Paint()
      ..color = const Color(0xFF3A5A4A)
      ..strokeWidth = 3;
    canvas.drawLine(
        Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.45),
        roadPaint);
    canvas.drawLine(
        Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height),
        roadPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Heatmap animated dots ─────────────────────────────────────────────────────
class _HeatmapDots extends StatefulWidget {
  const _HeatmapDots();
  @override
  State<_HeatmapDots> createState() => _HeatmapDotsState();
}

class _HeatmapDotsState extends State<_HeatmapDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  // Pre-defined hotspot positions (relative 0-1)
  static const _hotspots = [
    (0.2, 0.35, 3.0),
    (0.45, 0.25, 2.0),
    (0.6, 0.55, 4.0),
    (0.75, 0.3, 2.5),
    (0.3, 0.65, 1.5),
    (0.85, 0.7, 3.0),
    (0.15, 0.7, 2.0),
    (0.55, 0.75, 1.5),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return CustomPaint(
          painter: _HeatmapPainter(_hotspots, _pulse.value),
          child: Container(color: Colors.transparent),
        );
      },
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<(double, double, double)> hotspots;
  final double pulse;
  _HeatmapPainter(this.hotspots, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    for (final (rx, ry, intensity) in hotspots) {
      final cx = rx * size.width;
      final cy = ry * size.height;
      final baseR = intensity * 14.0 * pulse;

      // Glow layers
      for (int i = 3; i >= 0; i--) {
        final radius = baseR * (1 + i * 0.5);
        final opacity = 0.06 * (4 - i) * pulse;
        final grad = RadialGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(opacity + 0.05),
            Colors.transparent,
          ],
        );
        final paint = Paint()
          ..shader = grad.createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: radius));
        canvas.drawCircle(Offset(cx, cy), radius, paint);
      }

      // Core dot
      canvas.drawCircle(
        Offset(cx, cy),
        3.5,
        Paint()..color = kGreenAccent.withOpacity(0.9 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.pulse != pulse;
}

// ── Full heatmap screen ───────────────────────────────────────────────────────
class HeatmapFullPage extends StatefulWidget {
  const HeatmapFullPage({super.key});
  @override
  State<HeatmapFullPage> createState() => _HeatmapFullPageState();
}

class _HeatmapFullPageState extends State<HeatmapFullPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  static const _fullHotspots = [
    (0.2, 0.35, 3.5),
    (0.45, 0.25, 2.5),
    (0.6, 0.55, 5.0),
    (0.75, 0.3, 3.0),
    (0.3, 0.65, 2.0),
    (0.85, 0.7, 3.5),
    (0.15, 0.7, 2.5),
    (0.55, 0.75, 2.0),
    (0.4, 0.45, 4.0),
    (0.7, 0.15, 2.0),
    (0.25, 0.15, 1.5),
    (0.9, 0.4, 2.5),
    (0.1, 0.5, 3.0),
    (0.65, 0.85, 2.0),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A2A),
      body: Stack(
        children: [
          // Full screen animated map
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => CustomPaint(
                painter: _FullMapPainter(_fullHotspots, _pulse.value),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: kRadius12,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Toplotna karta',
                      style: TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kGreenAccent.withOpacity(0.9),
                      borderRadius: kRadiusFull,
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 4),
                        Text('23 aktivnih',
                            style: TextStyle(color: Colors.white,
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom legend card
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: kBorder, borderRadius: kRadiusFull,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Razporeditev hrane',
                          style: kHeading3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kGreenPale, borderRadius: kRadiusFull,
                        ),
                        child: const Text('Maribor',
                            style: TextStyle(color: kGreenMid, fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _LegendDot(color: kGreenAccent, label: 'Visoka gostota'),
                      const SizedBox(width: 16),
                      _LegendDot(
                          color: kGreenLight.withOpacity(0.6),
                          label: 'Srednja gostota'),
                      const SizedBox(width: 16),
                      _LegendDot(
                          color: kGreenLight.withOpacity(0.25),
                          label: 'Nizka gostota'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('Pokaži bližnje oglase'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kGreenMid,
                        side: const BorderSide(color: kGreenMid),
                        shape: const RoundedRectangleBorder(
                            borderRadius: kRadius12),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: kCaption),
      ],
    );
  }
}

class _FullMapPainter extends CustomPainter {
  final List<(double, double, double)> hotspots;
  final double pulse;
  _FullMapPainter(this.hotspots, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF2A4A3A)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Roads
    final roadPaint = Paint()
      ..color = const Color(0xFF3A5A4A)
      ..strokeWidth = 5;
    canvas.drawLine(
        Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.45),
        roadPaint);
    canvas.drawLine(
        Offset(size.width * 0.35, 0),
        Offset(size.width * 0.35, size.height), roadPaint);
    canvas.drawLine(
        Offset(size.width * 0.65, 0),
        Offset(size.width * 0.65, size.height), roadPaint);

    // Hotspots
    for (final (rx, ry, intensity) in hotspots) {
      final cx = rx * size.width;
      final cy = ry * size.height;
      final baseR = intensity * 22.0 * pulse;

      for (int i = 4; i >= 0; i--) {
        final radius = baseR * (1 + i * 0.45);
        final opacity = 0.05 * (5 - i) * pulse;
        final grad = RadialGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(opacity + 0.04),
            Colors.transparent,
          ],
        );
        final paint = Paint()
          ..shader = grad.createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: radius));
        canvas.drawCircle(Offset(cx, cy), radius, paint);
      }
      canvas.drawCircle(
        Offset(cx, cy), 4.5,
        Paint()..color = kGreenAccent.withOpacity(0.95 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(_FullMapPainter old) => old.pulse != pulse;
}
