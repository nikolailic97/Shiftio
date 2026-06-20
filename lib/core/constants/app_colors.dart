import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── PRIMARY ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2A6FDB);
  static const Color primaryLight = Color(0xFF5B93E8);
  static const Color primaryDark = Color(0xFF1A4FA8);

  // ─── LIGHT MODE ─────────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF4F6FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0D1B2A);
  static const Color textSecondaryLight = Color(0xFF6B7A8D);
  static const Color dividerLight = Color(0xFFE8ECF2);
  static const Color inputFillLight = Color(0xFFF0F3F9);

  // ─── DARK MODE ──────────────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF12121C);
  static const Color surfaceDark = Color(0xFF1E1E2E);
  static const Color cardDark = Color(0xFF252538);
  static const Color textPrimaryDark = Color(0xFFF0F4FF);
  static const Color textSecondaryDark = Color(0xFF8892A4);
  static const Color dividerDark = Color(0xFF2E2E45);
  static const Color inputFillDark = Color(0xFF2A2A3E);

  // ─── STATUS COLORS ──────────────────────────────────────────────────────────
  static const Color success = Color(0xFF34C759);
  static const Color successLight = Color(0xFFE8F8ED);
  static const Color error = Color(0xFFFF3B30);
  static const Color errorLight = Color(0xFFFFECEB);
  static const Color warning = Color(0xFFFF9500);
  static const Color warningLight = Color(0xFFFFF4E5);
  static const Color info = Color(0xFF0A84FF);
  static const Color infoLight = Color(0xFFE5F2FF);

  // ─── ROLE COLORS ────────────────────────────────────────────────────────────
  static const Color adminColor = Color(0xFF5856D6);
  static const Color managerColor = Color(0xFF2A6FDB);
  static const Color workerColor = Color(0xFF34C759);

  // ─── AVATAR COLORS (za inicijale) ───────────────────────────────────────────
  static const List<Color> avatarColors = [
    Color(0xFF2A6FDB),
    Color(0xFF5856D6),
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFBE0B),
    Color(0xFF8338EC),
    Color(0xFFFF006E),
    Color(0xFF3A86FF),
  ];
}
