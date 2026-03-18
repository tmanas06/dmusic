import 'package:hive/hive.dart';

part 'track.g.dart';

/// Track model — stored in Hive for offline library.
/// Uses wave internal IDs only. No source references.
@HiveType(typeId: 0)
class Track extends HiveObject {
  @HiveField(0)
  final String id; // internal wave ID e.g. "wv_abc123"

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String artist;

  @HiveField(3)
  final String album;

  @HiveField(4)
  final int durationSeconds;

  @HiveField(5)
  final String artworkUrl; // always proxied server URL

  @HiveField(6)
  String? localFilePath; // set after download completes

  @HiveField(7)
  final DateTime addedAt;

  @HiveField(8)
  String quality; // "128kbps" | "256kbps" | "320kbps"

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    required this.artworkUrl,
    this.localFilePath,
    DateTime? addedAt,
    this.quality = '320kbps',
  }) : addedAt = addedAt ?? DateTime.now();

  bool get isDownloaded => localFilePath != null;

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Create from API JSON response
  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String? ?? '',
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      artworkUrl: json['artwork_url'] as String? ?? '',
      quality: '320kbps',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration_seconds': durationSeconds,
      'artwork_url': artworkUrl,
    };
  }
}
