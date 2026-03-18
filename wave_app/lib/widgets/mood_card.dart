import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Mood card — 130×155 card with gradient background, emoji, and title.
class MoodCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String count;
  final List<Color> gradientColors;
  final VoidCallback? onTap;

  const MoodCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.count,
    required this.gradientColors,
    this.onTap,
  });

  @override
  State<MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<MoodCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppTheme.pressScale,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 130,
          height: 155,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.moodCardRadius),
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors[0].withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Gradient overlay (transparent top → dark bottom)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppTheme.moodCardRadius),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xB3000000)],
                      stops: [0.3, 1.0],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                    const Spacer(),
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.count,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Predefined mood card data
class MoodPresets {
  static const List<Map<String, dynamic>> moods = [
    {
      'emoji': '🌙',
      'title': 'Late Night',
      'count': '24 tracks',
      'colors': [Color(0xFF2D1B69), Color(0xFF11001C)],
    },
    {
      'emoji': '🔥',
      'title': 'Energy',
      'count': '18 tracks',
      'colors': [Color(0xFF8B2500), Color(0xFF1A0500)],
    },
    {
      'emoji': '💜',
      'title': 'Chill',
      'count': '32 tracks',
      'colors': [Color(0xFF1B3A4B), Color(0xFF0A1628)],
    },
    {
      'emoji': '🌿',
      'title': 'Focus',
      'count': '15 tracks',
      'colors': [Color(0xFF1B4B2A), Color(0xFF0A1C10)],
    },
  ];
}
