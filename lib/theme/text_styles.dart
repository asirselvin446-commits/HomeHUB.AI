import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Typography scale built on Google Fonts Inter.
class AppTextStyles {
  AppTextStyles._();

  // ── Headings ───────────────────────────────────────────────────────
  static TextStyle heading1(BuildContext context) => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.text(context),
        letterSpacing: -0.5,
        height: 1.2,
      );

  static TextStyle heading2(BuildContext context) => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.text(context),
        letterSpacing: -0.3,
        height: 1.25,
      );

  static TextStyle heading3(BuildContext context) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.text(context),
        height: 1.3,
      );

  // ── Body ───────────────────────────────────────────────────────────
  static TextStyle bodyLarge(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.text(context),
        height: 1.5,
      );

  static TextStyle body(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.text(context),
        height: 1.5,
      );

  static TextStyle bodySmall(BuildContext context) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary(context),
        height: 1.4,
      );

  // ── UI Labels ──────────────────────────────────────────────────────
  static TextStyle label(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.text(context),
        height: 1.3,
      );

  static TextStyle caption(BuildContext context) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary(context),
        height: 1.3,
      );

  // ── Numeric / Stats ────────────────────────────────────────────────
  static TextStyle statLarge(BuildContext context) => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.text(context),
        height: 1,
      );

  static TextStyle statMedium(BuildContext context) => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.text(context),
        height: 1.1,
      );
}
