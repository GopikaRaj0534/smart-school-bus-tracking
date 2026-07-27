import 'package:flutter/material.dart';
import 'package:routesafe/utils/app_colors.dart';

class TrackingMapCard extends StatelessWidget {
  final String busNumber;
  final String routeLabel;
  final String etaLabel;

  const TrackingMapCard({
    super.key,
    required this.busNumber,
    required this.routeLabel,
    this.etaLabel = "15 min",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.directions_bus_filled_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(busNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                      Text(routeLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: AppColors.success),
                      SizedBox(width: 5),
                      Text("LIVE", style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(
                painter: _MapPainter(),
                child: const _MapOverlay(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Text("ETA", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                Text(etaLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapOverlay extends StatelessWidget {
  const _MapOverlay();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(left: 24, top: 24, child: _PointLabel(icon: Icons.school, label: "School")),
        Positioned(right: 24, bottom: 28, child: _PointLabel(icon: Icons.home, label: "Home")),
      ],
    );
  }
}

class _PointLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PointLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFEFF4FC);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.06)
      ..strokeWidth = 1;

    const gridGap = 28.0;
    for (double x = 0; x < size.width; x += gridGap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridGap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final start = Offset(size.width * 0.15, size.height * 0.28);
    final end = Offset(size.width * 0.82, size.height * 0.78);
    final control = Offset(size.width * 0.55, size.height * 0.15);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    final routePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    _drawDashedPath(canvas, path, routePaint);

    _drawDot(canvas, start, AppColors.primary);
    _drawDot(canvas, end, AppColors.success);

    final busPoint = Offset(
      start.dx + (end.dx - start.dx) * 0.6,
      control.dy + (end.dy - control.dy) * 0.55,
    );

    final busBg = Paint()..color = Colors.white;
    final busBorder = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(busPoint, 16, busBg);
    canvas.drawCircle(busPoint, 16, busBorder);

    final textPainter = TextPainter(
      text: const TextSpan(text: "🚌", style: TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(busPoint.dx - textPainter.width / 2, busPoint.dy - textPainter.height / 2),
    );
  }

  void _drawDot(Canvas canvas, Offset point, Color color) {
    canvas.drawCircle(point, 6, Paint()..color = color);
    canvas.drawCircle(point, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}