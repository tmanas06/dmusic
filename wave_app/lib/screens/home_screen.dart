import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../widgets/mood_card.dart';
import '../widgets/track_card.dart';

/// Home screen — main landing with greeting, mood cards, and trending tracks.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<Track> _trendingTracks = [];
  bool _isLoading = true;

  // Blob animation controllers
  late AnimationController _blobController1;
  late AnimationController _blobController2;

  @override
  void initState() {
    super.initState();
    _blobController1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _blobController2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _loadTrendingTracks();
  }

  Future<void> _loadTrendingTracks() async {
    try {
      final api = ApiService();
      final results = await api.search('trending hits 2024');
      setState(() {
        _trendingTracks.addAll(results.take(10));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _blobController1.dispose();
    _blobController2.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'good morning ☀️';
    if (h < 18) return 'good afternoon 〰';
    return 'good evening ✦';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Ambient background blobs
        _buildBlob(
          AppTheme.accent.withValues(alpha: 0.08),
          200,
          _blobController1,
          Alignment.topRight,
        ),
        _buildBlob(
          AppTheme.accent2.withValues(alpha: 0.06),
          180,
          _blobController2,
          Alignment.bottomLeft,
        ),

        // Main content
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'wave.',
                        style: GoogleFonts.syne(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent,
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surface2,
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppTheme.textMuted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Greeting
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "what's the ",
                            style: GoogleFonts.syne(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: "vibe",
                            style: GoogleFonts.dmSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w300,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.accent,
                            ),
                          ),
                          TextSpan(
                            text: " ?",
                            style: GoogleFonts.syne(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Mood cards section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'moods',
                        style: GoogleFonts.syne(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 155,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: MoodPresets.moods.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final mood = MoodPresets.moods[index];
                          return MoodCard(
                            emoji: mood['emoji'] as String,
                            title: mood['title'] as String,
                            count: mood['count'] as String,
                            gradientColors: mood['colors'] as List<Color>,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Trending section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'trending now',
                      style: GoogleFonts.syne(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Live pulse dot
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Trending tracks list
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= _trendingTracks.length) return null;
                    return TrackCard(
                      track: _trendingTracks[index],
                      index: index,
                      onTap: () {
                        context.read<PlayerProvider>().playQueue(
                              _trendingTracks,
                              index,
                            );
                      },
                    );
                  },
                  childCount: _trendingTracks.length,
                ),
              ),

            // Bottom padding for mini player
            const SliverToBoxAdapter(
              child: SizedBox(height: 160),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlob(
    Color color,
    double baseSize,
    AnimationController controller,
    Alignment alignment,
  ) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + 0.05 * sin(controller.value * pi * 2);
        return Align(
          alignment: alignment,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: baseSize,
              height: baseSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color, Colors.transparent],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
