import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import '../models/download_job.dart';
import '../services/api_service.dart';

/// Manages the downloaded tracks library and download operations.
class LibraryProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  Box<Track>? _tracksBox;
  final Map<String, DownloadJob> _activeJobs = {};

  List<Track> get tracks {
    if (_tracksBox == null || !_tracksBox!.isOpen) return [];
    return _tracksBox!.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  Map<String, DownloadJob> get activeJobs => _activeJobs;

  bool isDownloaded(String trackId) {
    if (_tracksBox == null || !_tracksBox!.isOpen) return false;
    final track = _tracksBox!.values.where((t) => t.id == trackId).firstOrNull;
    return track?.isDownloaded ?? false;
  }

  bool isDownloading(String trackId) {
    return _activeJobs.values.any(
      (j) => j.trackId == trackId && j.isInProgress,
    );
  }

  int getProgress(String trackId) {
    final job = _activeJobs.values
        .where((j) => j.trackId == trackId)
        .firstOrNull;
    return job?.progress ?? 0;
  }

  Future<void> init() async {
    _tracksBox = await Hive.openBox<Track>('tracks');
    notifyListeners();
  }

  /// Start a download for a track
  Future<void> downloadTrack(Track track, {String quality = '320kbps'}) async {
    if (isDownloaded(track.id) || isDownloading(track.id)) return;

    try {
      // Request download from backend
      final jobId = await _api.requestDownload(track.id, quality);

      final job = DownloadJob(
        jobId: jobId,
        trackId: track.id,
        status: 'pending',
      );
      _activeJobs[jobId] = job;
      notifyListeners();

      // Poll for progress
      await for (final data in _api.watchProgress(jobId)) {
        job.status = data['status'] as String;
        job.progress = data['progress'] as int? ?? 0;
        notifyListeners();

        if (job.isDone) {
          // Download the actual file to phone storage
          await _saveToPhone(track, quality);
          _activeJobs.remove(jobId);
          notifyListeners();
          break;
        } else if (job.isFailed) {
          _activeJobs.remove(jobId);
          notifyListeners();
          break;
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
      notifyListeners();
    }
  }

  Future<void> _saveToPhone(Track track, String quality) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/wave_music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final safeName = '${track.title} - ${track.artist}'
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final filePath = '${musicDir.path}/$safeName.mp3';

      await _api.downloadFileToPhone(track.id, filePath);

      // Save to Hive with local file path
      final savedTrack = Track(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        durationSeconds: track.durationSeconds,
        artworkUrl: track.artworkUrl,
        localFilePath: filePath,
        quality: quality,
      );

      await _tracksBox?.put(track.id, savedTrack);
      notifyListeners();
    } catch (e) {
      debugPrint('Save to phone error: $e');
    }
  }

  /// Delete a downloaded track
  Future<void> deleteTrack(String trackId) async {
    final track = _tracksBox?.get(trackId);
    if (track?.localFilePath != null) {
      try {
        final file = File(track!.localFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Delete file error: $e');
      }
    }
    await _tracksBox?.delete(trackId);
    notifyListeners();
  }

  /// Clear all downloaded tracks
  Future<void> clearLibrary() async {
    for (final track in tracks) {
      if (track.localFilePath != null) {
        try {
          final file = File(track.localFilePath!);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
    await _tracksBox?.clear();
    notifyListeners();
  }
}
