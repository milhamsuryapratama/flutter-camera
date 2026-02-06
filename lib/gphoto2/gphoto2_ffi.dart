import 'dart:ffi';
import 'dart:io';

// Typedefs for the C functions
typedef GPContextNewC = Pointer<Void> Function();
typedef GPContextNewDart = Pointer<Void> Function();

typedef GPContextUnrefC = Void Function(Pointer<Void> context);
typedef GPContextUnrefDart = void Function(Pointer<Void> context);

// GPhoto2 Wrapper Class
class GPhoto2 {
  late DynamicLibrary _lib;
  late GPContextNewDart _gpContextNew;
  late GPContextUnrefDart _gpContextUnref;

  bool _isLoaded = false;
  String _statusMessage = "Not Initialized";

  bool get isLoaded => _isLoaded;
  String get statusMessage => _statusMessage;

  // Constructor that attempts to load the library
  GPhoto2() {
    try {
      if (Platform.isWindows) {
        // Try to load the library.
        // Note: libgphoto2-6.dll depends on libgphoto2_port-12.dll.
        // Both need to be in the same directory or in the PATH.
        // You might need to specify full path or ensure they are in build folder.
        _lib = DynamicLibrary.open('libgphoto2-6.dll');
      } else if (Platform.isMacOS) {
        // Just for safety if we accidentally run on Mac during dev
        // Assuming installed via brew or similiar if testing on mac
        // But user specifically said windows DLLs.
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

      // Lookup functions
      try {
        _gpContextNew = _lib
            .lookup<NativeFunction<GPContextNewC>>('gp_context_new')
            .asFunction();

        _gpContextUnref = _lib
            .lookup<NativeFunction<GPContextUnrefC>>('gp_context_unref')
            .asFunction();

        _isLoaded = true;
        _statusMessage = "Library Loaded Successfully";
      } catch (e) {
        _statusMessage = "Error lookig up symbols: $e";
        _isLoaded = false;
      }
    } catch (e) {
      _statusMessage =
          "Failed to load library: $e\nMake sure libgphoto2-6.dll and libgphoto2_port-12.dll are next to the executable.";
      _isLoaded = false;
    }
  }

  // Wrapper method to create a context
  Pointer<Void>? createContext() {
    if (!_isLoaded) return null;
    try {
      final context = _gpContextNew();
      return context;
    } catch (e) {
      print("Error creating context: $e");
      return null;
    }
  }

  // Wrapper method to unref/free a context
  void unrefContext(Pointer<Void> context) {
    if (!_isLoaded) return;
    _gpContextUnref(context);
  }
}
