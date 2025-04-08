import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tus_client_dart/tus_client_dart.dart';
import 'package:uuid/uuid.dart';

import 'logger.dart';

class SupabaseUploadController {
  final SupabaseClient _supabase;
  final String bucketName;
  final Map<int, TusClient> _clients = {};
  final Map<int, double> _progressMap = {};
  final bool enableDebugLogs;
  final String cacheControl;

  final Map<int, Completer<String>> _urlCompleters = {};

  final _progressController = StreamController<double>.broadcast();
  final _completionController = StreamController<int>.broadcast();
  final _uuid = Uuid();

  final memoryStore = TusMemoryStore();

  Stream<int> get completionStream => _completionController.stream;

  SupabaseUploadController(
    this._supabase,
    this.bucketName, {
    this.enableDebugLogs = false,
    this.cacheControl = 'no-cache',
  }) {
    'Initialized SupabaseUploadController for bucket: $bucketName'
        .logIf(enableDebugLogs);
  }

  Future<int> addFile(XFile file) async {
    final fileId = _uuid.v4().hashCode;
    'Adding file: ${file.name} with generated ID: $fileId'
        .logIf(enableDebugLogs);

    final tusClient = TusClient(
      file,
      store: memoryStore,
      retries: 5,
      retryInterval: 2,
      retryScale: RetryScale.lineal,
    );
    _clients[fileId] = tusClient;
    'TusClient created for file ID: $fileId'.logIf(enableDebugLogs);
    return fileId;
  }

  Future<void> removeFile(int fileId) async {
    'Removing file with ID: $fileId'.logIf(enableDebugLogs);
    _clients.remove(fileId);
  }

  Future<void> startUpload(
    int fileId, {
    String? contentType,
    Function(double progress)? onUploadProgress,
  }) async {
    final client = _clients[fileId];
    if (client == null) {
      'No client found for file ID: $fileId'.logIf(enableDebugLogs);
      return;
    }

    'Starting upload for file ID: $fileId'.logIf(enableDebugLogs);

    // Create a completer for this upload
    _urlCompleters[fileId] = Completer<String>();

    final uploadUrl = '${_supabase.storage.url}/upload/resumable';
    final uri = Uri.parse(uploadUrl);

    final headers = {
      'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
      'x-upsert': 'true',
      'cache-control': cacheControl,
    };

    final userId = _supabase.auth.currentUser!.id;
    final filename = client.file.name;
    final fileName = path.basename(filename);
    final fileType = client.file.mimeType ?? contentType ?? 'image/*';
    final objectName = '$userId/$fileName';

    _progressMap[fileId] = 0.0;

    final metadata = {
      'bucketName': bucketName,
      'objectName': objectName,
      'contentType': fileType,
    };

    'Upload configuration - URI: $uri'.logIf(enableDebugLogs);
    'Upload metadata: $metadata'.logIf(enableDebugLogs);

    await client.upload(
      uri: uri,
      headers: headers,
      metadata: metadata,
      onStart: (TusClient client, Duration? estimate) {
        'Upload started for file ID: $fileId ${estimate != null ? "- Estimated duration: $estimate" : ""}'
            .logIf(enableDebugLogs);
      },
      onProgress: (progress, duration) {
        'Upload progress for file ID: $fileId - ${(progress * 100).toStringAsFixed(1)}%'
            .logIf(enableDebugLogs);

        onUploadProgress?.call(progress);
        _progressMap[fileId] = progress;
        _progressController.add(progress);
      },
      onComplete: () async {
        try {
          final publicUrl =
              _supabase.storage.from(bucketName).getPublicUrl(objectName);

          'Upload completed for file ID: $fileId - URL: $publicUrl'
              .logIf(enableDebugLogs);

          _progressMap[fileId] = 100;
          _progressController.add(100.0);
          _urlCompleters[fileId]?.complete(publicUrl);
          _completionController.add(fileId);
        } catch (e) {
          'Error completing upload for file ID: $fileId - Error: $e'
              .logIf(enableDebugLogs);
        }
      },
    );
  }

  void pauseUpload(int fileId) {
    'Pausing upload for file ID: $fileId'.logIf(enableDebugLogs);
    _clients[fileId]?.pauseUpload();
  }

  void resumeUpload(int fileId) {
    'Resuming upload for file ID: $fileId'.logIf(enableDebugLogs);
    _clients[fileId]?.createUpload();
  }

  Future<void> cancelUpload(int fileId) async {
    'Canceling upload for file ID: $fileId'.logIf(enableDebugLogs);
    await _clients[fileId]?.cancelUpload();
    _clients.remove(fileId);
    _progressMap.remove(fileId);
    _urlCompleters.remove(fileId);
  }

  double getFileProgress(int fileId) {
    final progress = _progressMap[fileId] ?? 0.0;
    'Current progress for file ID $fileId: ${(progress * 100).toStringAsFixed(1)}%'
        .logIf(enableDebugLogs);
    return progress;
  }

  Future<String?> getUploadedUrl(int fileId) async {
    'Retrieving uploaded URL for file ID: $fileId'.logIf(enableDebugLogs);
    if (_urlCompleters.containsKey(fileId)) {
      return _urlCompleters[fileId]?.future;
    }
    'No URL completer found for file ID: $fileId'.logIf(enableDebugLogs);
    return null;
  }

  Future<void> dispose() async {
    'Disposing SupabaseUploadController'.logIf(enableDebugLogs);
    for (var client in _clients.values) {
      await client.cancelUpload();
    }
    _clients.clear();
    _progressMap.clear();
    for (var completer in _urlCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError('Upload cancelled due to controller disposal');
      }
    }
    _urlCompleters.clear();
    await _progressController.close();
    await _completionController.close();
  }
}
