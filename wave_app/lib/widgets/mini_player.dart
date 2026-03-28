import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import 'waveform_bars.dart';

/// Mini player — fixed at bottom above navigation bar.
/// Shows current track with controls and animated waveform.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    if (!player.hasTrack) return const SizedBox.shrink();

    final track = player.currentTrack!;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const PlayerScreen(),
        );
      },
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                // Left accent bar
                Container(
                  width: 3,
                  height: 72,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      colors: [AppTheme.accent, AppTheme.accent2],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: track.artworkUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: track.artworkUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: AppTheme.surface2,
                              child: const Icon(Icons.music_note_rounded,
                                  color: AppTheme.textMuted, size: 20),
                            ),
                          )
                        : Container(
                            color: AppTheme.surface2,
                            child: const Icon(Icons.music_note_rounded,
                                color: AppTheme.textMuted, size: 20),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Track info + waveform
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          WaveformBars(
                            isPlaying: player.isPlaying,
                            height: 10,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'now playing',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Controls
                IconButton(
                  onPressed: () => player.skipPrevious(),
                  icon: const Icon(Icons.skip_previous_rounded),
                  iconSize: 22,
                  color: AppTheme.textPrimary,
                ),
                GestureDetector(
                  onTap: () => player.togglePlayPause(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accent,
                    ),
                    child: Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => player.skipNext(),
                  icon: const Icon(Icons.skip_next_rounded),
                  iconSize: 22,
                  color: AppTheme.textPrimary,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
