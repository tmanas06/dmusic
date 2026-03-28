import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
import '../providers/player_provider.dart';
import '../widgets/track_card.dart';
import 'player_screen.dart';
import '../providers/navigation_provider.dart';

/// Search screen — debounced search with results list.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ApiService _api = ApiService();
  Timer? _debounce;
  List<Track> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigation = context.watch<NavigationProvider>();
    if (navigation.pendingSearchQuery != null) {
      final query = navigation.pendingSearchQuery!;
      // Use microtask to clear the query after the build is complete
      Future.microtask(() {
        _searchController.text = query;
        _performSearch(query);
        navigation.consumeSearchQuery();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim());
      } else {
        setState(() {
          _results = [];
          _hasSearched = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await _api.search(query);
      setState(() {
        _results = results;
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('search failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'search',
                  style: GoogleFonts.syne(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.surface2, border: Border.all(color: AppTheme.border)),
                    child: const Icon(Icons.person_rounded, color: AppTheme.textMuted, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.searchRadius),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? AppTheme.accent.withOpacity(0.3)
                      : AppTheme.border,
                ),
                boxShadow: _focusNode.hasFocus
                    ? [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.06),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                style: GoogleFonts.dmSans(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'search any song, artist...',
                  hintStyle: GoogleFonts.dmSans(
                    color: AppTheme.textMuted.withOpacity(0.5),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppTheme.textMuted.withOpacity(0.4),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.textMuted,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _results = [];
                              _hasSearched = false;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  )
                : !_hasSearched
                    ? _buildEmptyState()
                    : _results.isEmpty
                        ? _buildNoResults()
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 160),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              return TrackCard(
                                track: _results[index],
                                index: index,
                                onTap: () {
                                  context.read<PlayerProvider>().playQueue(
                                        _results,
                                        index,
                                      );
                                  // Auto-open full player
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => PlayerScreen(),
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 64,
            color: AppTheme.textMuted.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'discover your next\nfavorite track',
            textAlign: TextAlign.center,
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off_rounded,
            size: 48,
            color: AppTheme.textMuted.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'no results found',
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'try a different search term',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textMuted.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
