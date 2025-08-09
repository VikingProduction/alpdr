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
      // Initialiser HERE SDK avec API Key ET App ID
      await SDKOptions.withApiKeyAndAppId(
        HereConfig.apiKey, 
        HereConfig.appId,
      );
      
      _routingEngine = RoutingEngine();
      _visualNavigator = VisualNavigator();
      
      _locationController = StreamController<GeoCoordinates>.broadcast();
      _instructionController = StreamController<String>.broadcast();
      
      _setupNavigationCallbacks();
      
      _isInitialized = true;
      debugPrint('HERE Navigation Service initialisé avec App ID: ${HereConfig.appId}');
      
    } catch (e) {
      debugPrint('Erreur initialisation HERE SDK: $e');
      
      // Fallback : essayer avec seulement API Key
      try {
        await SDKOptions.withApiKey(HereConfig.apiKey);
        _routingEngine = RoutingEngine();
        _visualNavigator = VisualNavigator();
        _isInitialized = true;
        debugPrint('HERE SDK initialisé avec API Key seulement');
      } catch (e2) {
        debugPrint('Erreur fallback HERE SDK: $e2');
        rethrow;
      }
    }
  }

  void _setupNavigationCallbacks() {
    _visualNavigator.routeProgressListener = (RouteProgress progress) {
      if (progress.currentLocation != null) {
        _locationController?.add(progress.currentLocation!);
      }
    };

    _visualNavigator.maneuverNotificationListener = (String instruction) {
      _instructionController?.add(instruction);
    };
    
    _visualNavigator.routeDeviationListener = (RouteDeviation deviation) {
      debugPrint('Déviation détectée: ${deviation.currentLocation}');
    };
  }

  // Reste du code identique...
  Future<Route?> calculateRoute(GeoCoordinates destination) async {
    if (!_isInitialized) await initialize();
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final start = GeoCoordinates(position.latitude, position.longitude);
      
      final waypoints = [
        Waypoint.withDefaults(start),
        Waypoint.withDefaults(destination),
      ];

      // Configuration route avec options avancées
      final carOptions = CarOptions();
      carOptions.routeOptions.enableTolls = false; // Éviter péages
      carOptions.routeOptions.enableTrafficOptimization = true;
      
      final routingCompleter = Completer<Route?>();
      
      _routingEngine.calculateRoute(waypoints, carOptions, (error, routes) {
        if (error != null) {
          debugPrint('Erreur calcul route: $error');
          routingCompleter.complete(null);
        } else if (routes != null && routes.isNotEmpty) {
          _currentRoute = routes.first;
          debugPrint('Route calculée: ${routes.first.lengthInMeters}m');
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

  // Reste des méthodes identique...
  Future<void> startNavigation(Route route) async {
    if (!_isInitialized) return;
    
    try {
      _currentRoute = route;
      _visualNavigator.route = route;
      await _visualNavigator.startNavigation();
      debugPrint('Navigation démarrée pour ${route.lengthInMeters}m');
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
