import 'dart:math';
import 'package:flutter/material.dart';
import 'package:routesafe/utils/app_colors.dart';

class BarChartItemData {
  final String label;
  final double value;
  final Color color;

  BarChartItemData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class InteractiveBarChart extends StatefulWidget {
  final List<BarChartItemData> items;
  final String title;
  final double height;

  const InteractiveBarChart({
    super.key,
    required this.items,
    this.title = '',
    this.height = 220,
  });

  @override
  State<InteractiveBarChart> createState() => _InteractiveBarChartState();
}

class _InteractiveBarChartState extends State<InteractiveBarChart>
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
  void didUpdateWidget(InteractiveBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
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
    final maxValue = widget.items.fold<double>(1, (maxVal, item) => max(maxVal, item.value));
    final selectedItem = (_selectedIndex != null && _selectedIndex! < widget.items.length)
        ? widget.items[_selectedIndex!]
        : null;

    final maxBarAreaHeight = max(100.0, widget.height - 60.0);

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
                const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 22),
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
          if (widget.items.isEmpty)
            const SizedBox(
              height: 180,
              child: Center(
                child: Text('No metrics available', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else ...[
            SizedBox(
              height: widget.height,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: widget.items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final isSelected = idx == _selectedIndex;
                      final heightRatio = maxValue > 0 ? (item.value / maxValue) * _animation.value : 0.0;
                      final calculatedBarHeight = max(6.0, maxBarAreaHeight * heightRatio);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedIndex = (isSelected ? null : idx);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${item.value.toInt()}',
                                  style: TextStyle(
                                    fontSize: isSelected ? 13 : 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? item.color : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: maxBarAreaHeight,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      height: calculatedBarHeight,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: isSelected ? item.color : item.color.withOpacityCompat(0.85),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: item.color.withOpacityCompat(0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, -2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            if (selectedItem != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selectedItem.color.withOpacityCompat(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selectedItem.color.withOpacityCompat(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: selectedItem.color, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${selectedItem.label}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${selectedItem.value.toInt()} registered / active records',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selectedItem.color),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
