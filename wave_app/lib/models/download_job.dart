/// Download job model for tracking download progress
class DownloadJob {
  final String jobId;
  final String trackId;
  String status; // pending | processing | done | failed
  int progress;  // 0-100

  DownloadJob({
    required this.jobId,
    required this.trackId,
    this.status = 'pending',
    this.progress = 0,
  });

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isInProgress => status == 'pending' || status == 'processing';

  factory DownloadJob.fromJson(Map<String, dynamic> json) {
    return DownloadJob(
      jobId: json['job_id'] as String,
      trackId: json['track_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      progress: json['progress'] as int? ?? 0,
    );
  }
}
