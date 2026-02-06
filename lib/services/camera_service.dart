import 'dart:io';

class CameraService {
  // MSYS2 gphoto2 paths - required for Windows
  // Merge with existing environment so we don't lose PATH
  static Map<String, String>? _getGphoto2Env() {
    if (!Platform.isWindows) return null;
    return {
      ...Platform.environment,
      'CAMLIBS': 'C:\\msys64\\mingw64\\lib\\libgphoto2\\2.5.33',
      'IOLIBS': 'C:\\msys64\\mingw64\\lib\\libgphoto2_port\\0.12.2',
    };
  }

  static final Map<String, String>? _gphoto2Env = _getGphoto2Env();

  Future<String> detectCamera() async {
    try {
      print('Calling gphoto2 --auto-detect...');
      print('CAMLIBS: ${_gphoto2Env?["CAMLIBS"]}');
      print('IOLIBS: ${_gphoto2Env?["IOLIBS"]}');

      final result = await Process.run('gphoto2', [
        '--auto-detect',
      ], environment: _gphoto2Env);

      print('Exit code: ${result.exitCode}');
      print('stdout: ${result.stdout}');
      print('stderr: ${result.stderr}');

      if (result.exitCode == 0) {
        return result.stdout.toString();
      } else {
        return 'Error: ${result.stderr}';
      }
    } catch (e) {
      print('Exception: $e');
      return 'Failed to execute gphoto2: $e';
    }
  }

  Future<String> getSummary() async {
    try {
      final result = await Process.run('gphoto2', [
        '--summary',
      ], environment: _gphoto2Env);
      if (result.exitCode == 0) {
        return result.stdout.toString();
      } else {
        return 'Error: ${result.stderr}';
      }
    } catch (e) {
      return 'Failed to execute gphoto2: $e';
    }
  }

  Future<String?> takePicture({int retries = 3}) async {
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final directory = Directory.systemTemp;
        // Use a timestamp to ensure unique filename
        final filename = 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = '${directory.path}${Platform.pathSeparator}$filename';

        // --capture-image-and-download takes a picture and downloads it to the PC
        // --filename allows specifying where to save it
        final result = await Process.run('gphoto2', [
          '--capture-image-and-download',
          '--filename',
          filePath,
          '--force-overwrite',
        ], environment: _gphoto2Env);

        if (result.exitCode == 0) {
          // Verify file exists
          final file = File(filePath);
          if (await file.exists()) {
            return filePath;
          } else {
            // Check for warnings even on success (gphoto2 quirks)
            if (result.stdout.toString().contains('Auto-Focus failed') ||
                result.stderr.toString().contains('Auto-Focus failed')) {
              if (attempt < retries) {
                print(
                  'Auto-focus failed using exit code 0, retrying (attempt $attempt)...',
                );
                await Future.delayed(const Duration(seconds: 1));
                continue;
              }
            }

            print(
              'WARNING: gphoto2 returned 0 but file not found at $filePath',
            );
            print('STDOUT: ${result.stdout}');
            print('STDERR: ${result.stderr}');

            // Try to wait a bit, maybe it's flushing?
            await Future.delayed(const Duration(seconds: 1));
            if (await file.exists()) {
              return filePath;
            }

            throw Exception(
              'Image captured but file not found at $filePath\nStdout: ${result.stdout}\nStderr: ${result.stderr}',
            );
          }
        } else {
          // Handle specific errors
          final stderr = result.stderr.toString();
          final stdout = result.stdout.toString();

          if (stderr.contains('Auto-Focus failed') ||
              stdout.contains('Auto-Focus failed')) {
            if (attempt < retries) {
              print('Auto-focus failed, retrying (attempt $attempt)...');
              await Future.delayed(const Duration(seconds: 1));
              continue;
            }
            throw Exception(
              'Camera Auto-Focus Failed. Please ensure lighting is good or switch lens to Manual Focus (MF).',
            );
          }

          if (stderr.contains('busy') || stdout.contains('busy')) {
            if (attempt < retries) {
              print('Camera busy, retrying (attempt $attempt)...');
              await Future.delayed(const Duration(seconds: 2));
              continue;
            }
            throw Exception('Camera is busy. Please wait a moment.');
          }

          print('Error taking picture: $stderr $stdout');
          throw Exception('Error taking picture: $stderr');
        }
      } catch (e) {
        if (attempt == retries) {
          print('Failed to take picture after $retries attempts: $e');
          rethrow;
        }
      }
    }
    return null;
  }

  Process? _previewProcess;
  bool _isPreviewing = false;

  /// Starts live preview using --capture-preview in a loop.
  /// This is more compatible than --capture-movie which has I/O issues on Windows.
  Stream<List<int>> startPreview() async* {
    if (_isPreviewing) return;
    _isPreviewing = true;

    try {
      print('Starting preview with capture-preview loop...');

      // Use capture-preview in a loop instead of capture-movie
      // This is slower but more compatible on Windows
      int frameCount = 0;
      while (_isPreviewing) {
        final tempDir = Directory.systemTemp;
        final previewPath =
            '${tempDir.path}${Platform.pathSeparator}preview_temp.jpg';

        print('Calling gphoto2 --capture-preview...');
        final result = await Process.run('gphoto2', [
          '--capture-preview',
          '--filename',
          previewPath,
          '--force-overwrite',
        ], environment: _gphoto2Env);
        print('gphoto2 returned with exit code: ${result.exitCode}');

        if (!_isPreviewing) break;

        if (result.exitCode == 0) {
          final file = File(previewPath);
          final exists = await file.exists();
          print('File exists: $exists, path: $previewPath');
          if (exists) {
            final bytes = await file.readAsBytes();
            print('File size: ${bytes.length} bytes');
            if (bytes.isNotEmpty) {
              frameCount++;
              if (frameCount <= 3) {
                print('Preview frame $frameCount: ${bytes.length} bytes');
              }
              yield bytes;
            } else {
              print('File is empty!');
            }
          }
        } else {
          final stderr = result.stderr.toString();
          print('Preview failed: exit=${result.exitCode}, stderr=$stderr');
          // Small delay before retry on error
          await Future.delayed(const Duration(milliseconds: 500));
        }

        // Small delay between frames to avoid overwhelming the camera
        // Adjust this for your desired frame rate
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      print('Preview error: $e');
    } finally {
      _isPreviewing = false;
    }
  }

  Future<void> stopPreview() async {
    _isPreviewing = false;
    if (_previewProcess != null) {
      _previewProcess!.kill();
      _previewProcess = null;
    }
  }

  int _findPattern(List<int> data, List<int> pattern, [int start = 0]) {
    for (int i = start; i <= data.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }
}
