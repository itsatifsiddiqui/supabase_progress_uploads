import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_progress_uploads/supabase_progress_uploads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: UploadExample());
  }
}

class UploadExample extends StatefulWidget {
  const UploadExample({super.key});

  @override
  _UploadExampleState createState() => _UploadExampleState();
}

class _UploadExampleState extends State<UploadExample> {
  final ImagePicker _picker = ImagePicker();
  late SupabaseUploadService _uploadService;
  late SupabaseUploadController _uploadController;
  double _singleProgress = 0.0;
  double _multipleProgress = 0.0;

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    supabase.auth.signInAnonymously();
    _uploadService = SupabaseUploadService(supabase, 'your_bucket_name');
    _uploadController = SupabaseUploadController(supabase, 'your_bucket_name');
  }

  Future<void> _uploadSingleFile() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      String? url = await _uploadService.uploadFile(
        image,
        onUploadProgress: (progress) {
          setState(() => _singleProgress = progress);
        },
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('File Uploaded')));
      print('Uploaded file URL: $url');
    }
  }

  Future<void> _uploadMultipleFiles() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      List<String?> urls = await _uploadService.uploadMultipleFiles(
        images,
        onUploadProgress: (progress) {
          setState(() => _multipleProgress = progress);
        },
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Files Uploaded')));
      print('Uploaded files URLs: $urls');
    }
  }

  Future<void> _uploadWithController() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      int fileId = await _uploadController.addFile(image);
      _uploadController.startUpload(
        fileId,
        onUploadProgress: (progress) {
          setState(() => _singleProgress = progress);
        },
      );
      String? url = await _uploadController.getUploadedUrl(fileId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('File Uploaded')));
      print('Uploaded file URL: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supabase Upload Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _uploadSingleFile,
              child: const Text('Upload Single File'),
            ),
            Text('Single Progress: ${(_singleProgress).toStringAsFixed(2)}%'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadMultipleFiles,
              child: const Text('Upload Multiple Files'),
            ),
            Text(
                'Multiple Progress: ${(_multipleProgress).toStringAsFixed(2)}%'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadWithController,
              child: const Text('Upload with Controller'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _uploadService.dispose();
    super.dispose();
  }
}
