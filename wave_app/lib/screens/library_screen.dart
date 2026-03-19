import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';

/// Library screen — shows downloaded tracks with filter chips.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _filter = 'All';
  final List<String> _filters = ['All', 'Recent', 'A-Z', 'Artist'];

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final tracks = _getFilteredTracks(library.tracks);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'library',
                  style: GoogleFonts.syne(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${tracks.length} tracks',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filter pills
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isActive = _filter == filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.accent : AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.accent
                            : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isActive ? Colors.black : AppTheme.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Track grid / list
          Expanded(
            child: tracks.isEmpty
                ? _buildEmptyLibrary()
                : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.76,
                    ),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      return _buildGridItem(context, tracks[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<Track> _getFilteredTracks(List<Track> tracks) {
    switch (_filter) {
      case 'Recent':
        return List.from(tracks)
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case 'A-Z':
        return List.from(tracks)
          ..sort((a, b) => a.title.compareTo(b.title));
      case 'Artist':
        return List.from(tracks)
          ..sort((a, b) => a.artist.compareTo(b.artist));
      default:
        return tracks;
    }
  }

  Widget _buildGridItem(BuildContext context, Track track) {
    return GestureDetector(
      onTap: () {
        context.read<PlayerProvider>().playTrack(track);
      },
      onLongPress: () => _showTrackOptions(context, track),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Artwork
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.1),
                      AppTheme.accent2.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: track.artworkUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: track.artworkUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.music_note_rounded,
                              color: AppTheme.textMuted, size: 32),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.music_note_rounded,
                            color: AppTheme.textMuted, size: 32),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            track.title,
            style: GoogleFonts.syne(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            track.artist,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLibrary() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music_rounded,
            size: 64,
            color: AppTheme.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'your library is empty',
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'search and download tracks\nto build your collection',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _showTrackOptions(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      track.title,
                      style: GoogleFonts.syne(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artist,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded,
                    color: AppTheme.textPrimary),
                title: Text('Play',
                    style: GoogleFonts.dmSans(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  context.read<PlayerProvider>().playTrack(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.accent2),
                title: Text('Delete',
                    style: GoogleFonts.dmSans(color: AppTheme.accent2)),
                onTap: () {
                  Navigator.pop(context);
                  context.read<LibraryProvider>().deleteTrack(track.id);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
