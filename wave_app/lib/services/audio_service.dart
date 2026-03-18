import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'config.dart';

/// Proper Mobile-Ready Audio Handler using audio_service.
/// This version supports lock screen controls and background playback.
class WaveAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();

  WaveAudioHandler() {
    _init();
  }

  void _init() {
    // Broadcast state changes
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Listen for track completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      // androidCompactControlIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() async {
    // Handling queue logic from provider/service?
  }

  @override
  Future<void> skipToPrevious() async {
    // Handling queue logic
  }

  Future<void> playTrack(Track track) async {
    final mediaItem = MediaItem(
      id: track.id,
      album: track.album,
      title: track.title,
      artist: track.artist,
      duration: Duration(seconds: track.durationSeconds),
      artUri: Uri.parse('${AppConfig.apiBaseUrl}/art/${track.id}'),
    );

    this.mediaItem.add(mediaItem);

    try {
      if (track.isDownloaded && track.localFilePath != null) {
        await _player.setFilePath(track.localFilePath!);
      } else {
        await _player.setUrl('${AppConfig.apiBaseUrl}/file/${track.id}');
      }
      play();
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }
}

/// Legacy wrapper for UI compatibility
class AudioPlayerService extends ChangeNotifier {
  static WaveAudioHandler? _handler;
  
  static Future<void> init() async {
    _handler = await AudioService.init(
      builder: () => WaveAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.wave.wave_app.channel.audio',
        androidNotificationChannelName: 'wave. Playback',
        androidNotificationOngoing: true,
      ),
    );
  }

  WaveAudioHandler get handler => _handler!;
  AudioPlayer get player => handler._player;

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = -1;

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => player.playing;
  bool get hasTrack => _currentTrack != null;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  
  Duration get position => player.position;
  Duration get duration => player.duration ?? Duration.zero;

  // Bridge streams for UI
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;

  Future<void> playTrack(Track track) async {
    _currentTrack = track;
    await handler.playTrack(track);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      await handler.pause();
    } else {
      await handler.play();
    }
    notifyListeners();
  }

  Future<void> playQueue(List<Track> tracks, int startIndex) async {
    _queue = tracks;
    _currentIndex = startIndex;
    await playTrack(_queue[_currentIndex]);
  }

  Future<void> skipNext() async {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await playTrack(_queue[_currentIndex]);
    }
  }

  Future<void> skipPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await playTrack(_queue[_currentIndex]);
    }
  }

  Future<void> seek(Duration position) => handler.seek(position);

  void toggleShuffle() {} // Placeholder
  void toggleRepeat() {} // Placeholder
  bool get isShuffleEnabled => false;
  bool get isRepeatEnabled => false;
}
