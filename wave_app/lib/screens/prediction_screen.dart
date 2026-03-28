import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../services/api_service.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> with TickerProviderStateMixin {
  final List<Track> _deck = [];
  bool _isLoading = true;
  Offset _dragPosition = Offset.zero;
  double _dragAngle = 0;
  
  // Controls the 'fly away' or 'return' animation
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swipeAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(_swipeController);
    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final library = context.read<LibraryProvider>();
      final tracks = library.tracks;
      
      String query = 'Top Hits 2024';
      if (tracks.isNotEmpty) {
        final randomTrack = tracks[Random().nextInt(tracks.length)];
        query = '${randomTrack.artist} music';
      }

      final results = await ApiService().search(query);
      if (mounted) {
        setState(() {
          _deck.addAll(results.take(10));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition += details.delta;
      // Angle: card tilts as you drag it
      _dragAngle = _dragPosition.dx / 20 * (pi / 180);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.4;
    
    // Check if the velocity or position warrants a swipe
    if (_dragPosition.dx > threshold || details.velocity.pixelsPerSecond.dx > 800) {
      _animateSwipe(const Offset(600, 100), true); // Swipe Right (PLAY)
    } else if (_dragPosition.dx < -threshold || details.velocity.pixelsPerSecond.dx < -800) {
      _animateSwipe(const Offset(-600, 100), false); // Swipe Left (SKIP)
    } else {
      // Return to center with elastic effect
      _swipeController.reset();
      _swipeAnimation = Tween<Offset>(begin: _dragPosition, end: Offset.zero).animate(
        CurvedAnimation(parent: _swipeController, curve: Curves.elasticOut),
      )..addListener(() {
          setState(() {
            _dragPosition = _swipeAnimation.value;
            _dragAngle = _dragPosition.dx / 20 * (pi / 180);
          });
        });
      _swipeController.forward();
    }
  }

  void _animateSwipe(Offset target, bool isRight) {
    HapticFeedback.mediumImpact();
    _swipeController.reset();
    _swipeAnimation = Tween<Offset>(begin: _dragPosition, end: target).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.fastOutSlowIn),
    )..addListener(() {
        setState(() {
          _dragPosition = _swipeAnimation.value;
          _dragAngle = _dragPosition.dx / 20 * (pi / 180);
        });
      });
    
    _swipeController.forward().then((_) {
      if (isRight && _deck.isNotEmpty) {
        context.read<PlayerProvider>().playTrack(_deck.first);
      }
      setState(() {
        if (_deck.isNotEmpty) _deck.removeAt(0);
        _dragPosition = Offset.zero;
        _dragAngle = 0;
      });
      if (_deck.length < 3) _loadPredictions();
    });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Bluish Ambient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    const Color(0xFF003366).withValues(alpha: 0.15),
                    AppTheme.bg,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent.shade200, size: 28),
                          const SizedBox(width: 8),
                          Text('Discovery', style: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('swipe right to play • left to skip', style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                
                Expanded(
                  child: Center(
                    child: _isLoading && _deck.isEmpty
                        ? const CircularProgressIndicator(color: Colors.blueAccent)
                        : _deck.isEmpty
                            ? Text('Looking for new music...', style: GoogleFonts.dmSans(color: AppTheme.textMuted))
                            : Stack(
                                alignment: Alignment.center,
                                children: _deck.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final track = entry.value;
                                  final isTop = index == 0;
                                  
                                  return _buildCard(track, isTop);
                                }).toList().reversed.toList(),
                              ),
                  ),
                ),
                
                const SizedBox(height: 60), // Space for bottom mini player
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Track track, bool isTop) {
    final double opacity = isTop ? 1.0 : (1.0 - (0.1)).clamp(0.0, 1.0);
    final double scale = isTop ? 1.0 : 0.95;

    return KeyedSubtree(
      key: ValueKey(track.id),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: opacity,
        child: Transform.translate(
          offset: isTop ? _dragPosition : const Offset(0, 10),
          child: Transform.rotate(
            angle: isTop ? _dragAngle : 0,
            child: Transform.scale(
              scale: scale,
              child: GestureDetector(
                onPanUpdate: isTop ? _onPanUpdate : null,
                onPanEnd: isTop ? _onPanEnd : null,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.88,
                  height: MediaQuery.of(context).size.height * 0.55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: track.artworkUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: AppTheme.surface, child: const Icon(Icons.music_note, size: 64)),
                        ),
                        
                        // Gradient Overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Info Bottom
                        Positioned(
                          bottom: 32, left: 24, right: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(track.title, style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.person_rounded, size: 14, color: Colors.blueAccent.shade100),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(track.artist, style: GoogleFonts.dmSans(fontSize: 16, color: Colors.blueAccent.shade100, fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Stamps (Visual Swipe Feedback)
                        if (isTop && _dragPosition.dx.abs() > 30)
                          Positioned(
                            top: 60,
                            left: _dragPosition.dx > 0 ? 40 : null,
                            right: _dragPosition.dx < 0 ? 40 : null,
                            child: Transform.rotate(
                              angle: _dragPosition.dx > 0 ? -0.2 : 0.2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _dragPosition.dx > 0 ? Colors.blueAccent : Colors.redAccent, 
                                    width: 4
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _dragPosition.dx > 0 ? 'PLAY' : 'SKIP',
                                  style: GoogleFonts.syne(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: _dragPosition.dx > 0 ? Colors.blueAccent : Colors.redAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
