import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'config.dart';

/// Proper Mobile-Ready Audio Handler using audio_service.
/// Fully manages the playlist and player state.
class WaveAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  WaveAudioHandler() {
    _init();
  }

  void _init() async {
    // Connect playlist to player
    await _player.setAudioSource(_playlist);

    // Broadcast state changes from just_audio to audio_service
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Sync mediaItem when index changes
    _player.currentIndexStream.listen((index) {
      if (index != null && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
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
      // androidCompactControlIndices: const [0, 1, 3], // Disabled due to version conflict
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
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) => _player.seek(Duration.zero, index: index);

  Future<void> syncQueueWithTracks(List<Track> tracks) async {
    final items = tracks.map((track) {
      final url = track.isDownloaded && track.localFilePath != null
          ? track.localFilePath!
          : '${AppConfig.apiBaseUrl}/file/${track.id}';
          
      return MediaItem(
        id: track.id,
        album: track.album,
        title: track.title,
        artist: track.artist,
        duration: Duration(seconds: track.durationSeconds),
        artUri: Uri.parse('${AppConfig.apiBaseUrl}/art/${track.id}'),
        extras: {'url': url},
      );
    }).toList();

    queue.add(items);

    // Build just_audio sources
    final sources = items.map((item) {
      final url = item.extras!['url'] as String;
      return url.startsWith('http') 
          ? AudioSource.uri(Uri.parse(url))
          : AudioSource.file(url);
    }).toList();

    await _playlist.clear();
    await _playlist.addAll(sources);
  }
}

/// Singleton service to bridge UI and AudioHandler
class AudioPlayerService extends ChangeNotifier {
  static WaveAudioHandler? _handler;
  
  static Future<void> init() async {
    if (_handler != null) return;
    _handler = await AudioService.init(
      builder: () => WaveAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.wave.wave_app.channel.audio',
        androidNotificationChannelName: 'wave. Playback',
        androidNotificationOngoing: true,
      ),
    );
  }

  WaveAudioHandler? get handler => _handler;
  AudioPlayer? get player => _handler?._player;

  Track? get currentTrack {
    final mid = _handler?.mediaItem.value;
    if (mid == null) return null;
    return Track(
      id: mid.id,
      title: mid.title,
      artist: mid.artist ?? '',
      album: mid.album ?? '',
      durationSeconds: mid.duration?.inSeconds ?? 0,
      artworkUrl: mid.artUri?.toString() ?? '',
    );
  }

  bool get isPlaying => player?.playing ?? false;
  bool get hasTrack => currentTrack != null;
  
  Stream<Duration> get positionStream => player?.positionStream ?? const Stream.empty();
  Stream<Duration?> get durationStream => player?.durationStream ?? const Stream.empty();
  Duration get position => player?.position ?? Duration.zero;
  Duration get duration => player?.duration ?? Duration.zero;

  bool get isShuffleEnabled => player?.shuffleModeEnabled ?? false;
  bool get isRepeatEnabled => player?.loopMode != LoopMode.off;

  Future<void> playTrack(Track track) async {
    await playQueue([track], 0);
  }

  Future<void> playQueue(List<Track> tracks, int startIndex) async {
    if (_handler == null) return;
    await _handler!.syncQueueWithTracks(tracks);
    await _handler!.skipToQueueItem(startIndex);
    await _handler!.play();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await _handler?.pause();
    } else {
      await _handler?.play();
    }
    notifyListeners();
  }

  Future<void> skipNext() async {
    await _handler?.skipToNext();
    notifyListeners();
  }

  Future<void> skipPrevious() async {
    await _handler?.skipToPrevious();
    notifyListeners();
  }

  Future<void> seek(Duration position) => _handler?.seek(position) ?? Future.value();
  
  void toggleShuffle() {
    final newMode = !isShuffleEnabled;
    player?.setShuffleModeEnabled(newMode);
    notifyListeners();
  }

  void toggleRepeat() {
    final mode = isRepeatEnabled ? LoopMode.off : LoopMode.one;
    player?.setLoopMode(mode);
    notifyListeners();
  }

  @override
  void dispose() {
    // Handler is global, don't dispose player here
    super.dispose();
  }
}
