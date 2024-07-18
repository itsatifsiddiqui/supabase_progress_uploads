import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tus_client_dart/tus_client_dart.dart';
import 'package:uuid/uuid.dart';

class SupabaseUploadController {
  final SupabaseClient _supabase;
  final String bucketName;
  final Map<int, TusClient> _clients = {};
  final Map<int, double> _progressMap = {};

  final Map<int, Completer<String>> _urlCompleters = {};

  final _progressController = StreamController<double>.broadcast();
  final _completionController = StreamController<int>.broadcast();
  final _uuid = Uuid();

  Stream<int> get completionStream => _completionController.stream;

  SupabaseUploadController(this._supabase, this.bucketName);

  Future<int> addFile(XFile file) async {
    final fileId = _uuid.v4().hashCode;

    final tusClient = TusClient(
      file,
      store: TusMemoryStore(),
      retries: 5,
      retryInterval: 2,
      retryScale: RetryScale.exponential,
    );
    _clients[fileId] = tusClient;
    return fileId;
  }

  Future<void> removeFile(int fileId) async {
    _clients.remove(fileId);
  }

  Future<void> startUpload(
    int fileId, {
    String? contentType,
    Function(double progress)? onUploadProgress,
  }) async {
    final client = _clients[fileId];
    if (client == null) return;

    // Create a completer for this upload
    _urlCompleters[fileId] = Completer<String>();

    final uploadUrl = '${_supabase.storage.url}/upload/resumable';
    final uri = Uri.parse(uploadUrl);

    final headers = {
      'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
      'x-upsert': 'true'
    };

    final userId = _supabase.auth.currentUser!.id;

    final filename = client.file.name;

    final fileName = path.basename(filename);

    final fileType = client.file.mimeType ?? contentType ?? 'image/*';
    final objectName = '$userId/$fileName';

    _progressMap[fileId] = 0.0;

    await client.upload(
      uri: uri,
      headers: headers,
      metadata: {
        'bucketName': bucketName,
        'objectName': objectName,
        'contentType': fileType,
      },
      onStart: (TusClient client, Duration? estimate) {
        // If estimate is not null, it will provide the estimate time for completion
        // it will only be not null if measuring upload speed
        print('This is the client to be used $client and $estimate time');
      },
      onProgress: (progress, duration) {
        onUploadProgress?.call(progress);

        _progressMap[fileId] = progress;

        _progressController.add(progress);
      },
      onComplete: () async {
        try {
          final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(objectName);

          _progressMap[fileId] = 100;
          _progressController.add(100.0);

          // Complete the Future with the URL
          _urlCompleters[fileId]?.complete(publicUrl);

          _completionController.add(fileId);

          print('File uploaded successfully. Public URL: $publicUrl');
        } catch (e) {
          print('Error completing the upload: $e');
        }
      },
    );
  }

  void pauseUpload(int fileId) {
    _clients[fileId]?.pauseUpload();
  }

  void resumeUpload(int fileId) {
    _clients[fileId]?.createUpload();
  }

  Future<void> cancelUpload(int fileId) async {
    await _clients[fileId]?.cancelUpload();
    _clients.remove(fileId);
    _progressMap.remove(fileId);
    _urlCompleters.remove(fileId);
  }

  double getFileProgress(int fileId) {
    return _progressMap[fileId] ?? 0.0;
  }

  Future<String?> getUploadedUrl(int fileId) async {
    if (_urlCompleters.containsKey(fileId)) {
      return _urlCompleters[fileId]?.future;
    }
    return null;
  }

  Future<void> dispose() async {
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
