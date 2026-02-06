import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'services/camera_service_ffi.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPhoto2 FFI Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const CameraControlScreen(),
    );
  }
}

class CameraControlScreen extends StatefulWidget {
  const CameraControlScreen({super.key});

  @override
  State<CameraControlScreen> createState() => _CameraControlScreenState();
}

class _CameraControlScreenState extends State<CameraControlScreen> {
  final CameraServiceFfi _cameraService = CameraServiceFfi();

  String _status = "Ready";
  List<String> _logs = [];
  Uint8List? _lastImage;
  bool _isLoading = false;

  void _log(String message) {
    setState(() {
      _logs.add(message);
      _status = message;
    });
  }

  Future<void> _detectCamera() async {
    setState(() {
      _isLoading = true;
      _logs = []; // Clear logs on new session
    });
    _log("Initializing library...");

    try {
      if (!_cameraService.isInitialized) {
        _log("Library status: ${_cameraService.statusMessage}");
      }

      _log("Detecting camera...");
      final result = await _cameraService.detectCamera();
      _log(result);
    } catch (e) {
      _log("Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _takePicture() async {
    setState(() {
      _isLoading = true;
    });
    _log("Taking picture...");

    try {
      final imageBytes = await _cameraService.takePicture();
      if (imageBytes != null && imageBytes.isNotEmpty) {
        _log("Picture taken! Size: ${imageBytes.length} bytes");
        setState(() {
          _lastImage = imageBytes;
        });
      } else {
        _log("Failed to take picture (returned null).");
      }
    } catch (e) {
      _log("Exception taking picture: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPhoto2 FFI Camera'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Row(
        children: [
          // Left Control Panel
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _detectCamera,
                    icon: const Icon(Icons.search),
                    label: const Text("1. Detect Camera"),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _takePicture,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("2. Take Picture"),
                  ),
                  const Divider(height: 40),
                  const Text(
                    "Status Log:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.black26),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          // Show logs in reverse order? or normal. Let's do normal.
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _logs[index],
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right Preview Area
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black87,
              child: Center(
                child: _lastImage != null
                    ? Image.memory(_lastImage!, fit: BoxFit.contain)
                    : const Text(
                        "No Image Captured",
                        style: TextStyle(color: Colors.white54),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
