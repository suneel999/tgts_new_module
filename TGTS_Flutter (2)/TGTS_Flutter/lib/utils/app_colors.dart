import 'package:flutter/material.dart';

/// App color palette inspired by Indian flag colors
/// Reference: Telangana Congress Communication App CSS
class AppColors {
  // App Theme Colors
  /// Primary - Sky Blue (#19aaed) - Indian flag blue
  static const Color primary = Color(0xFF19aaed);
  static const Color primaryLight = Color(0xFF4DB8F0);
  static const Color primaryDark = Color(0xFF0E8BC4);
  
  /// Secondary - Green (#138808) - Keeping as is or adjusting if needed? 
  /// User only asked to change primary. But let's keep secondary as is for now unless it clashes.
  static const Color secondary = Color(0xFF138808);
  static const Color secondaryLight = Color(0xFF2E7D32);
  static const Color secondaryDark = Color(0xFF0A5C05);
  
  /// Accent - Navy (#000080)
  static const Color accent = Color(0xFF000080);
  static const Color accentLight = Color(0xFF0000B3);
  static const Color accentDark = Color(0xFF000066);
  
  // Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundGrey = Color(0xFFF5F5F5);
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF717182);
  static const Color textMuted = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFFFFFFFF);
  
  // UI Elements
  static const Color border = Color(0x1A000000); // rgba(0, 0, 0, 0.1)
  static const Color divider = Color(0xFFE0E0E0);
  static const Color inputBackground = Color(0xFFF3F3F5);
  static const Color muted = Color(0xFFECECF0);
  static const Color mutedForeground = Color(0xFF717182);
  
  // Status Colors
  static const Color success = Color(0xFF138808);
  static const Color error = Color(0xFFD4183D);
  static const Color warning = Color(0xFFFF9933); // Keep warning as orange? Or change? Usually warning is orange/yellow.
  static const Color info = Color(0xFF19aaed); // Info uses primary sky blue
  
  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF19aaed), // Sky blue
    Color(0xFF4DB8F0), // Light sky blue
    Color(0xFF0E8BC4), // Dark sky blue
  ];
  
  static const List<Color> secondaryGradient = [
    Color(0xFF138808),
    Color(0xFF2E7D32),
  ];
  
  static const List<Color> accentGradient = [
    Color(0xFF000080),
    Color(0xFF0000B3),
  ];
  
  static const List<Color> indianFlagGradient = [
    Color(0xFFFF9933), // Orange (Saffron) - Indian flag orange
    Color(0xFFFFFFFF), // White
    Color(0xFF138808), // Green - Indian flag green
  ];
  
  // Chart Colors
  static const Color chart1 = Color(0xFF19aaed); // Sky blue
  static const Color chart2 = Color(0xFF138808); // Green
  static const Color chart3 = Color(0xFF000080); // Navy
  static const Color chart4 = Color(0xFF0E8BC4); // Dark sky blue
  static const Color chart5 = Color(0xFF2E7D32); // Light green
  
  // Shadow Colors
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color shadowDark = Color(0x4D000000);
}

