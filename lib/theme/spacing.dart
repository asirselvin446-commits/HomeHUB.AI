import 'package:flutter/material.dart';

/// 8-point grid spacing system.
class AppSpacing {
  AppSpacing._();

  // ── Raw values ─────────────────────────────────────────────────────
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  // ── Border radii ───────────────────────────────────────────────────
  static const double radiusSm  = 8;
  static const double radiusMd  = 12;
  static const double radiusLg  = 16;
  static const double radiusXl  = 20;
  static const double radiusFull = 100;

  // ── Common paddings ────────────────────────────────────────────────
  static const EdgeInsets paddingPage =
      EdgeInsets.symmetric(horizontal: md, vertical: sm);

  static const EdgeInsets paddingCard =
      EdgeInsets.all(md);

  static const EdgeInsets paddingSection =
      EdgeInsets.symmetric(horizontal: md);

  static const EdgeInsets paddingListItem =
      EdgeInsets.symmetric(horizontal: md, vertical: sm);

  // ── Gaps (for SizedBox shortcuts) ──────────────────────────────────
  static const SizedBox hXs  = SizedBox(width: xs);
  static const SizedBox hSm  = SizedBox(width: sm);
  static const SizedBox hMd  = SizedBox(width: md);
  static const SizedBox hLg  = SizedBox(width: lg);

  static const SizedBox vXs  = SizedBox(height: xs);
  static const SizedBox vSm  = SizedBox(height: sm);
  static const SizedBox vMd  = SizedBox(height: md);
  static const SizedBox vLg  = SizedBox(height: lg);
  static const SizedBox vXl  = SizedBox(height: xl);
  static const SizedBox vXxl = SizedBox(height: xxl);
}
