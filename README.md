# Supabase Progress Uploads

A Flutter package for easy file uploads to Supabase storage with progress tracking.

## Features

- Single and multiple file uploads
- Upload progress tracking
- Pause, resume, and cancel uploads
- Direct access to upload controller for more granular control

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  supabase_progress_uploads: ^1.0.0
```

## Basic Usage

### Initialize the upload service

```dart
final supabase = Supabase.instance.client;
final uploadService = SupabaseUploadService(supabase, 'your-bucket-name');
```

### Upload a single file

```dart
String? url = await uploadService.uploadFile(
  file,
  onUploadProgress: (progress) {
    print('Upload progress: ${progress}%');
  },
);
print('Uploaded file URL: $url');
```

### Upload multiple files

```dart
List<String?> urls = await uploadService.uploadMultipleFiles(
  files,
  onUploadProgress: (progress) {
    print('Total upload progress: ${progress}%');
  },
);
print('Uploaded files URLs: $urls');
```

### Advanced: Using the SupabaseUploadController directly

For more granular control over the upload process:

```dart
final controller = SupabaseUploadController(supabase, 'your_bucket_name');

int fileId = await controller.addFile(file);
controller.startUpload(
  fileId,
  onUploadProgress: (progress) {
    print('Upload progress: ${progress}%');
  },
);
String? url = await controller.getUploadedUrl(fileId);
print('Uploaded file URL: $url');
```

### Pause, Resume, and Cancel uploads

```dart
controller.pauseUpload(fileId);
controller.resumeUpload(fileId);
await controller.cancelUpload(fileId);
```

## Additional information

Make sure to properly initialize Supabase in your app before using this package. For more detailed examples, check the `example` folder in the package repository.

Remember to dispose of the upload service when you're done:

```dart
@override
void dispose() {
  uploadService.dispose();
  super.dispose();
}
```

For issues, feature requests, or contributions, please visit the [GitHub repository](https://github.com/itsatifsiddiqui/supabase_progress_uploads).