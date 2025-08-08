import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
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
  bool _busy = false;
  Timer? _throttle;
  Set<String> _watchlist = {};
  Set<String> _currentHits = {};
  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _zoom = 1.0;

  List<Rect> _candidateBoxes = [];
  List<String> _candidateTexts = [];
  Size _lastImageSize = const Size(0, 0);

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
    _throttle?.cancel();
    _controller?.dispose();
    _recognizer.close();
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
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await ctrl.initialize();
    await ctrl.setFlashMode(FlashMode.off);

    try {
      _minZoom = await ctrl.getMinZoomLevel();
      _maxZoom = await ctrl.getMaxZoomLevel();
      _zoom = max(1.0, _minZoom);
      await ctrl.setZoomLevel(_zoom);
    } catch (_) {}

    await ctrl.startImageStream(_onFrame);
    setState(() => _controller = ctrl);
  }

  void _onFrame(CameraImage image) async {
    if (_busy) return;
    if (_throttle == null) {
      _throttle = Timer(const Duration(milliseconds: 500), () => _throttle = null);
    } else if (_throttle!.isActive) {
      return;
    }

    _busy = true;
    try {
      final bb = BytesBuilder();
      for (final Plane p in image.planes) {
        bb.add(p.bytes);
      }
      final bytes = bb.toBytes();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      _lastImageSize = imageSize;

      final camera = _controller!;
      final rotation = InputImageRotationValue.fromRawValue(camera.description.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;
      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final result = await _recognizer.processImage(inputImage);

      final boxes = <Rect>[];
      final texts = <String>[];
      final candidates = <String>{};

      for (final block in result.blocks) {
        for (final line in block.lines) {
          final t = line.text;
          final found = extractPlateCandidates(t);
          if (found.isNotEmpty) {
            final bb = line.boundingBox;
            for (final cand in found) {
              candidates.add(cand);
              if (bb != null) {
                boxes.add(bb);
                texts.add(cand);
              }
            }
          }
        }
      }

      final hits = matchAgainstWatchlist(candidates, _watchlist).toSet();

      if (boxes.isNotEmpty) {
        final widths = boxes.map((r) => r.width).toList()..sort();
        final medianW = widths[widths.length ~/ 2];
        final frac = medianW / imageSize.width;
        double target = _zoom;
        if (frac < 0.25) target = (_zoom + 0.2).clamp(_minZoom, _maxZoom);
        else if (frac > 0.60) target = (_zoom - 0.2).clamp(_minZoom, _maxZoom);
        if ((target - _zoom).abs() >= 0.05) {
          _zoom = target;
          try { await _controller?.setZoomLevel(_zoom); } catch (_) {}
        }
      }

      setState(() {
        _candidateBoxes = boxes;
        _candidateTexts = texts;
        _currentHits = hits;
      });

      if (hits.isNotEmpty) {
        final now = DateTime.now();
        if (now.difference(_lastHaptic).inSeconds >= 2) {
          _lastHaptic = now;
          HapticFeedback.heavyImpact();
        }
      }
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cam = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner')),
      body: cam == null || !cam.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    CameraPreview(cam),
                    CustomPaint(
                      size: Size.infinite,
                      painter: _PlateOverlayPainter(
                        boxes: _candidateBoxes,
                        labels: _candidateTexts,
                        imageSize: _lastImageSize,
                        previewSize: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    ),
                    if (_currentHits.isNotEmpty)
                      Align(
                        alignment: Alignment.topCenter,
                        child: DangerBanner(
                          message: '${_currentHits.length} plaque(s) watchlist: ${_currentHits.join(", ")}',
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        color: Colors.black.withOpacity(0.35),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Text(
                          'Zoom: ${_zoom.toStringAsFixed(1)}  •  Cibles: ${_candidateTexts.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _PlateOverlayPainter extends CustomPainter {
  final List<Rect> boxes;
  final List<String> labels;
  final Size imageSize;
  final Size previewSize;

  _PlateOverlayPainter({
    required this.boxes,
    required this.labels,
    required this.imageSize,
    required this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    final scaleX = previewSize.width / imageSize.width;
    final scaleY = previewSize.height / imageSize.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFFFFC107);

    final textStyle = const TextStyle(color: Colors.white, fontSize: 12);

    for (int i = 0; i < boxes.length; i++) {
      final r = boxes[i];
      final mapped = Rect.fromLTRB(r.left * scaleX, r.top * scaleY, r.right * scaleX, r.bottom * scaleY);
      canvas.drawRect(mapped, paint);

      final tp = TextPainter(
        text: TextSpan(text: i < labels.length ? labels[i] : '', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: mapped.width);
      tp.paint(canvas, mapped.topLeft + const Offset(2, -14));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
