import 'dart:async';
import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart';
import 'package:geolocator/geolocator.dart';
import '../config/here_config.dart';

class HereNavigationService {
  late RoutingEngine _routingEngine;
  late VisualNavigator _visualNavigator;
  
  StreamController<GeoCoordinates>? _locationController;
  StreamController<String>? _instructionController;
  
  bool _isInitialized = false;
  Route? _currentRoute;

  Stream<GeoCoordinates> get locationStream => 
    _locationController?.stream ?? Stream.empty();
    
  Stream<String> get instructionStream => 
    _instructionController?.stream ?? Stream.empty();

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialiser HERE SDK
      await SDKOptions.withApiKey(HereConfig.apiKey);
      
      _routingEngine = RoutingEngine();
      _visualNavigator = VisualNavigator();
      
      _locationController = StreamController<GeoCoordinates>.broadcast();
      _instructionController = StreamController<String>.broadcast();
      
      // Configuration des callbacks navigation
      _setupNavigationCallbacks();
      
      _isInitialized = true;
      debugPrint('HERE Navigation Service initialisé');
      
    } catch (e) {
      debugPrint('Erreur initialisation HERE SDK: $e');
      rethrow;
    }
  }

  void _setupNavigationCallbacks() {
    _visualNavigator.routeProgressListener = (RouteProgress progress) {
      // Emission de la position courante
      if (progress.currentLocation != null) {
        _locationController?.add(progress.currentLocation!);
      }
    };

    _visualNavigator.maneuverNotificationListener = (String instruction) {
      _instructionController?.add(instruction);
    };
  }

  Future<Route?> calculateRoute(GeoCoordinates destination) async {
    if (!_isInitialized) await initialize();
    
    try {
      final position = await Geolocator.getCurrentPosition();
      final start = GeoCoordinates(position.latitude, position.longitude);
      
      final waypoints = [
        Waypoint.withDefaults(start),
        Waypoint.withDefaults(destination),
      ];

      final routingCompleter = Completer<Route?>();
      
      _routingEngine.calculateRoute(waypoints, CarOptions(), (error, routes) {
        if (error != null) {
          debugPrint('Erreur calcul route: $error');
          routingCompleter.complete(null);
        } else if (routes != null && routes.isNotEmpty) {
          _currentRoute = routes.first;
          routingCompleter.complete(routes.first);
        } else {
          routingCompleter.complete(null);
        }
      });

      return await routingCompleter.future;
      
    } catch (e) {
      debugPrint('Erreur calcul route: $e');
      return null;
    }
  }

  Future<void> startNavigation(Route route) async {
    if (!_isInitialized) return;
    
    try {
      _currentRoute = route;
      _visualNavigator.route = route;
      await _visualNavigator.startNavigation();
      debugPrint('Navigation démarrée');
    } catch (e) {
      debugPrint('Erreur démarrage navigation: $e');
    }
  }

  Future<void> stopNavigation() async {
    try {
      await _visualNavigator.stopNavigation();
      _currentRoute = null;
      debugPrint('Navigation arrêtée');
    } catch (e) {
      debugPrint('Erreur arrêt navigation: $e');
    }
  }

  Future<GeoCoordinates?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return GeoCoordinates(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Erreur localisation: $e');
      return null;
    }
  }

  void dispose() {
    _locationController?.close();
    _instructionController?.close();
    _visualNavigator.dispose();
    _routingEngine.dispose();
  }
}
