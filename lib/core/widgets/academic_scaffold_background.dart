import 'package:flutter/material.dart';

class AcademicScaffoldBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AcademicScaffoldBackground({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF020817),
                  Color(0xFF0F172A),
                  Color(0xFF111827),
                ]
              : const [
                  Color(0xFFF8FAFD),
                  Color(0xFFF1F5F9),
                  Color(0xFFEEF2F6),
                ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF6366F1).withValues(alpha: 0.22)
                    : const Color(0xFF6366F1).withValues(alpha: 0.06),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                        : const Color(0xFF6366F1).withValues(alpha: 0.08),
                    blurRadius: 90,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: -90,
            bottom: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.18)
                    : const Color(0xFF3B82F6).withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.18)
                        : const Color(0xFF3B82F6).withValues(alpha: 0.06),
                    blurRadius: 90,
                    spreadRadius: 18,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AmbientGridPainter(isDark: isDark),
              ),
            ),
          ),
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AmbientGridPainter extends CustomPainter {
  final bool isDark;

  const _AmbientGridPainter({this.isDark = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.035)
          : const Color(0xFF64748B).withValues(alpha: 0.03)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientGridPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
