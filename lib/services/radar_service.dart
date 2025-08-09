import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:here_sdk/core.dart';
import 'package:geolocator/geolocator.dart';
import '../models/radar_point.dart';
import '../config/here_config.dart';

class RadarService {
  StreamController<List<RadarPoint>>? _radarController;
  StreamController<GeoCoordinates>? _locationController;
  
  List<RadarPoint> _cachedRadars = [];
  Timer? _updateTimer;
  
  Stream<List<RadarPoint>> get radarStream => 
    _radarController?.stream ?? Stream.empty();
    
  Stream<GeoCoordinates> get onLocationChanged => 
    _locationController?.stream ?? Stream.empty();

  Future<void> initialize() async {
    _radarController = StreamController<List<RadarPoint>>.broadcast();
    _locationController = StreamController<GeoCoordinates>.broadcast();
    
    // Démarrer les mises à jour périodiques
    _startPeriodicUpdates();
    
    debugPrint('Radar Service initialisé');
  }

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateCurrentLocation();
    });
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final coords = GeoCoordinates(position.latitude, position.longitude);
      _locationController?.add(coords);
      
      // Mettre à jour les radars à proximité
      await _updateNearbyRadars(coords);
      
    } catch (e) {
      debugPrint('Erreur mise à jour position: $e');
    }
  }

  Future<void> _updateNearbyRadars(GeoCoordinates location) async {
    try {
      final radars = await getNearbyRadars(location, HereConfig.radarAlertDistance);
      _cachedRadars = radars;
      _radarController?.add(radars);
    } catch (e) {
      debugPrint('Erreur mise à jour radars: $e');
    }
  }

  Future<List<RadarPoint>> getNearbyRadars(
    GeoCoordinates center, 
    double radiusMeters,
  ) async {
    try {
      // ⚠️ URL d'exemple - remplace par la vraie API HERE Safety Cameras
      final url = 'https://fleet.ls.hereapi.com/2/search/proximity.json'
          '?apikey=${HereConfig.apiKey}'
          '&layer_ids=ADAS_ATTRIB_FC1'
          '&proximity=${center.latitude},${center.longitude},$radiusMeters'
          '&attributes=SPEED_LIMIT_ATTR,CAMERA_TYPE';
          
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
          );
        }).toList();
        
      } else {
        // Fallback: données radar simulées pour test
        return _generateMockRadars(center, radiusMeters);
      }
      
    } catch (e) {
      debugPrint('Erreur API radar: $e');
      // Fallback: données radar simulées
      return _generateMockRadars(center, radiusMeters);
    }
  }

  RadarType _parseRadarType(dynamic type) {
    switch (type?.toString().toLowerCase()) {
      case 'fixed': return RadarType.fixed;
      case 'mobile': return RadarType.mobile;
      case 'section': return RadarType.section;
      case 'traffic': return RadarType.traffic;
      default: return RadarType.fixed;
    }
  }

  List<RadarPoint> _generateMockRadars(GeoCoordinates center, double radius) {
    // Données de test - remplace par vraie API
    return [
      RadarPoint(
        coordinates: GeoCoordinates(
          center.latitude + 0.001, 
          center.longitude + 0.001,
        ),
        type: RadarType.fixed,
        speedLimit: 50,
        description: 'Radar fixe - Route Nationale',
      ),
      RadarPoint(
        coordinates: GeoCoordinates(
          center.latitude - 0.002, 
          center.longitude + 0.003,
        ),
        type: RadarType.mobile,
        speedLimit: 90,
        description: 'Zone contrôle mobile',
      ),
    ];
  }

  bool isInRadarZone(GeoCoordinates position, double speedKmh) {
    for (final radar in _cachedRadars) {
      final distance = _calculateDistance(position, radar.coordinates);
      
      if (distance <= HereConfig.radarAlertDistance) {
        if (radar.speedLimit != null && 
            speedKmh > (radar.speedLimit! + HereConfig.speedTolerance)) {
          return true; // Excès de vitesse détecté
        }
        return true; // Dans zone radar
      }
    }
    return false;
  }

  double _calculateDistance(GeoCoordinates a, GeoCoordinates b) {
    return Geolocator.distanceBetween(
      a.latitude, a.longitude,
      b.latitude, b.longitude,
    );
  }

  void dispose() {
    _updateTimer?.cancel();
    _radarController?.close();
    _locationController?.close();
  }
}
