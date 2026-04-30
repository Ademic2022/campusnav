import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette — deep navy dark theme
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceElevated = Color(0xFF1C2537);
  static const Color surfaceHigh = Color(0xFF243044);

  // Accent — OAU green + amber
  static const Color primary = Color(0xFF22C55E);      // vibrant green
  static const Color primaryDark = Color(0xFF16A34A);
  static const Color accent = Color(0xFFF59E0B);       // amber
  static const Color accentLight = Color(0xFFFBBF24);

  // Route colors
  static const Color routeWalking = Color(0xFF38BDF8);   // sky blue
  static const Color routeDriving = Color(0xFFF97316);   // orange

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF475569);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Borders / dividers
  static const Color border = Color(0xFF1E293B);
  static const Color divider = Color(0xFF1E293B);

  // Category colors
  static const Color catHostel = Color(0xFF8B5CF6);
  static const Color catFaculty = Color(0xFF3B82F6);
  static const Color catAdmin = Color(0xFF06B6D4);
  static const Color catFood = Color(0xFFF97316);
  static const Color catBank = Color(0xFF22C55E);
  static const Color catHealth = Color(0xFFEF4444);
  static const Color catGate = Color(0xFF94A3B8);
  static const Color catSports = Color(0xFFFBBF24);
  static const Color catLecture = Color(0xFF6366F1);
  static const Color catDepartment = Color(0xFF14B8A6);

  static Color categoryColor(String category) {
    switch (category) {
      case 'hostel': return catHostel;
      case 'faculty': return catFaculty;
      case 'admin': return catAdmin;
      case 'food': return catFood;
      case 'banks': return catBank;
      case 'health': return catHealth;
      case 'gate': return catGate;
      case 'sports': return catSports;
      case 'lecture': return catLecture;
      case 'department': return catDepartment;
      default: return textSecondary;
    }
  }
}
