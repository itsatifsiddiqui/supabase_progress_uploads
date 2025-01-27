import 'dart:developer' as dev;

extension ExtendedObject on Object? {
  void log([String? logName]) => dev.log(
        toString(),
        name: logName ?? 'supabase_progress_uploads',
      );

  void logIf(bool enableDebugLogs) {
    if (enableDebugLogs) {
      log();
    }
  }
}
