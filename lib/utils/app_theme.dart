import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// PAIRRIDE CUSTOMER — DESIGN TOKENS
/// ──────────────────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Color(0xFF0D7377);
  static const Color primaryDark = Color(0xFF095B5E);
  static const Color primaryLight = Color(0xFF16A3A7);

  // Accent
  static const Color accent = Color(0xFFF5A623);
  static const Color accentLight = Color(0xFFFFD580);

  // Surfaces
  static const Color surfaceLight = Color(0xFFF7F9FC);
  static const Color surfaceDark = Color(0xFF121820);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1C2530);

  // Gradients
  static const Color gradientStart = Color(0xFF0D7377);
  static const Color gradientEnd = Color(0xFF095040);

  static const Color darkGradientStart = Color(0xFF0B1D26);
  static const Color darkGradientEnd = Color(0xFF000000);

  // Status
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);

  // Service type colors
  static const Color singleRide = Color(0xFF0D7377);
  static const Color interstate = Color(0xFF6C5CE7);
  static const Color haulage = Color(0xFFE17055);
  static const Color dispatch = Color(0xFF00B894);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark = Color(0xFFF7F9FC);
  static const Color textOnPrimary = Colors.white;
}

class AppGradients {
  AppGradients._();

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gradientStart, AppColors.gradientEnd],
  );

  static const LinearGradient dark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.darkGradientStart, AppColors.darkGradientEnd],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accent, Color(0xFFFF8C00)],
  );

  static const LinearGradient splash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D7377), Color(0xFF053535)],
  );

  static LinearGradient serviceType(String type) {
    switch (type) {
      case 'interstate':
        return const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF4834D4)],
        );
      case 'haulage':
        return const LinearGradient(
          colors: [Color(0xFFE17055), Color(0xFFD63031)],
        );
      case 'dispatch':
        return const LinearGradient(
          colors: [Color(0xFF00B894), Color(0xFF00897B)],
        );
      default:
        return primary;
    }
  }
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Glassmorphic container decoration
BoxDecoration glassDecoration({
  Color? color,
  double borderRadius = 20,
  double opacity = 0.15,
  bool hasBorder = true,
}) {
  return BoxDecoration(
    color: (color ?? Colors.white).withOpacity(opacity),
    borderRadius: BorderRadius.circular(borderRadius),
    border: hasBorder
        ? Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          )
        : null,
  );
}

/// Service type icon data
IconData serviceTypeIcon(String type) {
  switch (type) {
    case 'interstate':
      return Icons.route;
    case 'haulage':
      return Icons.local_shipping;
    case 'dispatch':
      return Icons.inventory_2;
    default:
      return Icons.directions_car;
  }
}

/// Service type display label
String serviceTypeLabel(String type) {
  switch (type) {
    case 'interstate':
      return 'Interstate';
    case 'haulage':
      return 'Haulage';
    case 'dispatch':
      return 'Dispatch';
    default:
      return 'Single Ride';
  }
}

/// Service type color
Color serviceTypeColor(String type) {
  switch (type) {
    case 'interstate':
      return AppColors.interstate;
    case 'haulage':
      return AppColors.haulage;
    case 'dispatch':
      return AppColors.dispatch;
    default:
      return AppColors.singleRide;
  }
}

/// Category icon based on name
IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('bike')) return Icons.two_wheeler;
  if (n.contains('van')) return Icons.airport_shuttle;
  if (n.contains('truck')) return Icons.local_shipping;
  if (n.contains('flatbed')) return Icons.rv_hookup;
  if (n.contains('xl')) return Icons.directions_car;
  if (n.contains('premium')) return Icons.star;
  return Icons.directions_car;
}
