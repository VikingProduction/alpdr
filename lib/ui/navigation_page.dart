import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import '../services/here_navigation_service.dart';
import '../services/radar_service.dart';
import '../models/radar_point.dart';
import 'radar_overlay.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  HereMapController? _mapController;
  HereNavigationService? _navigationService;
  RadarService? _radarService;
  
  bool _isNavigating = false;
  String _currentInstruction = '';
  List<RadarPoint> _nearbyRadars = [];
  GeoCoordinates? _currentLocation;
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeNotifications();
  }

  Future<void> _initializeServices() async {
    _navigationService = HereNavigationService();
    _radarService = RadarService();
    
    await _navigationService!.initialize();
    await _radarService!.initialize();
    
    _setupListeners();
  }

  void _setupListeners() {
    // Écouter les instructions de navigation
    _navigationService!.instructionStream.listen((instruction) {
      setState(() {
        _currentInstruction = instruction;
      });
    });

    // Écouter les changements de position
    _radarService!.onLocationChanged.listen((location) {
      setState(() {
        _currentLocation = location;
      });
    });

    // Écouter les radars à proximité
    _radarService!.radarStream.listen((radars) {
      setState(() {
        _nearbyRadars = radars;
      });
      _checkRadarAlerts(radars);
    });
  }

  Future<void> _initializeNotifications() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'radar_alerts',
          channelName: 'Alertes Radar',
          channelDescription: 'Notifications pour les radars et contrôles',
          defaultColor: Colors.red,
          importance: NotificationImportance.High,
          playSound: true,
        ),
      ],
    );
  }

  void _checkRadarAlerts(List<RadarPoint> radars) {
    for (final radar in radars) {
      if (_currentLocation != null) {
        final distance = _calculateDistance(_currentLocation!, radar.coordinates);
        
        if (distance <= 500) { // 500m avant radar
          _showRadarAlert(radar, distance);
        }
      }
    }
  }

  void _showRadarAlert(RadarPoint radar, double distance) {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: radar.hashCode,
        channelKey: 'radar_alerts',
        title: '⚠️ ${radar.type.name.toUpperCase()} DÉTECTÉ',
        body: 'À ${distance.round()}m - Limite: ${radar.speedLimit ?? '?'} km/h',
        notificationLayout: NotificationLayout.Default,
        autoDismissible: false,
      ),
    );
  }

  double _calculateDistance(GeoCoordinates a, GeoCoordinates b) {
    // Formule de Haversine simplifiée
    const double earthRadius = 6371000; // mètres
    final double lat1Rad = a.latitude * (3.14159 / 180);
    final double lat2Rad = b.latitude * (3.14159 / 180);
    final double deltaLat = (b.latitude - a.latitude) * (3.14159 / 180);
    final double deltaLon = (b.longitude - a.longitude) * (3.14159 / 180);
    
    final double a1 = (deltaLat / 2).sin() * (deltaLat / 2).sin() +
        lat1Rad.cos() * lat2Rad.cos() *
        (deltaLon / 2).sin() * (deltaLon / 2).sin();
        
    final double c = 2 * (a1.sqrt()).atan2((1 - a1).sqrt());
    
    return earthRadius * c;
  }

  void _onMapCreated(HereMapController mapController) {
    _mapController = mapController;
    _setupMap();
  }

  void _setupMap() {
    if (_mapController == null) return;
    
    // Configuration initiale de la carte
    _mapController!.mapScene.loadScene(MapStyle.normalDay, (error) {
      if (error != null) {
        debugPrint('Erreur chargement carte: $error');
      } else {
        debugPrint('Carte chargée avec succès');
      }
    });
  }

  Future<void> _startNavigationToDestination() async {
    // Exemple : navigation vers Paris
    final destination = GeoCoordinates(48.8566, 2.3522);
    
    final route = await _navigationService!.calculateRoute(destination);
    if (route != null) {
      await _navigationService!.startNavigation(route);
      setState(() {
        _isNavigating = true;
      });
      
      // Afficher la route sur la carte
      _displayRouteOnMap(route);
    }
  }

  void _displayRouteOnMap(Route route) {
    if (_mapController == null) return;
    
    // Création de la polyligne pour la route
    final polyline = MapPolyline(route.geometry, 12, Colors.blue);
    _mapController!.mapScene.addMapPolyline(polyline);
    
    // Centrer la carte sur la route
    final bbox = route.boundingBox;
    _mapController!.camera.lookAtAreaWithGeoOrientationAndViewRectangle(
      bbox, 
      GeoOrientationUpdate.withDefaults(), 
      Rectangle2D.withOriginAndSize(Point2D(0, 0), Size2D(100, 100)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Carte HERE Maps
          HereMap(onMapCreated: _onMapCreated),
          
          // Overlay des alertes radar
          if (_nearbyRadars.isNotEmpty)
            RadarOverlay(
              radars: _nearbyRadars,
              currentLocation: _currentLocation,
            ),
          
          // Interface de navigation
          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: NavigationInfoCard(
                instruction: _currentInstruction,
                onStopNavigation: _stopNavigation,
              ),
            ),
          
          // Contrôles
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton.extended(
                  onPressed: _startNavigationToDestination,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigation'),
                ),
                FloatingActionButton(
                  onPressed: _centerOnLocation,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _centerOnLocation() async {
    final location = await _navigationService!.getCurrentLocation();
    if (location != null && _mapController != null) {
      _mapController!.camera.lookAtPointWithDistance(location, 1000);
    }
  }

  void _stopNavigation() async {
    await _navigationService!.stopNavigation();
    setState(() {
      _isNavigating = false;
      _currentInstruction = '';
    });
  }

  @override
  void dispose() {
    _navigationService?.dispose();
    _radarService?.dispose();
    super.dispose();
  }
}

class NavigationInfoCard extends StatelessWidget {
  final String instruction;
  final VoidCallback onStopNavigation;

  const NavigationInfoCard({
    super.key,
    required this.instruction,
    required this.onStopNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.navigation, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                instruction.isNotEmpty ? instruction : 'Calcul en cours...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            IconButton(
              onPressed: onStopNavigation,
              icon: const Icon(Icons.stop, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
