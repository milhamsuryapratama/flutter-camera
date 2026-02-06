import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/camera_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CameraService _cameraService = CameraService();
  String _status = 'Not Connected';
  String? _lastImagePath;
  bool _isLoading = false;

  Stream<List<int>>? _previewStream;
  int _timerSeconds = 0;
  bool _isTimerRunning = false;
  int _countdownValue = 0;

  @override
  void initState() {
    super.initState();
    // Auto-connect and auto-start live view
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _connectCamera();
      if (!_status.startsWith('Error')) {
        _startPreview();
      }
    });
  }

  Future<void> _startPreview() async {
    setState(() {
      _previewStream = _cameraService.startPreview();
    });
  }

  Future<void> _stopPreview() async {
    await _cameraService.stopPreview();
    // Small delay to ensure process is fully killed and USB released
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _previewStream = null;
      });
    }
  }

  Future<void> _connectCamera() async {
    setState(() {
      _isLoading = true;
      _status = 'Connecting...';
    });

    try {
      final result = await _cameraService.detectCamera();
      if (mounted) {
        setState(() {
          _status = result;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (_timerSeconds > 0) {
      setState(() {
        _isTimerRunning = true;
        _countdownValue = _timerSeconds;
      });

      for (int i = 0; i < _timerSeconds; i++) {
        if (!mounted) return;
        setState(() => _countdownValue = _timerSeconds - i);
        await Future.delayed(const Duration(seconds: 1));
      }

      if (mounted) {
        setState(() => _isTimerRunning = false);
      }
    }

    // Stop preview before taking picture
    // CRITICAL: Must wait for preview to stop to release USB interface
    if (_previewStream != null) {
      await _stopPreview();
    }

    setState(() {
      _isLoading = true;
      _status = 'Taking picture...';
    });

    try {
      final imagePath = await _cameraService.takePicture();
      if (imagePath != null && mounted) {
        setState(() {
          _lastImagePath = imagePath;
          _status = 'Picture taken: $imagePath';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error taking picture: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // NOTE: We do NOT auto-restart preview anymore.
        // User must click "Take Again" to review the picture and restart.
      }
    }
  }

  Future<void> _retakePicture() async {
    setState(() {
      _lastImagePath = null;
    });
    // Add small delay to ensure UI cleanly switches before heavy USB op
    await Future.delayed(const Duration(milliseconds: 200));
    await _startPreview();
  }

  Future<void> _ejectCamera() async {
    setState(() {
      _isLoading = true;
      _status = 'Ejecting camera...';
      _previewStream = null;
    });

    try {
      final result = await _cameraService.ejectCamera();
      if (mounted) {
        setState(() {
          _status = result;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we are in "Review Mode" (Image shown, no live view)
    final bool isReviewing =
        _lastImagePath != null && _previewStream == null && !_isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Canon Camera Control')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Camera Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _status.toLowerCase().contains('error')
                            ? Colors.red
                            : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (isReviewing) ...[
                  // Review Mode: Show simple "Take Again" button
                  ElevatedButton.icon(
                    key: const ValueKey(
                      'retakeBtn',
                    ), // Key prevents interpolation with captureBtn
                    onPressed: _retakePicture,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Take Again (Back to Live View)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ] else ...[
                  // Capture Mode: Show Timer and Take Picture
                  DropdownButton<int>(
                    value: _timerSeconds,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Timer: Off')),
                      DropdownMenuItem(value: 2, child: Text('2s')),
                      DropdownMenuItem(value: 5, child: Text('5s')),
                      DropdownMenuItem(value: 10, child: Text('10s')),
                    ],
                    onChanged: _isLoading || _isTimerRunning
                        ? null
                        : (value) {
                            setState(() {
                              _timerSeconds = value!;
                            });
                          },
                  ),
                  ElevatedButton.icon(
                    key: const ValueKey(
                      'captureBtn',
                    ), // Key prevents interpolation
                    onPressed: _isLoading || _isTimerRunning
                        ? null
                        : _takePicture,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      _isTimerRunning ? '$_countdownValue s' : 'Take Picture',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Secondary Controls (Live View Toggle / Reconnect)
            // Hide Live View toggle if we are reviewing, to avoid confusion
            if (!isReviewing)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _isLoading
                        ? null
                        : (_previewStream != null
                              ? _stopPreview
                              : _startPreview),
                    icon: Icon(
                      _previewStream != null
                          ? Icons.videocam_off
                          : Icons.videocam,
                    ),
                    label: Text(
                      _previewStream != null
                          ? 'Stop Live View'
                          : 'Start Live View',
                    ),
                  ),
                  const SizedBox(width: 20),
                  TextButton.icon(
                    onPressed: _isLoading ? null : _connectCamera,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reconnect'),
                  ),
                  const SizedBox(width: 20),
                  TextButton.icon(
                    onPressed: _isLoading ? null : _ejectCamera,
                    icon: const Icon(Icons.eject, color: Colors.orange),
                    label: const Text('Eject Camera'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Preview Section
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: _previewStream != null
                        ? StreamBuilder<List<int>>(
                            stream: _previewStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  Uint8List.fromList(snapshot.data!),
                                  gaplessPlayback: true,
                                  fit: BoxFit.contain,
                                );
                              } else if (snapshot.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Preview Error: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              } else {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                            },
                          )
                        : _lastImagePath != null
                        ? Image.file(File(_lastImagePath!), fit: BoxFit.contain)
                        : Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text('No image captured yet'),
                            ),
                          ),
                  ),
                  if (_isTimerRunning)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          '$_countdownValue',
                          style: const TextStyle(
                            fontSize: 100,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
