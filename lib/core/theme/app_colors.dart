import 'package:flutter/material.dart';

class AppColors {
  // --- Dark Palette (Figma Reference) ---
  static const Color darkBg = Color(0xFF070B14);
  static const Color darkSidebar = Color(0xFF090E19);
  static const Color darkSurface = Color(0xFF0D1320);
  static const Color darkSurface2 = Color(0xFF121A29);
  static const Color darkSurface3 = Color(0xFF172133);
  static const Color darkBorder = Color(0x1FA8BCE6); // rgba(168, 188, 230, 0.12)
  static const Color darkBorderBright = Color(0x387F9AD6); // rgba(127, 154, 214, 0.22)
  static const Color darkText = Color(0xFFF3F6FD);
  static const Color darkMuted = Color(0xFF8C98AD);
  static const Color darkMuted2 = Color(0xFF657188);

  // --- Light Palette ---
  static const Color lightBg = Color(0xFFF4F6FA);
  static const Color lightSidebar = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF6F8FC);
  static const Color lightSurface3 = Color(0xFFEEF2F8);
  static const Color lightBorder = Color(0x1C1F2D4C); // rgba(31, 45, 76, 0.11)
  static const Color lightBorderBright = Color(0x3642578C); // rgba(66, 87, 140, 0.21)
  static const Color lightText = Color(0xFF121827);
  static const Color lightMuted = Color(0xFF68758A);
  static const Color lightMuted2 = Color(0xFF8792A5);

  // --- Brand & Semantic Accents ---
  static const Color primary = Color(0xFF6E62EE);
  static const Color primaryBright = Color(0xFF8A7FFF);
  static const Color cyan = Color(0xFF22CFE5);
  static const Color amber = Color(0xFFF3A442);
  static const Color green = Color(0xFF50D39A);
  static const Color red = Color(0xFFF26D78);
  static const Color blue = Color(0xFF477DE7);

  // --- Gradients ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6E62EE), Color(0xFF22CFE5)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient titleGradient = LinearGradient(
    colors: [Color(0xFF9E93FF), Color(0xFF5FCBF7)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient violetMarkGradient = LinearGradient(
    colors: [Color(0xFF806FE9), Color(0xFF4E43A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanMarkGradient = LinearGradient(
    colors: [Color(0xFF2BC5D9), Color(0xFF3072A4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberMarkGradient = LinearGradient(
    colors: [Color(0xFFEDAA55), Color(0xFFA25F2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
