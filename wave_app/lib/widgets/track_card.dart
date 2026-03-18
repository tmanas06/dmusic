import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';

/// Track card — 70px row with artwork, info, and download button.
class TrackCard extends StatefulWidget {
  final Track track;
  final int index;
  final VoidCallback? onTap;

  const TrackCard({
    super.key,
    required this.track,
    this.index = 0,
    this.onTap,
  });

  @override
  State<TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<TrackCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: AppTheme.pageTransition,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: AppTheme.defaultCurve),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: AppTheme.defaultCurve),
    );

    // Stagger entrance
    Future.delayed(AppTheme.staggerDelay * widget.index, () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final isDownloaded = library.isDownloaded(widget.track.id);
    final isDownloading = library.isDownloading(widget.track.id);
    final progress = library.getProgress(widget.track.id);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: widget.onTap ?? () {
            context.read<PlayerProvider>().playTrack(widget.track);
          },
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent.withValues(alpha: 0.2),
                          AppTheme.accent2.withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: widget.track.artworkUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.track.artworkUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Icon(
                              Icons.music_note_rounded,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.music_note_rounded,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                          )
                        : const Icon(
                            Icons.music_note_rounded,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Track info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.track.artist,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Duration
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    widget.track.formattedDuration,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                        ),
                  ),
                ),

                // Download button
                _buildDownloadButton(isDownloaded, isDownloading, progress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadButton(bool isDownloaded, bool isDownloading, int progress) {
    return GestureDetector(
      onTap: () {
        if (!isDownloaded && !isDownloading) {
          context.read<LibraryProvider>().downloadTrack(widget.track);
        }
      },
      child: AnimatedContainer(
        duration: AppTheme.pressScale,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          color: isDownloaded
              ? AppTheme.accent.withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: isDownloaded ? 0.5 : 0.12),
            width: 1,
          ),
        ),
        child: isDownloading
            ? Padding(
                padding: const EdgeInsets.all(5),
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
                size: 14,
                color: AppTheme.accent,
              ),
      ),
    );
  }
}
