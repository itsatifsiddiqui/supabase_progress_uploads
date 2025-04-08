import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controller.dart';
import 'logger.dart';

class SupabaseUploadService {
  final SupabaseUploadController controller;
  final bool enableDebugLogs;
  final String cacheControl;

  /// This is the path that will be used to store the uploaded files.
  ///
  /// If not provided, the root path will be the user's ID.
  /// e.g if the user's ID is `123`, the files will be stored in the `123` folder.
  final String? rootPath;
  SupabaseUploadService(
    SupabaseClient supabase,
    String bucketName, {
    this.enableDebugLogs = false,
    this.cacheControl = 'no-cache',
    this.rootPath,
  }) : controller = SupabaseUploadController(
          supabase,
          bucketName,
          enableDebugLogs: enableDebugLogs,
          cacheControl: cacheControl,
          rootPath: rootPath,
        ) {
    'Initialized SupabaseUploadService with bucket: $bucketName'
        .logIf(enableDebugLogs);
  }

  Future<String?> uploadFile(
    XFile file, {
    Function(double progress)? onUploadProgress,
  }) async {
    'Uploading file: ${file.name}'.logIf(enableDebugLogs);
    final fileId = await controller.addFile(file);
    'File registered with ID: $fileId'.logIf(enableDebugLogs);

    await controller.startUpload(fileId, onUploadProgress: (progress) {
      'Upload progress for file ${file.name}: ${(progress * 100).toStringAsFixed(1)}%'
          .logIf(enableDebugLogs);
      onUploadProgress?.call(progress);
    });

    final url = await controller.getUploadedUrl(fileId);
    'Upload completed for ${file.name}. URL: $url'.logIf(enableDebugLogs);
    return url;
  }

  Future<List<String?>> uploadMultipleFiles(
    List<XFile> files, {
    Function(double progress)? onUploadProgress,
  }) async {
    'Starting multiple file upload for ${files.length} files'
        .logIf(enableDebugLogs);

    // Step 1: Register all files and get unique file IDs.
    final fileIdsFutures = files.map((file) {
      return controller.addFile(file);
    });

    final fileIds = await Future.wait(fileIdsFutures);

    // Step 2: Create a map to track progress for each file.
    final Map<int, double> progressMap = {};
    fileIds.forEach((id) => progressMap[id] = 0.0);

    // Step 3: Define a helper function to calculate and report total progress.
    void updateAndReportProgress(int fileId, double progress) {
      progressMap[fileId] = progress;
      double totalProgress = progressMap.values.fold(0.0, (a, b) => a + b);
      final avgProgress = totalProgress / fileIds.length;
      'Total upload progress: ${(avgProgress).toStringAsFixed(1)}%'
          .logIf(enableDebugLogs);
      onUploadProgress?.call(avgProgress);
    }

    // Step 4: Start uploading files and track their progress.
    await Future.wait(
      fileIds.map(
        (fileId) => controller.startUpload(
          fileId,
          onUploadProgress: (progress) {
            'Upload progress for file ID $fileId: ${(progress).toStringAsFixed(1)}%'
                .logIf(enableDebugLogs);
            updateAndReportProgress(fileId, progress);
          },
        ),
      ),
    );

    // Step 5: Retrieve and return upload URLs after uploads complete.
    final uploadUrls = await Future.wait(
      fileIds.map((fileId) => controller.getUploadedUrl(fileId)),
    );

    'Multiple file upload completed. Retrieved ${uploadUrls.length} URLs'
        .logIf(enableDebugLogs);
    return uploadUrls;
  }

  double? getUploadProgress(int fileId) {
    final progress = controller.getFileProgress(fileId);
    'Current progress for file ID $fileId: ${"${(progress * 100).toStringAsFixed(1)}%"}'
        .logIf(enableDebugLogs);
    return progress;
  }

  Future<void> dispose() async {
    return controller.dispose();
  }
}
