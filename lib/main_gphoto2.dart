import 'package:flutter/material.dart';
import 'dart:ffi';
import 'gphoto2/gphoto2_ffi.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPhoto2 Integration',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'GPhoto2 Windows Test'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _log = "Ready to test...";
  GPhoto2? _gphoto2;

  void _testIntegration() {
    setState(() {
      _log = "Initializing GPhoto2...";
    });

    try {
      _gphoto2 = GPhoto2();

      setState(() {
        _log += "\nStatus: ${_gphoto2!.statusMessage}";
      });

      if (_gphoto2!.isLoaded) {
        setState(() {
          _log += "\nAttempting to create context...";
        });

        final context = _gphoto2!.createContext();
        if (context != null && context != nullptr) {
          setState(() {
            _log += "\nSUCCESS: Context created! (Ptr: $context)";
            _log += "\nCleaning up context...";
          });
          _gphoto2!.unrefContext(context);
          setState(() {
            _log += "\nContext freed.";
          });
        } else {
          setState(() {
            _log += "\nFAILURE: Context returned null or nullptr.";
          });
        }
      }
    } catch (e) {
      setState(() {
        _log += "\nEXCEPTION: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'GPhoto2 DLL Integration Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _log,
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testIntegration,
              child: const Text('Initialize & Test DLL'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Make sure libgphoto2-6.dll and libgphoto2_port-12.dll\nare in the same folder as the executable.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
