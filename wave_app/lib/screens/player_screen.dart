import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import 'equalizer_screen.dart';

/// Full player screen — opens as modal bottom sheet.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: AppTheme.albumRotation,
    );

    // Start rotation if currently playing
    final player = context.read<PlayerProvider>();
    if (player.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final track = player.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    // Manage rotation animation
    if (player.isPlaying) {
      if (!_rotationController.isAnimating) _rotationController.repeat();
    } else {
      if (_rotationController.isAnimating) _rotationController.stop();
    }

    final isDownloaded = library.isDownloaded(track.id);
    final isDownloading = library.isDownloading(track.id);
    final progress = library.getProgress(track.id);

    final screenHeight = MediaQuery.of(context).size.height;
    final artworkSize = (screenHeight * 0.35).clamp(200.0, 280.0);

    return Container(
      height: screenHeight * 0.92,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // Mesmerizing Background (Blurred Artwork)
          Positioned.fill(
            child: Opacity(
              opacity: 0.45,
              child: track.artworkUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: track.artworkUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.bg.withOpacity(0.4),
                      AppTheme.bg.withOpacity(0.8),
                      AppTheme.bg,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Player Content
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),

                // Close / minimize
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 28, color: AppTheme.textMuted),
                      ),
                      Text(
                        'now playing',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.more_vert_rounded,
                            size: 22, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Album artwork with rotation and pulse
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    final pulse = 1.0 + 0.03 * sin(_rotationController.value * 2 * pi * 4);
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * pi,
                      child: Transform.scale(
                        scale: pulse,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: artworkSize,
                    height: artworkSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.artworkRadius),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.2),
                          blurRadius: 50,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.artworkRadius),
                      child: track.artworkUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: track.artworkUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppTheme.surface2,
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accent.withOpacity(0.2),
                                      AppTheme.accent2.withOpacity(0.2),
                                    ],
                                  ),
                                ),
                                child: const Icon(Icons.music_note_rounded,
                                    color: AppTheme.textMuted, size: 64),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.accent.withOpacity(0.2),
                                    AppTheme.accent2.withOpacity(0.2),
                                  ],
                                ),
                              ),
                              child: const Icon(Icons.music_note_rounded,
                                  color: AppTheme.textMuted, size: 64),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Track info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        track.title,
                        style: GoogleFonts.syne(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        track.artist,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Seek bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: StreamBuilder<Duration>(
                    stream: player.audioService.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = player.audioService.duration;
                      final maxDuration =
                          duration.inMilliseconds > 0 ? duration : const Duration(seconds: 1);

                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              activeTrackColor: AppTheme.accent,
                              inactiveTrackColor: AppTheme.surface2.withOpacity(0.5),
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayColor: AppTheme.accent.withOpacity(0.1),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16,
                              ),
                            ),
                            child: Slider(
                              value: position.inMilliseconds
                                  .clamp(0, maxDuration.inMilliseconds)
                                  .toDouble(),
                              max: maxDuration.inMilliseconds.toDouble(),
                              onChanged: (value) {
                                player
                                    .seek(Duration(milliseconds: value.toInt()));
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Main controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => player.toggleShuffle(),
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: player.isShuffleEnabled
                            ? AppTheme.accent
                            : AppTheme.textMuted,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => player.skipPrevious(),
                      icon: const Icon(Icons.skip_previous_rounded,
                          color: AppTheme.textPrimary, size: 42),
                    ),
                    const SizedBox(width: 16),

                    // Big play/pause / loader button
                    GestureDetector(
                      onTap: () => player.togglePlayPause(),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withOpacity(0.4),
                              blurRadius: 25,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: player.isBuffering
                          ? const Padding(
                              padding: EdgeInsets.all(22),
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 3,
                              ),
                            )
                          : Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 40,
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    IconButton(
                      onPressed: () => player.skipNext(),
                      icon: const Icon(Icons.skip_next_rounded,
                          color: AppTheme.textPrimary, size: 42),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => player.toggleRepeat(),
                      icon: Icon(
                        Icons.repeat_rounded,
                        color: player.isRepeatEnabled
                            ? AppTheme.accent
                            : AppTheme.textMuted,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Secondary controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Download button
                      _buildDownloadButton(
                          isDownloaded, isDownloading, progress, track, library),
                      // Like
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.favorite_border_rounded,
                            color: AppTheme.textMuted, size: 24),
                      ),
                      // Share
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.share_rounded,
                            color: AppTheme.textMuted, size: 24),
                      ),
                      // EQ shortcut
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EqualizerScreen()),
                          );
                        },
                        icon: const Icon(Icons.equalizer_rounded,
                            color: AppTheme.textMuted, size: 24),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(
    bool isDownloaded,
    bool isDownloading,
    int progress,
    dynamic track,
    LibraryProvider library,
  ) {
    return GestureDetector(
      onTap: () {
        if (!isDownloaded && !isDownloading) {
          library.downloadTrack(track);
        }
      },
      child: AnimatedContainer(
        duration: AppTheme.pressScale,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDownloaded
              ? AppTheme.accent.withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
            color: isDownloaded ? AppTheme.accent : AppTheme.textMuted,
            width: 1.5,
          ),
        ),
        child: isDownloading
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress / 100 : null,
                  strokeWidth: 2,
                  color: AppTheme.accent,
                ),
              )
            : Icon(
                isDownloaded
                    ? Icons.check_rounded
                    : Icons.arrow_downward_rounded,
                size: 20,
                color: isDownloaded ? AppTheme.accent : AppTheme.textMuted,
              ),
      ),
    );
  }
}
