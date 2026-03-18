import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/eq_slider.dart';
import '../widgets/frequency_curve_painter.dart';

/// Equalizer screen — 10-band EQ with presets and frequency curve visualization.
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen>
    with SingleTickerProviderStateMixin {
  // 10 bands: 31Hz, 63Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz
  List<double> bands = List.filled(10, 0.0);
  String _activePreset = 'Flat';

  static const List<String> freqLabels = [
    '31', '63', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'
  ];

  static const Map<String, List<double>> presets = {
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Bass': [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
    'Rock': [4, 3, 2, 0, -1, 1, 3, 4, 4, 3],
    'Pop': [-1, 1, 2, 3, 2, 0, -1, -1, -1, -1],
    'Hip-Hop': [5, 4, 2, 3, -1, -1, 2, 2, 3, 4],
    'Classical': [4, 3, 3, 2, -1, -1, 0, 2, 3, 4],
  };

  late AnimationController _presetAnimController;

  @override
  void initState() {
    super.initState();
    _presetAnimController = AnimationController(
      vsync: this,
      duration: AppTheme.eqPresetTween,
    );
  }

  @override
  void dispose() {
    _presetAnimController.dispose();
    super.dispose();
  }

  void _applyPreset(String name) {
    final preset = presets[name];
    if (preset == null) return;

    final startBands = List<double>.from(bands);
    final targetBands = List<double>.from(preset);

    _presetAnimController.reset();
    _presetAnimController.addListener(() {
      setState(() {
        for (int i = 0; i < 10; i++) {
          bands[i] = startBands[i] +
              (targetBands[i] - startBands[i]) * _presetAnimController.value;
        }
      });
    });
    _presetAnimController.forward();

    setState(() => _activePreset = name);
  }

  void _setBand(int index, double value) {
    setState(() {
      bands[index] = value;
      _activePreset = 'Custom';
    });
    // In a real implementation, call EqualizerFlutter.setBandLevel(index, value.toInt());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimary, size: 20),
        ),
        title: Text(
          'equalizer',
          style: GoogleFonts.syne(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Preset pills
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: presets.length + 1, // +1 for Custom
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final names = [...presets.keys, 'Custom'];
                    final name = names[index];
                    final isActive = _activePreset == name;

                    return GestureDetector(
                      onTap: () {
                        if (name != 'Custom') _applyPreset(name);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              isActive ? AppTheme.accent : AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? AppTheme.accent
                                : AppTheme.border,
                          ),
                        ),
                        child: Text(
                          name,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color:
                                isActive ? Colors.black : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Frequency curve painter
              Container(
                height: 140,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: CustomPaint(
                  size: const Size(double.infinity, 120),
                  painter: FrequencyCurvePainter(bands: bands),
                ),
              ),
              const SizedBox(height: 28),

              // dB range labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '+15 dB',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    '0 dB',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppTheme.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    '-15 dB',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 10-band sliders
              SizedBox(
                height: 190,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(10, (i) {
                    return Expanded(
                      child: EqSlider(
                        freqLabel: freqLabels[i],
                        value: bands[i],
                        onChanged: (v) => _setBand(i, v),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 32),

              // Reset button
              Center(
                child: GestureDetector(
                  onTap: () => _applyPreset('Flat'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      'reset to flat',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
