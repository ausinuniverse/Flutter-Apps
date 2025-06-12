import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

Future<void> main() async {
  // Ensure widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Get available cameras
  final cameras = await availableCameras();
  
  // Find the front camera
  CameraDescription? frontCamera;
  for (var camera in cameras) {
    if (camera.lensDirection == CameraLensDirection.front) {
      frontCamera = camera;
      break;
    }
  }

  // If no front camera is found, use the first available camera
  frontCamera ??= cameras.isNotEmpty ? cameras.first : null;

  if (frontCamera == null) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('No cameras found on this device')),
        ),
      ),
    );
    return;
  }

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: CameraScreen(camera: frontCamera),
    ),
  );
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  List<String> _capturedImages = [];

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> takePicture() async {
    try {
      await _initializeControllerFuture;

      final Directory extDir = await getApplicationDocumentsDirectory();
      final String dirPath = '${extDir.path}/Pictures/flutter_camera';
      await Directory(dirPath).create(recursive: true);
      final String filePath = join(dirPath, '${DateTime.now()}.png');

      if (_controller.value.isTakingPicture) {
        return '';
      }

      final XFile picture = await _controller.takePicture();
      await picture.saveTo(filePath);

      setState(() {
        _capturedImages.add(filePath);
      });

      return filePath;
    } catch (e) {
      print('Error taking picture: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Camera for macOS'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton(
              onPressed: () async {
                try {
                  await takePicture();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Photo saved')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Icon(Icons.camera),
            ),
          ),
          if (_capturedImages.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _capturedImages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.file(File(_capturedImages[index])),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}