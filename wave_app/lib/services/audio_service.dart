import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';

/// Audio player service wrapping just_audio.
/// Manages playback state, seeking, and queue.
class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isShuffleEnabled = false;
  bool _isRepeatEnabled = false;

  // ── Getters ─────────────────────────────────────────
  AudioPlayer get player => _player;
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;
  bool get isShuffleEnabled => _isShuffleEnabled;
  bool get isRepeatEnabled => _isRepeatEnabled;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  bool get hasTrack => _currentTrack != null;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  AudioPlayerService() {
    // Listen for track completion
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_isRepeatEnabled) {
          _player.seek(Duration.zero);
          _player.play();
        } else if (hasNext) {
          skipNext();
        }
      }
      notifyListeners();
    });
  }

  // ── Playback controls ─────────────────────────────
  Future<void> playTrack(Track track) async {
    _currentTrack = track;
    // Add to queue if not already there
    final existingIndex = _queue.indexWhere((t) => t.id == track.id);
    if (existingIndex == -1) {
      _queue.add(track);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = existingIndex;
    }

    try {
      if (track.isDownloaded && track.localFilePath != null) {
        await _player.setFilePath(track.localFilePath!);
      } else {
        // Stream from server
        await _player.setUrl('http://10.0.2.2:8000/file/${track.id}');
      }
      await _player.play();
    } catch (e) {
      debugPrint('Playback error: $e');
    }
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.play();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> skipNext() async {
    if (hasNext) {
      _currentIndex++;
      await playTrack(_queue[_currentIndex]);
    }
  }

  Future<void> skipPrevious() async {
    // If past 3 seconds, restart; otherwise go to previous
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (hasPrevious) {
      _currentIndex--;
      await playTrack(_queue[_currentIndex]);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    if (_isShuffleEnabled) {
      final current = _queue[_currentIndex];
      _queue.shuffle();
      // Keep current track at current index
      _queue.remove(current);
      _queue.insert(_currentIndex, current);
    }
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeatEnabled = !_isRepeatEnabled;
    notifyListeners();
  }

  /// Set a queue of tracks and start playing from index
  Future<void> playQueue(List<Track> tracks, int startIndex) async {
    _queue = List.from(tracks);
    _currentIndex = startIndex;
    await playTrack(_queue[_currentIndex]);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
