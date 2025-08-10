import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isDetecting = false;
  bool _isScanning = false;
  final TextRecognizer _textRecognizer = TextRecognizer();

  List<String> _detectedPlates = [];
  List<String> _watchlist = [];
  String? _lastDetectedPlate;
  DateTime? _lastDetectionTime;

  // Zone de détection
  Rect? _detectionZone;
  double _zoomLevel = 1.0;
  bool _autoZoom = true;

  // Statistiques
  int _totalScanned = 0;
  int _alertsTriggered = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadWatchlist();
    _initNotifications();
  }

  Future<void> _initializeCamera() async {
    // Demander permission caméra
    if (await Permission.camera.request() != PermissionStatus.granted) {
      return;
    }

    _cameras = await availableCameras();
    if (_cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      setState(() {});

      if (mounted) {
        _startImageStream();
      }
    }
  }

  void _startImageStream() {
    if (_controller?.value.isInitialized == true) {
      _controller!.startImageStream((CameraImage image) {
        if (!_isDetecting && _isScanning) {
          _isDetecting = true;
          _detectLicensePlate(image).then((_) {
            _isDetecting = false;
          });
        }
      });
    }
  }

  Future<void> _detectLicensePlate(CameraImage image) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);

      for (TextBlock block in recognizedText.blocks) {
        String text = block.text.replaceAll(' ', '').toUpperCase();

        // Pattern français de plaque d'immatriculation
        if (_isValidLicensePlate(text)) {
          _onPlateDetected(text, block.boundingBox);
        }
      }
    } catch (e) {
      debugPrint('Erreur détection: $e');
    }
  }

  bool _isValidLicensePlate(String text) {
    // Format français: AB-123-CD ou 1234-AB-12
    RegExp regExp = RegExp(r'^[A-Z]{2}-?[0-9]{3}-?[A-Z]{2}$|^[0-9]{4}-?[A-Z]{2}-?[0-9]{2}$');
    return regExp.hasMatch(text) && text.length >= 7;
  }

  void _onPlateDetected(String plate, Rect boundingBox) {
    DateTime now = DateTime.now();

    // Éviter les détections répétées
    if (_lastDetectedPlate == plate && 
        _lastDetectionTime != null && 
        now.difference(_lastDetectionTime!).inSeconds < 3) {
      return;
    }

    setState(() {
      _lastDetectedPlate = plate;
      _lastDetectionTime = now;
      _totalScanned++;

      if (!_detectedPlates.contains(plate)) {
        _detectedPlates.insert(0, plate);
        if (_detectedPlates.length > 50) {
          _detectedPlates.removeLast();
        }
      }

      // Définir zone de détection pour auto-zoom
      if (_autoZoom) {
        _detectionZone = boundingBox;
        _adjustZoom(boundingBox);
      }
    });

    // Vérifier watchlist
    if (_watchlist.contains(plate)) {
      _triggerAlert(plate);
    }

    // Vibration légère
    _vibrate();
  }

  void _adjustZoom(Rect boundingBox) {
    // Calculer le zoom optimal basé sur la taille de la plaque détectée
    double targetZoom = 1.5;
    if (boundingBox.width < 100) targetZoom = 2.0;
    if (boundingBox.width < 50) targetZoom = 3.0;

    if (_controller != null && targetZoom != _zoomLevel) {
      _controller!.setZoomLevel(targetZoom);
      setState(() => _zoomLevel = targetZoom);
    }
  }

  void _triggerAlert(String plate) {
    setState(() => _alertsTriggered++);

    // Notification
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'alpr_alerts',
        title: '🚨 ALERTE WATCHLIST',
        body: 'Plaque surveillée détectée: $plate',
        notificationLayout: NotificationLayout.BigText,
        category: NotificationCategory.Alarm,
        wakeUpScreen: true,
        criticalAlert: true,
      ),
    );

    // Dialog d'alerte
    if (mounted) {
      _showAlertDialog(plate);
    }
  }

  void _showAlertDialog(String plate) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[900],
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.yellow, size: 32),
            SizedBox(width: 12),
            Text('ALERTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Plaque surveillée détectée:',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                plate,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _vibrate() {
    // Vibration simple (nécessite le package vibration)
    // HapticFeedback.lightImpact();
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // Conversion CameraImage vers InputImage pour ML Kit
    final camera = _cameras![0];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (sensorOrientation == 90) rotation = InputImageRotation.rotation90deg;
    else if (sensorOrientation == 180) rotation = InputImageRotation.rotation180deg;
    else if (sensorOrientation == 270) rotation = InputImageRotation.rotation270deg;
    else rotation = InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    if (format == InputImageFormat.unknown) return null;

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  Future<void> _loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _watchlist = prefs.getStringList('watchlist') ?? [];
    });
  }

  Future<void> _initNotifications() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'alpr_alerts',
          channelName: 'ALPR Alerts',
          channelDescription: 'Alertes de détection de plaques surveillées',
          defaultColor: Colors.red,
          ledColor: Colors.red,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        )
      ],
    );
  }

  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
      if (!_isScanning) {
        _controller?.setZoomLevel(1.0);
        _zoomLevel = 1.0;
        _detectionZone = null;
      }
    });
  }

  void _resetZoom() {
    if (_controller != null) {
      _controller!.setZoomLevel(1.0);
      setState(() => _zoomLevel = 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller?.value.isInitialized != true) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Vue caméra
          SizedBox.expand(
            child: CameraPreview(_controller!),
          ),

          // Overlay de détection
          if (_detectionZone != null && _isScanning)
            Positioned(
              left: _detectionZone!.left,
              top: _detectionZone!.top,
              child: Container(
                width: _detectionZone!.width,
                height: _detectionZone!.height,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

          // Zone de visée
          Center(
            child: Container(
              width: 300,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isScanning ? Colors.green : Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'ZONE DE DETECTION',
                  style: TextStyle(
                    color: _isScanning ? Colors.green : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Interface utilisateur
          SafeArea(
            child: Column(
              children: [
                // Barre du haut
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scannées: $_totalScanned',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Text(
                            'Alertes: $_alertsTriggered',
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() => _autoZoom = !_autoZoom),
                            icon: Icon(
                              _autoZoom ? Icons.zoom_in : Icons.zoom_out,
                              color: _autoZoom ? Colors.green : Colors.grey,
                            ),
                          ),
                          IconButton(
                            onPressed: _resetZoom,
                            icon: Icon(Icons.center_focus_strong, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Dernière plaque détectée
                if (_lastDetectedPlate != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _watchlist.contains(_lastDetectedPlate!) 
                          ? Colors.red 
                          : Colors.green,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Dernière détection:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          _lastDetectedPlate!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (_watchlist.contains(_lastDetectedPlate!))
                          Text(
                            '⚠️ SURVEILLÉE',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                      ],
                    ),
                  ),

                // Contrôles
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Bouton historique
                      FloatingActionButton(
                        heroTag: "history",
                        onPressed: _showHistory,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.history),
                      ),

                      // Bouton scan
                      FloatingActionButton.large(
                        heroTag: "scan",
                        onPressed: _toggleScanning,
                        backgroundColor: _isScanning ? Colors.red : Colors.green,
                        child: Icon(
                          _isScanning ? Icons.stop : Icons.play_arrow,
                          size: 32,
                        ),
                      ),

                      // Bouton paramètres
                      FloatingActionButton(
                        heroTag: "settings",
                        onPressed: _showSettings,
                        backgroundColor: Colors.grey[700],
                        child: Icon(Icons.settings),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Historique des détections',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _detectedPlates.length,
                itemBuilder: (context, index) {
                  String plate = _detectedPlates[index];
                  bool isWatched = _watchlist.contains(plate);

                  return ListTile(
                    leading: Icon(
                      isWatched ? Icons.warning : Icons.check_circle,
                      color: isWatched ? Colors.red : Colors.green,
                    ),
                    title: Text(
                      plate,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 16),
                    ),
                    trailing: isWatched ? Icon(Icons.warning, color: Colors.red) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    // TODO: Implémenter les paramètres
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Paramètres à implémenter')),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }
}
