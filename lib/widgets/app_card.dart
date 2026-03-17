import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// Universal card used everywhere in the app.
/// Consistent: borderRadius 16, padding 16, soft elevation, optional border.
import 'package:flutter_animate/flutter_animate.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    Widget card = Container(
      padding: widget.padding ?? AppSpacing.paddingCard,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? AppColors.card(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: widget.borderColor != null
            ? Border.all(color: widget.borderColor!, width: 1)
            : Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : Colors.black.withValues(alpha: 0.04),
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: card.animate(target: _isPressed ? 1 : 0).scaleXY(end: 0.98, duration: 100.ms),
      );
    }
    return card;
  }
}
