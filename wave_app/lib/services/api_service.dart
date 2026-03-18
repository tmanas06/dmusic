import 'dart:async';
import 'package:dio/dio.dart';
import '../models/track.dart';

/// API service for communicating with the wave. backend.
/// All URLs point to YOUR server only — no external references.
class ApiService {
  // For Android emulator use 10.0.2.2, for iOS simulator use localhost
  static const _base = 'http://10.0.2.2:8000';

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
    } on DioException {
      // Generic error — never expose backend details to user
      throw Exception('Search failed. Please try again.');
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
