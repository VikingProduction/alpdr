import 'package:flutter/material.dart';
import 'package:here_sdk/here_sdk.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  HereMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;

  // Navigation
  bool _isNavigating = false;
  MapRoute? _currentRoute;
  GeoCoordinates? _destination;
  String _destinationAddress = '';

  // Contrôleurs de recherche
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;

  // Paramètres de carte
  double _zoomLevel = 15.0;
  bool _followUser = true;
  bool _trafficEnabled = true;
  MapScheme _mapScheme = MapScheme.normalDay;

  // Services HERE SDK
  SearchEngine? _searchEngine;
  RoutingEngine? _routingEngine;

  // Marqueurs
  List<MapMarker> _markers = [];

  // États de l'application
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeHereSDK();
    _checkLocationPermission();
  }

  Future<void> _initializeHereSDK() async {
    try {
      // Initialisation du SDK HERE (placeholder)
      SdkContext.init(IsolateOrigin.main);

      // Initialiser les services
      _searchEngine = SearchEngine();
      _routingEngine = RoutingEngine();

      setState(() {
        _statusMessage = 'HERE SDK initialisé';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Erreur initialisation HERE SDK: $e';
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage = 'Permission de localisation refusée définitivement';
      });
      return;
    }

    if (permission == LocationPermission.whileInUse || 
        permission == LocationPermission.always) {
      _startLocationUpdates();
    }
  }

  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });

      if (_followUser && _mapController != null) {
        _centerMapOnUser();
      }
    });
  }

  void _onMapCreated(HereMapController controller) {
    _mapController = controller;

    // Configuration initiale de la carte
    _mapController!.mapScene.loadSceneForMapScheme(_mapScheme, (MapError? error) {
      if (error == null) {
        setState(() {
          _statusMessage = 'Carte chargée';
        });
        _centerMapOnUser();
      } else {
        setState(() {
          _statusMessage = 'Erreur de chargement: ${error.toString()}';
        });
      }
    });
  }

  void _centerMapOnUser() {
    if (_currentPosition != null && _mapController != null) {
      GeoCoordinates userLocation = GeoCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      _mapController!.camera.lookAtPointWithDistance(
        userLocation,
        1000, // distance en mètres
      );

      // Ajouter marqueur de position utilisateur
      _addUserMarker(userLocation);
    }
  }

  void _addUserMarker(GeoCoordinates location) {
    // Supprimer ancien marqueur utilisateur
    _markers.removeWhere((marker) => marker.metadata?['type'] == 'user');

    // Créer nouveau marqueur utilisateur
    MapImage mapImage = MapImage.withFilePathAndWidthAndHeight(
      'assets/user_marker.png', // Vous devrez ajouter cette image
      64, 64,
    );

    MapMarker userMarker = MapMarker(location, mapImage);
    userMarker.metadata = {'type': 'user'};

    _markers.add(userMarker);
    _mapController?.mapScene.addMapMarker(userMarker);
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty || _searchEngine == null) return;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    try {
      // Centrer la recherche autour de la position actuelle
      GeoCoordinates? searchCenter;
      if (_currentPosition != null) {
        searchCenter = GeoCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }

      TextQuery textQuery = TextQuery.withAreaCenter(query, searchCenter ?? GeoCoordinates(48.8566, 2.3522));
      SearchOptions searchOptions = SearchOptions(
        languageCode: LanguageCode.frFr,
        maxItems: 10,
      );

      _searchEngine!.search(textQuery, searchOptions, (SearchError? error, List<Place>? results) {
        setState(() {
          _isSearching = false;
          if (error == null && results != null) {
            _searchResults = results.map((place) => SearchResult(
              title: place.title,
              address: place.address.addressText,
              coordinates: place.geoCoordinates!,
            )).toList();
          } else {
            _statusMessage = 'Erreur de recherche: ${error?.toString()}';
          }
        });
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _statusMessage = 'Erreur de recherche: $e';
      });
    }
  }

  Future<void> _navigateToDestination(GeoCoordinates destination, String address) async {
    if (_currentPosition == null || _routingEngine == null) {
      _showMessage('Position actuelle non disponible');
      return;
    }

    setState(() {
      _isLoading = true;
      _destination = destination;
      _destinationAddress = address;
    });

    try {
      GeoCoordinates startLocation = GeoCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      List<Waypoint> waypoints = [
        Waypoint(startLocation),
        Waypoint(destination),
      ];

      CarOptions carOptions = CarOptions();
      carOptions.routeOptions.enableTrafficOptimization = _trafficEnabled;
      carOptions.routeOptions.alternatives = 2;

      _routingEngine!.calculateCarRoute(waypoints, carOptions, (RoutingError? error, List<Route>? routes) {
        setState(() => _isLoading = false);

        if (error == null && routes != null && routes.isNotEmpty) {
          _displayRoute(routes.first);
          _addDestinationMarker(destination, address);
          setState(() {
            _isNavigating = true;
            _statusMessage = 'Navigation vers $address';
          });
        } else {
          _showMessage('Impossible de calculer l\'itinéraire');
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Erreur de navigation: $e';
      });
    }
  }

  void _displayRoute(Route route) {
    // Supprimer l'ancienne route
    if (_currentRoute != null) {
      _mapController?.mapScene.removeMapRoute(_currentRoute!);
    }

    // Créer la nouvelle route
    MapRouteStyle routeStyle = MapRouteStyle();
    routeStyle.setColor(MapRouteColor.traffic, Color(0xFF0078D4));
    routeStyle.setColor(MapRouteColor.route, Color(0xFF0078D4));
    routeStyle.setWidthInPixels(MapRouteColor.route, 10);

    _currentRoute = MapRoute(route);
    _currentRoute!.style = routeStyle;

    _mapController?.mapScene.addMapRoute(_currentRoute!);

    // Adapter le zoom pour voir toute la route
    _mapController?.camera.lookAtAreaWithGeoOrientationAndViewRectangle(
      route.boundingBox,
      GeoOrientationUpdate(0, 0), 
      Rectangle2D.make(0, 0, 
        MediaQuery.of(context).size.width, 
        MediaQuery.of(context).size.height * 0.7),
    );
  }

  void _addDestinationMarker(GeoCoordinates location, String title) {
    // Supprimer ancien marqueur de destination
    _markers.removeWhere((marker) => marker.metadata?['type'] == 'destination');

    // Créer marqueur de destination
    MapImage mapImage = MapImage.withFilePathAndWidthAndHeight(
      'assets/destination_marker.png', // Vous devrez ajouter cette image
      64, 64,
    );

    MapMarker destinationMarker = MapMarker(location, mapImage);
    destinationMarker.metadata = {'type': 'destination', 'title': title};

    _markers.add(destinationMarker);
    _mapController?.mapScene.addMapMarker(destinationMarker);
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _destination = null;
      _destinationAddress = '';
      _statusMessage = 'Navigation arrêtée';
    });

    // Supprimer la route et les marqueurs
    if (_currentRoute != null) {
      _mapController?.mapScene.removeMapRoute(_currentRoute!);
      _currentRoute = null;
    }

    _markers.removeWhere((marker) => marker.metadata?['type'] == 'destination');
    _mapController?.mapScene.removeMapMarkers(_markers.where((m) => m.metadata?['type'] == 'destination').toList());

    _centerMapOnUser();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _changeMapScheme() {
    List<MapScheme> schemes = [
      MapScheme.normalDay,
      MapScheme.normalNight,
      MapScheme.satelliteDay,
      MapScheme.terrainDay,
    ];

    int currentIndex = schemes.indexOf(_mapScheme);
    int nextIndex = (currentIndex + 1) % schemes.length;

    setState(() {
      _mapScheme = schemes[nextIndex];
    });

    _mapController?.mapScene.loadSceneForMapScheme(_mapScheme, (MapError? error) {
      if (error != null) {
        _showMessage('Erreur changement de carte');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Carte HERE
          _mapController != null 
            ? HereMap(onMapCreated: _onMapCreated)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[100]!, Colors.blue[300]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Chargement HERE Maps...'),
                    ],
                  ),
                ),
              ),

          // Interface utilisateur
          SafeArea(
            child: Column(
              children: [
                // Barre de recherche
                Container(
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une destination...',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _isSearching 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults.clear());
                              },
                              icon: Icon(Icons.clear),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    onChanged: (value) {
                      if (value.length > 2) {
                        _searchLocation(value);
                      } else {
                        setState(() => _searchResults.clear());
                      }
                    },
                  ),
                ),

                // Résultats de recherche
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: Icon(Icons.location_on, color: Colors.blue),
                          title: Text(result.title),
                          subtitle: Text(result.address),
                          onTap: () {
                            _navigateToDestination(result.coordinates, result.title);
                            setState(() => _searchResults.clear());
                            _searchController.clear();
                          },
                        );
                      },
                    ),
                  ),

                Spacer(),

                // Panneau de navigation
                if (_isNavigating)
                  Container(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.navigation, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Navigation vers:',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              onPressed: _stopNavigation,
                              icon: Icon(Icons.stop, color: Colors.white),
                            ),
                          ],
                        ),
                        Text(
                          _destinationAddress,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Contrôles de carte
                Container(
                  margin: EdgeInsets.only(right: 16, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FloatingActionButton.small(
                        heroTag: "location",
                        onPressed: () {
                          setState(() => _followUser = !_followUser);
                          if (_followUser) _centerMapOnUser();
                        },
                        backgroundColor: _followUser ? Colors.blue : Colors.grey,
                        child: Icon(Icons.my_location),
                      ),
                      SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "map_type",
                        onPressed: _changeMapScheme,
                        backgroundColor: Colors.grey[700],
                        child: Icon(Icons.layers),
                      ),
                      SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "traffic",
                        onPressed: () {
                          setState(() => _trafficEnabled = !_trafficEnabled);
                          _showMessage(_trafficEnabled ? 'Trafic activé' : 'Trafic désactivé');
                        },
                        backgroundColor: _trafficEnabled ? Colors.red : Colors.grey,
                        child: Icon(Icons.traffic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Indicateur de chargement
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Calcul de l\'itinéraire...'),
                    ],
                  ),
                ),
              ),
            ),

          // Barre de statut
          if (_statusMessage.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

class SearchResult {
  final String title;
  final String address;
  final GeoCoordinates coordinates;

  SearchResult({
    required this.title,
    required this.address,
    required this.coordinates,
  });
}
