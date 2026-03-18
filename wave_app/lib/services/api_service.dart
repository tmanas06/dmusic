import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import 'config.dart';

/// API service for communicating with the wave. backend.
/// All URLs point to YOUR server only — no external references.
class ApiService {
  static const _base = AppConfig.apiBaseUrl;

  final Dio _dio;

  ApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _base,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  /// Search for tracks — returns only wave internal schema
  Future<List<Track>> search(String query) async {
    try {
      final res = await _dio.get('/search', queryParameters: {'q': query});
      if (res.data is List) {
        return (res.data as List)
            .map((j) => Track.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('ApiService Error: $e');
      throw Exception('Search failed. Please try again.');
    }
  }

  /// Get trending tracks for home screen
  Future<List<Track>> getTrending() async {
    try {
      final res = await _dio.get('/trending');
      if (res.data is List) {
        return (res.data as List)
            .map((j) => Track.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException {
      throw Exception('Failed to fetch trending tracks.');
    }
  }

  /// Get dynamic mood categories
  Future<List<Map<String, dynamic>>> getMoods() async {
    try {
      final res = await _dio.get('/moods');
      if (res.data is List) {
        return List<Map<String, dynamic>>.from(res.data as List);
      }
      return [];
    } on DioException {
      throw Exception('Failed to fetch moods.');
    }
  }

  /// Request a download — returns job_id for progress tracking
  Future<String> requestDownload(String trackId, String quality) async {
    try {
      final res = await _dio.post('/download', data: {
        'id': trackId,
        'quality': quality,
      });
      return res.data['job_id'] as String;
    } on DioException {
      throw Exception('Download request failed. Please try again.');
    }
  }

  /// Watch download progress — polls every 800ms
  Stream<Map<String, dynamic>> watchProgress(String jobId) async* {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 800));
      try {
        final res = await _dio.get('/download-status/$jobId');
        final data = res.data as Map<String, dynamic>;
        yield data;
        final status = data['status'] as String;
        if (status == 'done' || status == 'failed') break;
      } on DioException {
        yield {'status': 'failed', 'progress': 0};
        break;
      }
    }
  }

  /// Download the actual audio file to phone storage
  Future<void> downloadFileToPhone(String trackId, String savePath) async {
    try {
      await _dio.download('/file/$trackId', savePath);
    } on DioException {
      throw Exception('File download failed. Please try again.');
    }
  }

  /// Get the full artwork URL for a track
  String getArtworkUrl(String trackId) {
    return '$_base/art/$trackId';
  }
}
