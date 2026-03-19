import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/audio_service.dart';

/// Player provider — bridges AudioPlayerService with UI.
/// Re-exports player state for Provider consumers.
class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();

  AudioPlayerService get audioService => _audioService;

  Track? get currentTrack => _audioService.currentTrack;
  bool get isPlaying => _audioService.isPlaying;
  bool get isBuffering => _audioService.isBuffering;
  bool get hasTrack => _audioService.hasTrack;
  bool get isShuffleEnabled => _audioService.isShuffleEnabled;
  bool get isRepeatEnabled => _audioService.isRepeatEnabled;

  PlayerProvider() {
    // Listen to audio service changes
    _audioService.addListener(() {
      notifyListeners();
    });
  }

  Future<void> playTrack(Track track) async {
    await _audioService.playTrack(track);
  }

  Future<void> togglePlayPause() async {
    await _audioService.togglePlayPause();
  }

  Future<void> skipNext() async {
    await _audioService.skipNext();
  }

  Future<void> skipPrevious() async {
    await _audioService.skipPrevious();
  }

  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
  }

  void toggleShuffle() {
    _audioService.toggleShuffle();
  }

  void toggleRepeat() {
    _audioService.toggleRepeat();
  }

  Future<void> playQueue(List<Track> tracks, int startIndex) async {
    await _audioService.playQueue(tracks, startIndex);
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
