class SupabaseUploadProgress {
  final int fileId;
  final double progress;
  SupabaseUploadProgress({
    required this.fileId,
    required this.progress,
  });

  SupabaseUploadProgress copyWith({
    int? fileId,
    double? progress,
  }) {
    return SupabaseUploadProgress(
      fileId: fileId ?? this.fileId,
      progress: progress ?? this.progress,
    );
  }

  @override
  String toString() =>
      'SupabaseUploadProgress(fileId: $fileId, progress: $progress)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SupabaseUploadProgress && other.fileId == fileId;
  }

  @override
  int get hashCode => fileId.hashCode;
}
