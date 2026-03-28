import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../providers/navigation_provider.dart';
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
  List<Map<String, dynamic>> _moods = [];
  bool _isLoading = true;
  bool _isMoodsLoading = true;

  // Animation controllers
  late AnimationController _blobController1;
  late AnimationController _blobController2;
  late AnimationController _diceController;

  @override
  void initState() {
    super.initState();
    _blobController1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _blobController2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _loadTrendingTracks();
    _loadMoods();
  }

  Future<void> _loadMoods() async {
    try {
      final api = ApiService();
      final results = await api.getMoods();
      if (mounted) {
        setState(() {
          _moods = results;
          _isMoodsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isMoodsLoading = false);
    }
  }

  Future<void> _loadTrendingTracks() async {
    try {
      final api = ApiService();
      final results = await api.getTrending();
      if (mounted) {
        setState(() {
          _trendingTracks.clear();
          _trendingTracks.addAll(results.take(15));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shufflePlay() async {
    HapticFeedback.mediumImpact();
    _diceController.forward(from: 0);

    final lang = ui.PlatformDispatcher.instance.locale.languageCode;
    String langName = 'English'; 
    if (lang == 'hi') langName = 'Hindi';
    if (lang == 'es') langName = 'Spanish';
    if (lang == 'fr') langName = 'French';
    if (lang == 'ja') langName = 'Japanese';
    if (lang == 'ko') langName = 'Korean';
    if (lang == 'pa') langName = 'Punjabi';

    final searchQuery = 'Top Hits $langName 2024';
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎲 picking a $langName hit for you...', style: GoogleFonts.dmSans(color: Colors.black)),
        backgroundColor: AppTheme.accent,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final results = await ApiService().search(searchQuery);
      if (results.isEmpty) {
        if (_trendingTracks.isNotEmpty) {
          final random = Random();
          final index = random.nextInt(_trendingTracks.length);
          if (mounted) context.read<PlayerProvider>().playQueue(_trendingTracks, index);
        }
        return;
      }

      final random = Random();
      final index = random.nextInt(min(results.length, 10)); 
      if (mounted) {
        context.read<PlayerProvider>().playQueue(results, index);
      }
    } catch (e) {
      debugPrint('[wave] Dice search error: $e');
      if (_trendingTracks.isNotEmpty && mounted) {
        final random = Random();
        final index = random.nextInt(_trendingTracks.length);
        context.read<PlayerProvider>().playQueue(_trendingTracks, index);
      }
    }
  }

  @override
  void dispose() {
    _blobController1.dispose();
    _blobController2.dispose();
    _diceController.dispose();
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
        _buildBlob(AppTheme.accent.withValues(alpha: 0.1), 300, _blobController1, Alignment.topRight),
        _buildBlob(AppTheme.accent2.withValues(alpha: 0.08), 250, _blobController2, Alignment.bottomLeft),

        RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              _loadTrendingTracks(),
              _loadMoods(),
            ]);
          },
          color: AppTheme.accent,
          backgroundColor: AppTheme.surface,
          displacement: 20,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildStaggeredSection(0, SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('wave.', style: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                        Row(
                          children: [
                            RotationTransition(
                              turns: _diceController,
                              child: IconButton(
                                onPressed: _shufflePlay,
                                icon: const Icon(Icons.casino_rounded, color: AppTheme.accent),
                                tooltip: 'Dice Shuffle',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.surface2, border: Border.all(color: AppTheme.border)),
                              child: const Icon(Icons.person_rounded, color: AppTheme.textMuted, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
              ),

              // Greeting
              SliverToBoxAdapter(
                child: _buildStaggeredSection(1, Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getGreeting(), style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: "what's the ", style: GoogleFonts.syne(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                            TextSpan(text: "vibe", style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: AppTheme.accent)),
                            TextSpan(text: " ?", style: GoogleFonts.syne(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ),

              // Moods
              SliverToBoxAdapter(
                child: _buildStaggeredSection(3, Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('moods', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: _isMoodsLoading 
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _moods.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final mood = _moods[index];
                                final List<Color> colors = (mood['colors'] as List)
                                    .map((c) => Color(int.parse(c.toString().replaceAll('#', '0xFF'))))
                                    .toList();
                                return MoodCard(
                                  emoji: mood['emoji'] as String,
                                  title: mood['title'] as String,
                                  count: "${Random().nextInt(50) + 10}+ tracks",
                                  imageUrl: mood['image'] as String,
                                  gradientColors: colors,
                                  onTap: () => context.read<NavigationProvider>().triggerSearch(mood['title'] as String),
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                )),
              ),

              // Quick Picks
              if (!_isLoading && _trendingTracks.length >= 4)
                SliverToBoxAdapter(
                  child: _buildStaggeredSection(4, Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('quick picks', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.2,
                          ),
                          itemCount: 4,
                          itemBuilder: (context, index) {
                            final track = _trendingTracks[index];
                            return GestureDetector(
                              onTap: () => context.read<PlayerProvider>().playQueue(_trendingTracks, index),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface, 
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppTheme.surface,
                                      AppTheme.surface2.withValues(alpha: 0.4),
                                    ],
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8), 
                                      child: Image.network(
                                        track.artworkUrl, 
                                        width: 44, 
                                        height: 44, 
                                        fit: BoxFit.cover, 
                                        errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: AppTheme.surface2, child: const Icon(Icons.music_note_rounded, color: AppTheme.textMuted, size: 20)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                      Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.textMuted)),
                                    ])),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  )),
                ),

              // Trending Header
              SliverToBoxAdapter(
                child: _buildStaggeredSection(5, Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Row(
                    children: [
                      Text('trending now', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(width: 8),
                      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accent, boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.5), blurRadius: 6)])),
                    ],
                  ),
                )),
              ),

              // Trending List
              if (_isLoading)
                const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppTheme.accent))))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _trendingTracks.length) return null;
                      return _buildStaggeredSection(6 + index.clamp(0, 5), TrackCard(
                        track: _trendingTracks[index],
                        index: index,
                        onTap: () => context.read<PlayerProvider>().playQueue(_trendingTracks, index),
                      ));
                    },
                    childCount: _trendingTracks.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildBlob(Color color, double baseSize, AnimationController controller, Alignment alignment) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + 0.15 * sin(controller.value * pi * 2);
        return Align(
          alignment: alignment,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: baseSize, height: baseSize,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: 0.12), Colors.transparent])),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaggeredSection(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 150)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 30 * (1 - value)), child: child),
        );
      },
      child: child,
    );
  }
}
