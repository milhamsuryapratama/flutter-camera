import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import '../gphoto2/gphoto2_ffi.dart';

class CameraServiceFfi {
  final GPhoto2 _gphoto2;

  // We keep a pointer to the camera if connected
  Pointer<Void>? _cameraContext;
  Pointer<Void>? _camera;

  bool get isInitialized => _gphoto2.isLoaded;
  String get statusMessage => _gphoto2.statusMessage;

  CameraServiceFfi() : _gphoto2 = GPhoto2();

  Future<String> detectCamera() async {
    if (!isInitialized)
      return "Library not initialized: ${_gphoto2.statusMessage}";

    final sb = StringBuffer();

    // 1. Probe Ports
    try {
      final listPtrRef = calloc<Pointer<Void>>();
      int ret = _gphoto2.newPortInfoList(listPtrRef);
      if (ret < 0) {
        sb.writeln(
          "Warning: Failed to create port list: ${_gphoto2.getResultAsString(ret)}",
        );
      } else {
        final list = listPtrRef.value;
        ret = _gphoto2.loadPortInfoList(list);
        if (ret < 0) {
          sb.writeln(
            "Warning: Failed to load port list: ${_gphoto2.getResultAsString(ret)}",
          );
          // This usually means libgphoto2_port can't load its drivers
        } else {
          final count = _gphoto2.countPortInfoList(list);
          sb.writeln("Found $count ports available to the library.");
          if (count == 0) {
            sb.writeln(
              "CRITICAL: No ports found. This means the library cannot see USB ports.",
            );
            sb.writeln(
              "Ensure you copied ALL DLLs, including `iolib.dll` or `usb.dll` if they exist in `libgphoto2_port` folder.",
            );
          }
        }
        _gphoto2.freePortInfoList(list);
        calloc.free(listPtrRef);
      }
    } catch (e) {
      sb.writeln("Exception probing ports: $e");
    }

    // 2. Detect Camera
    try {
      _cameraContext = _gphoto2.createContext();
      if (_cameraContext == null)
        return "${sb.toString()}Failed to create context";

      final cameraPtr = calloc<Pointer<Void>>();
      int ret = _gphoto2.newCamera(cameraPtr);
      if (ret < 0) {
        calloc.free(cameraPtr);
        return "${sb.toString()}gp_camera_new failed: ${_gphoto2.getResultAsString(ret)}";
      }

      _camera = cameraPtr.value;
      calloc.free(cameraPtr);

      // Attempt to init
      ret = _gphoto2.initCamera(_camera!, _cameraContext!);
      if (ret < 0) {
        final errorStr = _gphoto2.getResultAsString(ret);
        // If init fails, we should free the camera
        _gphoto2.unrefCamera(_camera!);
        _camera = null;
        return "${sb.toString()}No camera detected. Error: $ret ($errorStr)";
      }

      // If we got here, a camera was found and initialized
      _closeCamera(); // Close for now

      return "${sb.toString()}Camera Detected Successfully!";
    } catch (e) {
      return "${sb.toString()}Exception during detection: $e";
    }
  }

  void _closeCamera() {
    if (_camera != null) {
      _gphoto2.exitCamera(_camera!, _cameraContext!);
      _gphoto2.unrefCamera(_camera!);
      _camera = null;
    }
    if (_cameraContext != null) {
      _gphoto2.unrefContext(_cameraContext!);
      _cameraContext = null;
    }
  }

