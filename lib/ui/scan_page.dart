import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../plate_matcher.dart';
import '../watchlist_store.dart';
import 'widgets.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  CameraController? _controller;
  late final TextRecognizer _recognizer;
  bool _isProcessing = false;
  Timer? _shotTimer;
  Set<String> _watchlist = {};
  String? _lastHit;
  DateTime _lastHitAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shotTimer?.cancel();
    _controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _shotTimer?.cancel();
      cam.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _init() async {
    _watchlist = await WatchlistStore().load();
    await _initCamera();
    setState(() {});
  }

  Future<void> _initCamera() async {
    final cams = await availableCameras();
    final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
    final ctrl = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await ctrl.initialize();
    await ctrl.setFlashMode(FlashMode.off);
    setState(() => _controller = ctrl);

    // Démarre la capture périodique (1 image / seconde)
    _shotTimer?.cancel();
    _shotTimer = Timer.periodic(const Duration(seconds: 1), (_) => _captureAndProcess());
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing) return;
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;

    _isProcessing = true;
    try {
      final shot = await cam.takePicture();
      final inputImage = InputImage.fromFilePath(shot.path);
      final result = await _recognizer.processImage(inputImage);

      final buffer = StringBuffer();
      for (final block in result.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
          for (final el in line.elements) {
            buffer.writeln(el.text);
          }
        }
      }
      final text = buffer.toString();
      final cands = extractPlateCandidates(text);

      final hits = matchAgainstWatchlist(cands, _watchlist);
      if (hits.isNotEmpty) {
        final now = DateTime.now();
        final sameAsBefore = _lastHit != null && hits.first == _lastHit && now.difference(_lastHitAt).inSeconds < 3;
        if (!sameAsBefore) {
          _lastHit = hits.first;
          _lastHitAt = now;
          if (mounted) {
            HapticFeedback.heavyImpact();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Correspondance: ${hits.join(', ')}')),
              );
            }
            setState(() {});
          }
        }
      }
    } catch (e) {
      // ignore
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cam = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner')),
      body: cam == null || !cam.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CameraPreview(cam),
                if (_lastHit != null && DateTime.now().difference(_lastHitAt).inSeconds < 3)
                  Align(
                    alignment: Alignment.topCenter,
                    child: DangerBanner(message: 'PLAQUE SURVEILLÉE DÉTECTÉE: $_lastHit'),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: const Text(
                      'Cadrez la plaque à ~1–3 m. Luminosité suffisante = meilleurs résultats.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
