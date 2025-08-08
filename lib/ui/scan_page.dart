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
  Timer? _throttle;
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
    _controller?.dispose();
    _recognizer.close();
    _throttle?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.stopImageStream();
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
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await ctrl.initialize();
    await ctrl.setFlashMode(FlashMode.off);
    await ctrl.startImageStream(_onFrame);
    setState(() => _controller = ctrl);
  }

  void _onFrame(CameraImage image) {
    if (_isProcessing) return;
    _isProcessing = true;

    // Throttle: 2 fps max
    _throttle ??= Timer(const Duration(milliseconds: 500), () => _throttle = null);
    if (_throttle!.isActive) {
      _isProcessing = false;
      return;
    }

    _processImage(image).whenComplete(() => _isProcessing = false);
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final camera = _controller!;
      final imageRotation = InputImageRotationValue.fromRawValue(camera.description.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      final planeData = image.planes.map(
        (Plane plane) => InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        ),
      ).toList();

      final inputImageData = InputImageData(
        size: imageSize,
        imageRotation: imageRotation,
        inputImageFormat: inputImageFormat,
        planeData: planeData,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

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
      // ignore frame errors
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
