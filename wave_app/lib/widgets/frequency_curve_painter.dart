import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Frequency curve painter for the equalizer.
/// Draws grid lines, cubic spline through band points, and filled area.
class FrequencyCurvePainter extends CustomPainter {
  final List<double> bands;
  final Color curveColor;

  FrequencyCurvePainter({
    required this.bands,
    this.curveColor = AppTheme.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;

    final paint = Paint()
      ..color = curveColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          curveColor.withValues(alpha: 0.3),
          curveColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final midY = size.height / 2;

    // Draw grid lines
    _drawGrid(canvas, size, midY);

    // Generate control points
    final pts = List.generate(bands.length, (i) {
      final x = (i / (bands.length - 1)) * size.width;
      final y = midY - (bands[i] / 15) * (midY - 8);
      return Offset(x, y);
    });

    if (pts.length < 2) return;

    // Build cubic spline path
    final path = Path();
    path.moveTo(pts[0].dx, pts[0].dy);

    for (int i = 0; i < pts.length - 1; i++) {
      final cp1 = Offset(
        pts[i].dx + (pts[i + 1].dx - pts[i].dx) / 3,
        pts[i].dy,
      );
      final cp2 = Offset(
        pts[i + 1].dx - (pts[i + 1].dx - pts[i].dx) / 3,
        pts[i + 1].dy,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }

    // Draw fill
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw stroke
    canvas.drawPath(path, paint);

    // Draw dots at control points
    final dotPaint = Paint()
      ..color = curveColor
      ..style = PaintingStyle.fill;

    for (final pt in pts) {
      canvas.drawCircle(pt, 3.5, dotPaint);
      canvas.drawCircle(
        pt,
        5,
        Paint()
          ..color = curveColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawGrid(Canvas canvas, Size size, double midY) {
    final gridPaint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 0.5;

    // Horizontal grid lines at -15, -10, -5, 0, 5, 10, 15 dB
    for (final db in [-15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 15.0]) {
      final y = midY - (db / 15) * (midY - 8);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Center line (0 dB) slightly brighter
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = AppTheme.textMuted.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(FrequencyCurvePainter oldDelegate) {
    if (oldDelegate.bands.length != bands.length) return true;
    for (int i = 0; i < bands.length; i++) {
      if (oldDelegate.bands[i] != bands[i]) return true;
    }
    return false;
  }
}
