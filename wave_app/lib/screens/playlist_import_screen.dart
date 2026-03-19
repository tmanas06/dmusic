import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../widgets/track_card.dart';
import '../models/track.dart';

class PlaylistImportScreen extends StatefulWidget {
  const PlaylistImportScreen({super.key});

  @override
  State<PlaylistImportScreen> createState() => _PlaylistImportScreenState();
}

class _PlaylistImportScreenState extends State<PlaylistImportScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  List<Track> _importedTracks = [];

  Future<void> _importPlaylist() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _importedTracks = [];
    });

    try {
      final api = ApiService();
      final tracks = await api.importPlaylist(_controller.text);
      setState(() {
        _importedTracks = tracks;
        _isLoading = false;
      });

      if (tracks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tracks found in this playlist.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _downloadAll() async {
    if (_importedTracks.isEmpty) return;

    final library = context.read<LibraryProvider>();
    int count = 0;

    // Show initial snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.surface,
        duration: const Duration(seconds: 1),
        content: Text(
          'starting sequential download...',
          style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
        ),
      ),
    );

    for (var track in _importedTracks) {
      if (!library.isDownloaded(track.id) && !library.isDownloading(track.id)) {
        await library.downloadTrack(track);
        count++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accent,
          content: Text(
            count > 0 ? 'completed $count downloads' : 'all tracks already in library',
            style: GoogleFonts.dmSans(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'import playlist',
          style: GoogleFonts.syne(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YouTube Playlist Link',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Paste link here...',
                      hintStyle: GoogleFonts.dmSans(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.accent),
                        onPressed: _importPlaylist,
                      ),
                    ),
                    onSubmitted: (_) => _importPlaylist(),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            )
          else if (_importedTracks.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_importedTracks.length} tracks found',
                            style: GoogleFonts.syne(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: _downloadAll,
                              icon: const Icon(Icons.download_rounded, color: AppTheme.textMuted, size: 20),
                              label: Text(
                                'Download',
                                style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton.icon(
                              onPressed: () {
                                context.read<PlayerProvider>().playQueue(_importedTracks, 0);
                              },
                              icon: const Icon(Icons.play_arrow_rounded, color: AppTheme.accent),
                              label: Text(
                                'Play All',
                                style: GoogleFonts.dmSans(color: AppTheme.accent, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _importedTracks.length,
                      itemBuilder: (context, index) {
                        return TrackCard(
                          track: _importedTracks[index],
                          index: index,
                          onTap: () {
                            context.read<PlayerProvider>().playQueue(_importedTracks, index);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.playlist_add_rounded, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text(
                      'Search for a playlist to start listening',
                      style: GoogleFonts.dmSans(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
