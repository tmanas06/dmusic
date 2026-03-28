import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../widgets/track_card.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  bool _isBatchDownloading = false;
  bool _stopBatchRequested = false;
  List<Map<String, dynamic>> _pastSearches = [];
  Box<Map>? _historyBox;

  @override
  void initState() {
    super.initState();
    _initHistory();
  }

  Future<void> _initHistory() async {
    _historyBox = await Hive.openBox<Map>('playlist_history_v2');
    if (mounted) {
      setState(() {
        _pastSearches = _historyBox!.values.map((e) => Map<String, dynamic>.from(e)).toList().reversed.toList();
      });
    }
  }

  void _saveSearch(String url, List<Track> tracks) {
    if (url.isEmpty || _historyBox == null || tracks.isEmpty) return;
    
    final String title = "Playlist"; // Default
    final String imageUrl = tracks.first.artworkUrl;

    final Map<String, dynamic> entry = {
      'url': url,
      'title': title,
      'imageUrl': imageUrl,
      'trackCount': tracks.length,
    };

    // Remove if already exists with same url
    _pastSearches.removeWhere((element) => element['url'] == url);
    
    _pastSearches.insert(0, entry);
    
    if (_pastSearches.length > 10) {
      _pastSearches = _pastSearches.sublist(0, 10);
    }

    _historyBox!.clear();
    for (var i = _pastSearches.length - 1; i >= 0; i--) {
      _historyBox!.add(_pastSearches[i]);
    }

    setState(() {});
  }

  void _clearHistory() {
    _historyBox?.clear();
    setState(() {
      _pastSearches = [];
    });
  }

  Widget _buildRecentSearches() {
    if (_pastSearches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: _clearHistory,
                child: Text(
                  'clear',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _pastSearches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final entry = _pastSearches[index];
              final url = entry['url'] as String;
              final title = entry['title'] as String;
              final imageUrl = entry['imageUrl'] as String;
              final trackCount = entry['trackCount'] as int? ?? 0;
              
              return GestureDetector(
                onTap: () {
                  _controller.text = url;
                  _importPlaylist();
                },
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Stack(
                            children: [
                              Image.network(
                                imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.surface2,
                                  child: const Icon(Icons.music_note_rounded, color: AppTheme.textMuted),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.playlist_play_rounded, size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$trackCount',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              url.length > 20 ? '${url.substring(0, 20)}...' : url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _importPlaylist() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _importedTracks = [];
    });

    try {
      final api = ApiService();
      final tracks = await api.importPlaylist(_controller.text);
      
      if (tracks.isNotEmpty) {
        _saveSearch(_controller.text, tracks);
      }

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

    setState(() {
      _isBatchDownloading = true;
      _stopBatchRequested = false;
    });

    final library = context.read<LibraryProvider>();
    int count = 0;

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
      if (_stopBatchRequested) break;

      if (!library.isDownloaded(track.id) && !library.isDownloading(track.id)) {
        await library.downloadTrack(track);
        count++;
      }
    }

    if (mounted) {
      setState(() {
        _isBatchDownloading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _stopBatchRequested ? AppTheme.surface : AppTheme.accent,
          content: Text(
            _stopBatchRequested 
              ? 'stopped after $count tracks'
              : (count > 0 ? 'completed $count downloads' : 'all tracks already in library'),
            style: GoogleFonts.dmSans(
              color: _stopBatchRequested ? AppTheme.textPrimary : Colors.black, 
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      );
    }
  }

  void _stopBatch() {
    setState(() => _stopBatchRequested = true);
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
                              onPressed: _isBatchDownloading ? _stopBatch : _downloadAll,
                              icon: Icon(
                                _isBatchDownloading ? Icons.stop_rounded : Icons.download_rounded,
                                color: _isBatchDownloading ? AppTheme.accent2 : AppTheme.textMuted,
                                size: 20,
                              ),
                              label: Text(
                                _isBatchDownloading ? 'Stop' : 'Download',
                                style: GoogleFonts.dmSans(
                                  color: _isBatchDownloading ? AppTheme.accent2 : AppTheme.textMuted,
                                  fontSize: 13,
                                ),
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildRecentSearches(),
                    const SizedBox(height: 40),
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
