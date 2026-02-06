import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// --- Typedefs ---

// Enums / Constants
const int GP_CAPTURE_IMAGE = 0;
const int GP_CAPTURE_MOVIE = 1;
const int GP_CAPTURE_SOUND = 2;

// Context
typedef GPContextNewC = Pointer<Void> Function();
typedef GPContextNewDart = Pointer<Void> Function();

typedef GPContextUnrefC = Void Function(Pointer<Void> context);
typedef GPContextUnrefDart = void Function(Pointer<Void> context);

// Camera
typedef GPCameraNewC = Int32 Function(Pointer<Pointer<Void>> camera);
typedef GPCameraNewDart = int Function(Pointer<Pointer<Void>> camera);

typedef GPCameraInitC =
    Int32 Function(Pointer<Void> camera, Pointer<Void> context);
typedef GPCameraInitDart =
    int Function(Pointer<Void> camera, Pointer<Void> context);

typedef GPCameraExitC =
    Int32 Function(Pointer<Void> camera, Pointer<Void> context);
typedef GPCameraExitDart =
    int Function(Pointer<Void> camera, Pointer<Void> context);

typedef GPCameraRefC = Int32 Function(Pointer<Void> camera);
typedef GPCameraRefDart = int Function(Pointer<Void> camera);

typedef GPCameraUnrefC = Int32 Function(Pointer<Void> camera);
typedef GPCameraUnrefDart = int Function(Pointer<Void> camera);

// Capture
// int gp_camera_capture (Camera *camera, CameraCaptureType type, CameraFilePath *path, GPContext *context)
// We need struct for CameraFilePath.
// For FFI, we can define a Struct which matches CameraFilePath layout.
// struct _CameraFilePath { char name[64]; char folder[1024]; };
final class CameraFilePath extends Struct {
  @Array(64)
  external Array<Int8> name;

  @Array(1024)
  external Array<Int8> folder;
}

typedef GPCameraCaptureC =
    Int32 Function(
      Pointer<Void> camera,
      Int32 captureType,
      Pointer<CameraFilePath> path,
      Pointer<Void> context,
    );
typedef GPCameraCaptureDart =
    int Function(
      Pointer<Void> camera,
      int captureType,
      Pointer<CameraFilePath> path,
      Pointer<Void> context,
    );

// File
typedef GPFileNewC = Int32 Function(Pointer<Pointer<Void>> file);
typedef GPFileNewDart = int Function(Pointer<Pointer<Void>> file);

typedef GPFileUnrefC = Int32 Function(Pointer<Void> file);
typedef GPFileUnrefDart = int Function(Pointer<Void> file);

// int gp_camera_file_get (Camera *camera, const char *folder, const char *file, CameraFileType type, CameraFile *camera_file, GPContext *context)
// type: GP_FILE_TYPE_NORMAL = 1
const int GP_FILE_TYPE_NORMAL = 1;

typedef GPCameraFileGetC =
    Int32 Function(
      Pointer<Void> camera,
      Pointer<Utf8> folder,
      Pointer<Utf8> file,
      Int32 type,
      Pointer<Void> cameraFile,
      Pointer<Void> context,
    );
typedef GPCameraFileGetDart =
    int Function(
      Pointer<Void> camera,
      Pointer<Utf8> folder,
      Pointer<Utf8> file,
      int type,
      Pointer<Void> cameraFile,
      Pointer<Void> context,
    );

// int gp_file_get_data_and_size (CameraFile *file, const char **data, unsigned long int *size)
typedef GPFileGetDataAndSizeC =
    Int32 Function(
      Pointer<Void> file,
      Pointer<Pointer<Int8>> data,
      Pointer<UnsignedLong> size,
    );
typedef GPFileGetDataAndSizeDart =
    int Function(
      Pointer<Void> file,
      Pointer<Pointer<Int8>> data,
      Pointer<UnsignedLong> size,
    );

// Port Info List
typedef GPPortInfoListNewC = Int32 Function(Pointer<Pointer<Void>> list);
typedef GPPortInfoListNewDart = int Function(Pointer<Pointer<Void>> list);

typedef GPPortInfoListLoadC = Int32 Function(Pointer<Void> list);
typedef GPPortInfoListLoadDart = int Function(Pointer<Void> list);

