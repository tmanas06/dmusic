import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// EQ slider — vertical slider for individual frequency band.
class EqSlider extends StatelessWidget {
  final String freqLabel;
  final double value;  // -15.0 to +15.0 dB
  final ValueChanged<double> onChanged;

  const EqSlider({
    super.key,
    required this.freqLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // dB value label
        Text(
          '${value > 0 ? '+' : ''}${value.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: value != 0 ? AppTheme.accent : AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 4),

        // Vertical slider (rotated)
        SizedBox(
          height: 120,
          width: 28,
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: AppTheme.accent,
                inactiveTrackColor: AppTheme.surface2,
                thumbColor: AppTheme.accent,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayColor: AppTheme.accent.withValues(alpha: 0.1),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 14,
                ),
              ),
              child: Slider(
                value: value,
                min: -15.0,
                max: 15.0,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Frequency label
        Text(
          freqLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 9,
                color: AppTheme.textMuted,
              ),
        ),
      ],
    );
  }
}
