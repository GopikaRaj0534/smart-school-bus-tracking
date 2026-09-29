import 'dart:math';
import 'package:flutter/material.dart';
import 'package:routesafe/utils/app_colors.dart';

class ChartSegmentData {
  final String label;
  final double value;
  final Color color;

  ChartSegmentData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class InteractiveDoughnutChart extends StatefulWidget {
  final List<ChartSegmentData> segments;
  final String title;
  final String centerLabel;
  final double height;

  const InteractiveDoughnutChart({
    super.key,
    required this.segments,
    this.title = '',
    this.centerLabel = '',
    this.height = 220,
  });

  @override
  State<InteractiveDoughnutChart> createState() => _InteractiveDoughnutChartState();
}

class _InteractiveDoughnutChartState extends State<InteractiveDoughnutChart>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(InteractiveDoughnutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.segments.fold<double>(0, (sum, s) => sum + s.value);
    final selectedSegment = (_selectedIndex != null && _selectedIndex! < widget.segments.length)
        ? widget.segments[_selectedIndex!]
        : null;

    final displayLabel = selectedSegment != null
        ? selectedSegment.label
        : (widget.centerLabel.isNotEmpty ? widget.centerLabel : 'Total');
    final displayValue = selectedSegment != null
        ? '${selectedSegment.value.toInt()}'
        : '${total.toInt()}';
    final percentage = (selectedSegment != null && total > 0)
        ? '(${((selectedSegment.value / total) * 100).toStringAsFixed(1)}%)'
        : '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.pie_chart_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
          ],
          if (total == 0)
            const SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'No attendance data available yet',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: widget.height,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return GestureDetector(
                          onTapUp: (details) {
                            final box = context.findRenderObject() as RenderBox?;
                            if (box == null) return;
                            final localTouch = details.localPosition;
                            final center = Offset(box.size.width / 2, box.size.height / 2);
                            final dx = localTouch.dx - center.dx;
                            final dy = localTouch.dy - center.dy;
                            var touchAngle = atan2(dy, dx);
                            if (touchAngle < -pi / 2) {
                              touchAngle += 2 * pi;
                            }

                            double startAngle = -pi / 2;
                            for (int i = 0; i < widget.segments.length; i++) {
                              final sweep = (widget.segments[i].value / total) * 2 * pi;
                              if (touchAngle >= startAngle && touchAngle <= startAngle + sweep) {
                                setState(() {
                                  _selectedIndex = (_selectedIndex == i) ? null : i;
                                });
                                break;
                              }
                              startAngle += sweep;
                            }
                          },
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _DoughnutChartPainter(
                              segments: widget.segments,
                              total: total,
                              progress: _animation.value,
                              selectedIndex: _selectedIndex,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    displayValue,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  Text(
                                    displayLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (percentage.isNotEmpty)
                                    Text(
                                      percentage,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accentYellow,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.segments.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final segment = entry.value;
                        final isSelected = idx == _selectedIndex;
                        final pct = total > 0 ? (segment.value / total * 100).toStringAsFixed(0) : '0';

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedIndex = (isSelected ? null : idx);
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? segment.color.withOpacityCompat(0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? segment.color : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: segment.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    segment.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${segment.value.toInt()} ($pct%)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: segment.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DoughnutChartPainter extends CustomPainter {
  final List<ChartSegmentData> segments;
  final double total;
  final double progress;
  final int? selectedIndex;

  _DoughnutChartPainter({
    required this.segments,
    required this.total,
    required this.progress,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;
    const strokeWidth = 24.0;

    var startAngle = -pi / 2;

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final sweepAngle = (seg.value / total) * 2 * pi * progress;
      final isSelected = i == selectedIndex;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 6 : strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = isSelected ? seg.color : seg.color.withOpacityCompat(0.9);

      final curRadius = isSelected ? radius + 2 : radius;
      final rect = Rect.fromCircle(center: center, radius: curRadius);

      canvas.drawArc(rect, startAngle, sweepAngle - 0.04, false, paint);
      startAngle += (seg.value / total) * 2 * pi * progress;
    }
  }

  @override
  bool shouldRepaint(covariant _DoughnutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.segments != segments;
  }
}