typedef GPPortInfoListCountC = Int32 Function(Pointer<Void> list);
typedef GPPortInfoListCountDart = int Function(Pointer<Void> list);

typedef GPPortInfoListFreeC = Int32 Function(Pointer<Void> list);
typedef GPPortInfoListFreeDart = int Function(Pointer<Void> list);

// Utilities
typedef GPResultAsStringC = Pointer<Utf8> Function(Int32 result);
typedef GPResultAsStringDart = Pointer<Utf8> Function(int result);

// --- Wrapper Class ---

class GPhoto2 {
  late DynamicLibrary _lib;
  final String _dllName = 'libgphoto2-6.dll';

  // Function pointers
  late GPContextNewDart _gpContextNew;
  late GPContextUnrefDart _gpContextUnref;

  late GPCameraNewDart _gpCameraNew;
  late GPCameraInitDart _gpCameraInit;
  late GPCameraExitDart _gpCameraExit;
  late GPCameraUnrefDart _gpCameraUnref;

  late GPCameraCaptureDart _gpCameraCapture;

  late GPFileNewDart _gpFileNew;
  late GPFileUnrefDart _gpFileUnref;
  late GPCameraFileGetDart _gpCameraFileGet;
  late GPFileGetDataAndSizeDart _gpFileGetDataAndSize;

  late GPPortInfoListNewDart _gpPortInfoListNew;
  late GPPortInfoListLoadDart _gpPortInfoListLoad;
  late GPPortInfoListCountDart _gpPortInfoListCount;
  late GPPortInfoListFreeDart _gpPortInfoListFree;

  late GPResultAsStringDart _gpResultAsString;

  bool _isLoaded = false;
  String _statusMessage = "Not Initialized";

  bool get isLoaded => _isLoaded;
  String get statusMessage => _statusMessage;

  GPhoto2() {
    _loadLibrary();
  }

  void _loadLibrary() {
    try {
      if (Platform.isWindows) {
        _lib = DynamicLibrary.open(_dllName);
      } else if (Platform.isMacOS) {
        try {
          _lib = DynamicLibrary.open('libgphoto2.dylib');
        } catch (_) {
          _statusMessage = "Mac: Could not load libgphoto2.dylib";
          return;
        }
      } else {
        _statusMessage = "Unsupported Platform";
        return;
      }

      // Context
      _gpContextNew = _lib.lookupFunction<GPContextNewC, GPContextNewDart>(
        'gp_context_new',
      );
      _gpContextUnref = _lib
          .lookupFunction<GPContextUnrefC, GPContextUnrefDart>(
            'gp_context_unref',
          );

      // Camera
      _gpCameraNew = _lib.lookupFunction<GPCameraNewC, GPCameraNewDart>(
        'gp_camera_new',
      );
      _gpCameraInit = _lib.lookupFunction<GPCameraInitC, GPCameraInitDart>(
        'gp_camera_init',
      );
      _gpCameraExit = _lib.lookupFunction<GPCameraExitC, GPCameraExitDart>(
        'gp_camera_exit',
      );
      _gpCameraUnref = _lib.lookupFunction<GPCameraUnrefC, GPCameraUnrefDart>(
        'gp_camera_unref',
      );

      // Capture
      _gpCameraCapture = _lib
          .lookupFunction<GPCameraCaptureC, GPCameraCaptureDart>(
            'gp_camera_capture',
          );

      // File
      _gpFileNew = _lib.lookupFunction<GPFileNewC, GPFileNewDart>(
        'gp_file_new',
      );
      _gpFileUnref = _lib.lookupFunction<GPFileUnrefC, GPFileUnrefDart>(
        'gp_file_unref',
      );
      _gpCameraFileGet = _lib
          .lookupFunction<GPCameraFileGetC, GPCameraFileGetDart>(
            'gp_camera_file_get',
          );
      _gpFileGetDataAndSize = _lib
          .lookupFunction<GPFileGetDataAndSizeC, GPFileGetDataAndSizeDart>(
            'gp_file_get_data_and_size',
          );

      // Port Info List
      _gpPortInfoListNew = _lib
          .lookupFunction<GPPortInfoListNewC, GPPortInfoListNewDart>(
            'gp_port_info_list_new',
          );
      _gpPortInfoListLoad = _lib
          .lookupFunction<GPPortInfoListLoadC, GPPortInfoListLoadDart>(
            'gp_port_info_list_load',
          );
      _gpPortInfoListCount = _lib
          .lookupFunction<GPPortInfoListCountC, GPPortInfoListCountDart>(
            'gp_port_info_list_count',
          );
      _gpPortInfoListFree = _lib
          .lookupFunction<GPPortInfoListFreeC, GPPortInfoListFreeDart>(
            'gp_port_info_list_free',
          );

      // Utilities
      _gpResultAsString = _lib
          .lookupFunction<GPResultAsStringC, GPResultAsStringDart>(
            'gp_result_as_string',
          );

      _isLoaded = true;
      _statusMessage = "Library Loaded Successfully";
    } catch (e) {
      _statusMessage = "Failed to load library or symbols: $e";
      _isLoaded = false;
    }
  }

