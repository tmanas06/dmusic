import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class RotaryDial extends StatefulWidget {
  final String label;
  final double value; // 0.0 to 1.0
  final ValueChanged<double> onChanged;
  final Color activeColor;

  const RotaryDial({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor = AppTheme.accent,
  });

  @override
  State<RotaryDial> createState() => _RotaryDialState();
}

class _RotaryDialState extends State<RotaryDial> {
  double _currentAngle = 0;

  @override
  void initState() {
    super.initState();
    // Map 0..1 value to -150 to 150 degrees
    _currentAngle = (widget.value * 300) - 150;
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final touchPosition = details.localPosition;
    
    // Calculate angle from center
    final angle = atan2(touchPosition.dy - center.dy, touchPosition.dx - center.dx) * 180 / pi;
    
    // Normalize and clamp angle to a 300 degree sweep (bottom gap)
    // -150 to 150 degrees
    double normalizedAngle = angle + 90;
    if (normalizedAngle > 180) normalizedAngle -= 360;
    
    if (normalizedAngle >= -150 && normalizedAngle <= 150) {
      if ((normalizedAngle - _currentAngle).abs() < 50) { // Prevent sudden jumps
        setState(() => _currentAngle = normalizedAngle);
        final newValue = (normalizedAngle + 150) / 300;
        widget.onChanged(newValue);
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.label,
          style: GoogleFonts.syne(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxWidth);
            return GestureDetector(
              onPanUpdate: (details) => _onPanUpdate(details, size),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow
                  Container(
                    width: constraints.maxWidth,
                    height: constraints.maxWidth,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.activeColor.withValues(alpha: 0.05 + (widget.value * 0.1)),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  
                  CustomPaint(
                    size: size,
                    painter: _DialPainter(
                      angle: _currentAngle,
                      activeColor: widget.activeColor,
                      value: widget.value,
                    ),
                  ),
                  
                  // Center Text
                  Text(
                    '${(widget.value * 100).toInt()}%',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  final double angle;
  final Color activeColor;
  final double value;

  _DialPainter({
    required this.angle,
    required this.activeColor,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 8.0;
    
    final bgPaint = Paint()
      ..color = AppTheme.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background Track (300 degrees)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth),
      pi * 0.75, // Start at 135 deg
      pi * 1.5,  // Sweep 270 deg
      false,
      bgPaint,
    );

    // Active Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth),
      pi * 0.75,
      pi * 1.5 * value,
      false,
      activePaint,
    );

    // Knob
    final knobPaint = Paint()
      ..color = AppTheme.surface
      ..style = PaintingStyle.fill;
      
    final knobBorderPaint = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius - 20, knobPaint);
    canvas.drawCircle(center, radius - 20, knobBorderPaint);

    // Pointer
    final pointerPaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final dragAngleRad = (angle - 90) * pi / 180;
    final p1 = Offset(
      center.dx + (radius - 35) * cos(dragAngleRad),
      center.dy + (radius - 35) * sin(dragAngleRad),
    );
    final p2 = Offset(
      center.dx + (radius - 50) * cos(dragAngleRad),
      center.dy + (radius - 50) * sin(dragAngleRad),
    );
    canvas.drawLine(p1, p2, pointerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
