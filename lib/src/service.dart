import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controller.dart';

class SupabaseUploadService {
  final SupabaseUploadController controller;

  SupabaseUploadService(SupabaseClient supabase, String bucketName)
      : controller = SupabaseUploadController(supabase, bucketName);

  Future<String?> uploadFile(
    XFile file, {
    Function(double progress)? onUploadProgress,
  }) async {
    final fileId = await controller.addFile(file);
    await controller.startUpload(fileId, onUploadProgress: onUploadProgress);
    return controller.getUploadedUrl(fileId);
  }

  Future<List<String?>> uploadMultipleFiles(
    List<XFile> files, {
    Function(double progress)? onUploadProgress,
  }) async {
    // Step 1: Register all files and get unique file IDs.
    final fileIds = await Future.wait(files.map((file) => controller.addFile(file)));

    // Step 2: Create a map to track progress for each file.
    final Map<int, double> progressMap = {};
    fileIds.forEach((id) => progressMap[id] = 0.0);

    // Step 3: Define a helper function to calculate and report total progress.
    void updateAndReportProgress(int fileId, double progress) {
      progressMap[fileId] = progress; // Update progress for the specific file.
      double totalProgress = progressMap.values.fold(0.0, (a, b) => a + b);
      onUploadProgress?.call(totalProgress / fileIds.length); // Calculate average progress.
    }

    // Step 4: Start uploading files and track their progress.
    await Future.wait(
      fileIds.map(
        (fileId) => controller.startUpload(
          fileId,
          onUploadProgress: (progress) {
            updateAndReportProgress(fileId, progress);
          },
        ),
      ),
    );

    // Step 5: Retrieve and return upload URLs after uploads complete.
    final uploadUrls =
        await Future.wait(fileIds.map((fileId) => controller.getUploadedUrl(fileId)));
    return uploadUrls;
  }

  double? getUploadProgress(int fileId) {
    return controller.getFileProgress(fileId);
  }

  Future<void> dispose() {
    return controller.dispose();
  }
}
