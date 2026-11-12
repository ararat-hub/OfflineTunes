import 'package:flutter/material.dart';

abstract class AppColors {
  // Основные акценты
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF4B43E0);
  static const Color accent = Color(0xFF00E5FF);

  // Фон и подложки
  static const Color background = Color(0xFF101014);
  static const Color cardBg = Color(0x1F22222E);
  static const Color glassBorder = Color(0x33FFFFFF);

  // Текст
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0x99FFFFFF);
  static const Color textMuted = Color(0x66FFFFFF);

  // Статусы
  static const Color offline = Color(0xFFFF4B4B);
  static const Color success = Color(0xFF00E676);
}
