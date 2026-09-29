import 'package:flutter/material.dart';
import 'package:routesafe/utils/app_colors.dart';

class RouteSafeLogo extends StatelessWidget {
  final double fontSize;
  final bool isDarkBackground;
  final bool showIcon;
  final double iconSize;

  const RouteSafeLogo({
    super.key,
    this.fontSize = 26,
    this.isDarkBackground = true,
    this.showIcon = true,
    this.iconSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    final routeColor = isDarkBackground ? Colors.white : AppColors.textPrimary;
    const safeColor = AppColors.accentYellow;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showIcon) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkBackground
                  ? Colors.white.withOpacityCompat(0.18)
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.directions_bus_filled_rounded,
              color: isDarkBackground ? AppColors.accentYellow : AppColors.primary,
              size: iconSize,
            ),
          ),
          const SizedBox(width: 10),
        ],
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "Route",
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: routeColor,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: "Safe",
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: safeColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