  Future<Uint8List?> takePicture() async {
    if (!isInitialized) return null;

    try {
      // 1. Setup Context and Camera
      _cameraContext = _gphoto2.createContext();
      final cameraPtr = calloc<Pointer<Void>>();
      _gphoto2.newCamera(cameraPtr);
      _camera = cameraPtr.value;
      calloc.free(cameraPtr);

      // 2. Init
      int ret = _gphoto2.initCamera(_camera!, _cameraContext!);
      if (ret < 0) {
        print("Camera init failed: $ret");
        _closeCamera();
        return null;
      }

      // 3. Capture
      final cameraFilePath = calloc<CameraFilePath>();
      // GP_CAPTURE_IMAGE = 0
      ret = _gphoto2.capture(
        _camera!,
        GP_CAPTURE_IMAGE,
        cameraFilePath,
        _cameraContext!,
      );

      if (ret < 0) {
        print("Capture failed: $ret");
        calloc.free(cameraFilePath);
        _closeCamera();
        return null;
      }

      // 4. Download file from camera
      // Read folder and name from struct
      // Note: We need to handle the char arrays manually if we were to look them up
      // But we just need these to pass to gp_camera_file_get

      // Let's copy strings to Dart strings just to be sure (and for debug)
      String folder = "";
      String name = "";

      // Basic extraction of null-terminated string from fixed array
      // This is a bit manual in Dart FFI without helper extensions for fixed arrays
      // But wait! We don't strictly need to extract them if we just use the struct
      // effectively. However, gp_camera_file_get takes `const char *folder, const char *file`.
      // We need to pass the strings we got back.

      // Helper to read C string from the pointer to the array
      // cameraFilePath.ref.folder is an Array<Int8>. We can get address of it.
      // But Array doesn't have address getter easily exposed on Struct fields usually?
      // Actually ffi package helps.

      // We can just cast the pointer to the struct to a pointer to char (Int8)
      // The struct layout is: name (64 bytes), folder (1024 bytes)

      // Unsafe pointer arithmetic to get the strings:
      // Name is at offset 0
      final namePtr = cameraFilePath.cast<Utf8>();
      name = namePtr.toDartString();

      // Folder is at offset 64
      final folderPtr = (cameraFilePath.cast<Int8>().elementAt(
        64,
      )).cast<Utf8>();
      folder = folderPtr.toDartString();

      print("Captured to: $folder / $name");

      // 5. Create CameraFile to hold the image
      final filePtrRef = calloc<Pointer<Void>>();
      _gphoto2.newFile(filePtrRef);
      final cameraFile = filePtrRef.value;
      calloc.free(filePtrRef);

      // 6. Get the file (download)
      ret = _gphoto2.cameraFileGet(
        _camera!,
        folder,
        name,
        GP_FILE_TYPE_NORMAL,
        cameraFile,
        _cameraContext!,
      );
      if (ret < 0) {
        print("File download failed: $ret");
        _gphoto2.unrefFile(cameraFile);
        calloc.free(cameraFilePath);
        _closeCamera();
        return null;
      }

      // 7. Get data from CameraFile
      final dataPtrRef = calloc<Pointer<Int8>>();
      final sizeRef = calloc<UnsignedLong>();

      ret = _gphoto2.getFileDataAndSize(cameraFile, dataPtrRef, sizeRef);
      if (ret < 0) {
        print("Get data failed: $ret");
        calloc.free(dataPtrRef);
        calloc.free(sizeRef);
        _gphoto2.unrefFile(cameraFile);
        calloc.free(cameraFilePath);
        _closeCamera();
        return null;
      }

      final dataPtr = dataPtrRef.value;
      final size = sizeRef.value;

      // Copy data to Dart Uint8List
      // We MUST copy because the pointer belongs to libgphoto2 internal memory managed by the GPFile
      final imageBytes = dataPtr.cast<Uint8>().asTypedList(size);
      final resultBytes = Uint8List.fromList(imageBytes); // Copy

      // 8. Clean up
      // We don't free dataPtr directly because it belongs to cameraFile
      calloc.free(dataPtrRef);
      calloc.free(sizeRef);
      _gphoto2.unrefFile(cameraFile);
      calloc.free(cameraFilePath);

      _closeCamera();

      return resultBytes;
    } catch (e) {
      print("Error in takePicture: $e");
      _closeCamera();
      return null;
    }
  }
}
