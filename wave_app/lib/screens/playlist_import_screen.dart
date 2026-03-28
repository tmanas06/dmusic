import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
    // Open a fresh box for the unified history logic
    _historyBox = await Hive.openBox<Map>('playlist_history_unified');
    _loadHistoryData();
  }

  void _loadHistoryData() {
    if (_historyBox == null) return;
    if (mounted) {
      setState(() {
        // Sort by timestamp if available, otherwise just use values
        final values = _historyBox!.values.map((e) => Map<String, dynamic>.from(e)).toList();
        values.sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
        _pastSearches = values;
      });
    }
  }

  void _saveSearch(String url, List<Track> tracks) {
    if (url.isEmpty || _historyBox == null || tracks.isEmpty) return;
    
    // Try to find a meaningful title from the tracks or first track
    String title = "Imported Playlist";
    if (tracks.isNotEmpty) {
      // Logic: if many tracks have the same album, use it? Or just 'Playlist'
      // For now, let's just stick to 'Playlist' until we have playlist metadata from API
    }
    
    final String imageUrl = tracks.first.artworkUrl;

    final Map<String, dynamic> entry = {
      'url': url,
      'title': title,
      'imageUrl': imageUrl,
      'trackCount': tracks.length,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Save with URL as key to prevent duplicates
    _historyBox!.put(url, entry);
    _historyBox!.flush(); // Force persist
    
    _loadHistoryData();
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
                'Past Searched',
                style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: _clearHistory,
                child: Text(
                  'clear all',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.82,
          ),
          itemCount: _pastSearches.length,
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
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Square portion
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
                            // Gradient overlay for bottom metadata
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.playlist_play_rounded, size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$trackCount',
                                      style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Search again',
                            style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.accent),
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

      if (mounted) {
        setState(() {
          _importedTracks = tracks;
          _isLoading = false;
        });
      }

      if (tracks.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tracks found in this playlist.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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

    for (var track in _importedTracks) {
      if (_stopBatchRequested) break;
      if (!library.isDownloaded(track.id) && !library.isDownloading(track.id)) {
        await library.downloadTrack(track);
        count++;
      }
    }

    if (mounted) {
      setState(() => _isBatchDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(count > 0 ? 'Queued $count downloads' : 'All tracks already in library')),
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
          style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
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
                Text('YouTube Playlist Link', style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.textMuted)),
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
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.accent)))
          else if (_importedTracks.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_importedTracks.length} tracks', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _isBatchDownloading ? _stopBatch : _downloadAll,
                              icon: Icon(_isBatchDownloading ? Icons.stop_rounded : Icons.download_rounded, color: _isBatchDownloading ? Colors.red : AppTheme.accent, size: 20),
                              label: Text(_isBatchDownloading ? 'Stop' : 'Get All', style: GoogleFonts.dmSans(color: _isBatchDownloading ? Colors.red : AppTheme.accent)),
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
                      itemBuilder: (context, index) => TrackCard(
                        track: _importedTracks[index],
                        index: index,
                        onTap: () => context.read<PlayerProvider>().playQueue(_importedTracks, index),
                      ),
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
                    const SizedBox(height: 60),
                    Icon(Icons.playlist_add_rounded, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.1)),
                    const SizedBox(height: 16),
                    Text('Search for a playlist to start listening', style: GoogleFonts.dmSans(color: AppTheme.textMuted)),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
