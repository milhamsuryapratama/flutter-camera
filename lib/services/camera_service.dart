import 'dart:io';

class CameraService {
  Future<String> detectCamera() async {
    try {
      final result = await Process.run('gphoto2', ['--auto-detect']);
      if (result.exitCode == 0) {
        return result.stdout.toString();
      } else {
        return 'Error: ${result.stderr}';
      }
    } catch (e) {
      return 'Failed to execute gphoto2: $e';
    }
  }

  Future<String> getSummary() async {
    try {
      final result = await Process.run('gphoto2', ['--summary']);
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
        final filePath = '${directory.path}/$filename';

        // --capture-image-and-download takes a picture and downloads it to the PC
        // --filename allows specifying where to save it
        final result = await Process.run('gphoto2', [
          '--capture-image-and-download',
          '--filename',
          filePath,
          '--force-overwrite',
        ]);

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

  Stream<List<int>> startPreview() async* {
    if (_isPreviewing) return;
    _isPreviewing = true;

    try {
      _previewProcess = await Process.start('gphoto2', [
        '--capture-movie',
        '--stdout',
      ]);

      final buffer = <int>[];
      final startMarker = [0xFF, 0xD8];
      final endMarker = [0xFF, 0xD9];

      await for (final chunk in _previewProcess!.stdout) {
        if (!_isPreviewing) break;
        buffer.addAll(chunk);

        while (true) {
          final startIndex = _findPattern(buffer, startMarker);
          if (startIndex == -1) {
            // Keep the last few bytes in case the marker is split across chunks
            if (buffer.length > 2) {
              final remaining = buffer.sublist(buffer.length - 2);
              buffer.clear();
              buffer.addAll(remaining);
            }
            break;
          }

          final endIndex = _findPattern(buffer, endMarker, startIndex);
          if (endIndex == -1) {
            // We have a start but no end, wait for more data
            // Remove everything before start to save memory
            if (startIndex > 0) {
              final remaining = buffer.sublist(startIndex);
              buffer.clear();
              buffer.addAll(remaining);
            }
            break;
          }

          // We have a full frame!
          // Include endMarker in the frame (endIndex points to 0xFF, so we need +2)
          final frameEnd = endIndex + 2;
          final jpegData = buffer.sublist(startIndex, frameEnd);

          yield jpegData;

          // Remove the processed frame from buffer
          final remaining = buffer.sublist(frameEnd);
          buffer.clear();
          buffer.addAll(remaining);
        }
      }
    } catch (e) {
      print('Preview error: $e');
    } finally {
      await stopPreview();
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