  // Utilities
  String getResultAsString(int result) {
    if (!_isLoaded) return "Library not loaded";
    final ptr = _gpResultAsString(result);
    // Note: The string returned by gp_result_as_string is static/const, do not free it.
    return ptr.toDartString();
  }

  // Port operations
  int newPortInfoList(Pointer<Pointer<Void>> list) {
    if (!_isLoaded) return -1;
    return _gpPortInfoListNew(list);
  }

  int loadPortInfoList(Pointer<Void> list) {
    if (!_isLoaded) return -1;
    return _gpPortInfoListLoad(list);
  }

  int countPortInfoList(Pointer<Void> list) {
    if (!_isLoaded) return -1;
    return _gpPortInfoListCount(list);
  }

  int freePortInfoList(Pointer<Void> list) {
    if (!_isLoaded) return -1;
    return _gpPortInfoListFree(list);
  }

  Pointer<Void>? createContext() {
    if (!_isLoaded) return null;
    return _gpContextNew();
  }

  void unrefContext(Pointer<Void> context) {
    if (!_isLoaded) return;
    _gpContextUnref(context);
  }

  // Camera operations
  int newCamera(Pointer<Pointer<Void>> cameraPtr) {
    if (!_isLoaded) return -1;
    return _gpCameraNew(cameraPtr);
  }

  int initCamera(Pointer<Void> camera, Pointer<Void> context) {
    if (!_isLoaded) return -1;
    return _gpCameraInit(camera, context);
  }

  int exitCamera(Pointer<Void> camera, Pointer<Void> context) {
    if (!_isLoaded) return -1;
    return _gpCameraExit(camera, context);
  }

  int unrefCamera(Pointer<Void> camera) {
    if (!_isLoaded) return -1;
    return _gpCameraUnref(camera);
  }

  int capture(
    Pointer<Void> camera,
    int type,
    Pointer<CameraFilePath> path,
    Pointer<Void> context,
  ) {
    if (!_isLoaded) return -1;
    return _gpCameraCapture(camera, type, path, context);
  }

  int newFile(Pointer<Pointer<Void>> filePtr) {
    if (!_isLoaded) return -1;
    return _gpFileNew(filePtr);
  }

  int unrefFile(Pointer<Void> file) {
    if (!_isLoaded) return -1;
    return _gpFileUnref(file);
  }

  int cameraFileGet(
    Pointer<Void> camera,
    String folder,
    String file,
    int type,
    Pointer<Void> cameraFile,
    Pointer<Void> context,
  ) {
    if (!_isLoaded) return -1;
    final folderPtr = folder.toNativeUtf8();
    final filePtr = file.toNativeUtf8();
    try {
      return _gpCameraFileGet(
        camera,
        folderPtr,
        filePtr,
        type,
        cameraFile,
        context,
      );
    } finally {
      calloc.free(folderPtr);
      calloc.free(filePtr);
    }
  }

  int getFileDataAndSize(
    Pointer<Void> file,
    Pointer<Pointer<Int8>> data,
    Pointer<UnsignedLong> size,
  ) {
    if (!_isLoaded) return -1;
    return _gpFileGetDataAndSize(file, data, size);
  }
}
