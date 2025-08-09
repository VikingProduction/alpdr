import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here_sdk/core.dart';
import 'package:geolocator/geolocator.dart';
import '../models/radar_point.dart';
import '../config/here_config.dart';

class RadarService {
  // Streams pour radars et localisation
  final StreamController<List<RadarPoint>> _radarController = StreamController.broadcast();
  final StreamController<GeoCoordinates> _locationController = StreamController.broadcast();

  // Cache radars proches
  List<RadarPoint> _radarsProches = [];
  Timer? _timer;

  // Expose streams
  Stream<List<RadarPoint>> get radarStream => _radarController.stream;
  Stream<GeoCoordinates> get onLocationChanged => _locationController.stream;

  // Initialisation
  Future<void> initialize() async {
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _updateLocationAndRadars());
    // immédiat aussi
    await _updateLocationAndRadars();
  }

  Future<void> _updateLocationAndRadars() async {
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final coords = GeoCoordinates(position.latitude, position.longitude);
      _locationController.add(coords);
      await _fetchAndUpdateRadars(coords);
    } catch (e) {
      debugPrint('RadarService error: $e');
    }
  }

  Future<void> _fetchAndUpdateRadars(GeoCoordinates location) async {
    final radars = await getNearbyRadars(location, HereConfig.radarAlertDistance);
    _radarsProches = radars;
    _radarController.add(radars);
  }

  Future<List<RadarPoint>> getNearbyRadars(GeoCoordinates center, double radiusMeters) async {
    final url = 'https://fleet.ls.hereapi.com/2/search/proximity.json'
      '?apikey=${HereConfig.apiKey}'
      '&app_id=${HereConfig.appId}'
      '&layer_ids=ADAS_ATTRIB_FC1'
      '&proximity=${center.latitude},${center.longitude},$radiusMeters'
      '&attributes=SPEED_LIMIT_ATTR,CAMERA_TYPE';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List? ?? [];
        return results.map<RadarPoint>((item) {
          return RadarPoint(
            coordinates: GeoCoordinates(
              item['position'][0] as double,
              item['position'][1] as double,
            ),
            type: _parseRadarType(item['attributes']?['CAMERA_TYPE']),
            speedLimit: item['attributes']?['SPEED_LIMIT_ATTR'] as int?,
            description: item['title'] as String?,
            lastUpdated: DateTime.now(),
          );
        }).toList();
      } else {
        debugPrint('Erreur API radars: ${response.statusCode} ${response.body}');
        return _generateMockRadars(center, radiusMeters);
      }
    } catch (e) {
      debugPrint('Exception API radars: $e');
      return _generateMockRadars(center, radiusMeters);
    }
  }

  RadarType _parseRadarType(dynamic type) {
    if (type == null) return RadarType.fixed;
    final s = type.toString().toLowerCase();
    switch (s) {
      case 'fixed': return RadarType.fixed;
      case 'mobile': return RadarType.mobile;
      case 'section': return RadarType.section;
      case 'traffic': return RadarType.traffic;
      default: return RadarType.fixed;
    }
  }

  List<RadarPoint> _generateMockRadars(GeoCoordinates center, double radius) {
    // Données test
    return [
      RadarPoint(
        coordinates: GeoCoordinates(center.latitude + 0.001, center.longitude + 0.001),
        type: RadarType.fixed,
        speedLimit: 50,
        description: 'Radar fixe test',
      ),
      RadarPoint(
        coordinates: GeoCoordinates(center.latitude - 0.002, center.longitude + 0.002),
        type: RadarType.mobile,
        speedLimit: 80,
        description: 'Contrôle mobile test',
      ),
    ];
  }

  bool isInRadarZone(GeoCoordinates position, double currentSpeedKmh, {double radiusMetres = 1000}) {
    for (final radar in _radarsProches) {
      final dist = _calculateDistance(position, radar.coordinates);
      if (dist <= radiusMetres) {
        if (radar.speedLimit != null && currentSpeedKmh > radar.speedLimit! + HereConfig.speedTolerance) {
          return true; // excès vitesse detectionné
        }
        return true; // dans la zone radar
      }
    }
    return false;
  }

  double _calculateDistance(GeoCoordinates a, GeoCoordinates b) {
    return Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  void dispose() {
    _timer?.cancel();
    _radarController.close();
    _locationController.close();
  }
}
