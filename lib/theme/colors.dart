import 'package:flutter/material.dart';

/// Unified color palette for HomeHub AI.
/// Primary: Emerald (#059669)  Accent: Amber (#F59E0B)
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF059669);
  static const Color primaryLight  = Color(0xFF10B981);
  static const Color primaryDark   = Color(0xFF047857);
  static const Color accent        = Color(0xFFF59E0B);
  static const Color accentLight   = Color(0xFFFBBF24);

  // ── Semantic ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color info    = Color(0xFF3B82F6);

  // ── Dark theme ─────────────────────────────────────────────────────
  static const Color darkBg           = Color(0xFF0F0F14);
  static const Color darkSurface      = Color(0xFF18181B);
  static const Color darkSurfaceAlt   = Color(0xFF1E1E24);
  static const Color darkCard         = Color(0xFF1C1C22);
  static const Color darkCardAlt      = Color(0xFF252530);
  static const Color darkBorder       = Color(0xFF2A2A35);
  static const Color darkText         = Color(0xFFF4F4F5);
  static const Color darkTextSecondary= Color(0xFF9CA3AF);

  // ── Light theme ────────────────────────────────────────────────────
  static const Color lightBg           = Color(0xFFF9FAFB);
  static const Color lightSurface      = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt   = Color(0xFFF3F4F6);
  static const Color lightCard         = Color(0xFFFFFFFF);
  static const Color lightBorder       = Color(0xFFE5E7EB);
  static const Color lightText         = Color(0xFF111827);
  static const Color lightTextSecondary= Color(0xFF6B7280);

  // ── Gradients (used sparingly: hero, AI, dashboard header) ────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient aiGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Helpers ────────────────────────────────────────────────────────
  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBg : lightBg;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color surfaceAlt(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurfaceAlt : lightSurfaceAlt;

  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCard : lightCard;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorder : lightBorder;

  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkText : lightText;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
