import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import '../models/radar_point.dart';

class RadarOverlay extends StatelessWidget {
  final List<RadarPoint> radars;
  final GeoCoordinates? currentLocation;
  final Function(RadarPoint)? onRadarTapped;

  const RadarOverlay({
    super.key,
    required this.radars,
    this.currentLocation,
    this.onRadarTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Alertes radar en haut
        if (radars.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 16,
            right: 16,
            child: _buildRadarAlerts(context),
          ),
        
        // Indicateurs radar sur la carte (simulés)
        ...radars.asMap().entries.map((entry) {
          final index = entry.key;
          final radar = entry.value;
          return _buildRadarIndicator(context, radar, index);
        }),
      ],
    );
  }

  Widget _buildRadarAlerts(BuildContext context) {
    final nearbyRadars = _getNearbyRadars();
    
    if (nearbyRadars.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.red.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(
                  '⚠️ RADAR DÉTECTÉ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...nearbyRadars.map((radar) => _buildRadarInfo(context, radar)),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarInfo(BuildContext context, RadarPoint radar) {
    final distance = currentLocation != null 
      ? _calculateDistance(currentLocation!, radar.coordinates).round()
      : 0;

    String radarTypeText = '';
    IconData radarIcon = Icons.speed;
    Color iconColor = Colors.orange;

    switch (radar.type) {
      case RadarType.fixed:
        radarTypeText = 'RADAR FIXE';
        radarIcon = Icons.videocam;
        iconColor = Colors.red;
        break;
      case RadarType.mobile:
        radarTypeText = 'CONTRÔLE MOBILE';
        radarIcon = Icons.local_police;
        iconColor = Colors.orange;
        break;
      case RadarType.section:
        radarTypeText = 'RADAR SECTION';
        radarIcon = Icons.straighten;
        iconColor = Colors.purple;
        break;
      case RadarType.traffic:
        radarTypeText = 'FEU ROUGE';
        radarIcon = Icons.traffic;
        iconColor = Colors.amber;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(radarIcon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  radarTypeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'À ${distance}m • ${radar.speedLimit ?? "?"} km/h',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarIndicator(BuildContext context, RadarPoint radar, int index) {
    // Position simulée sur l'écran (en réalité, il faudrait convertir 
    // les coordonnées géographiques en coordonnées écran)
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Position pseudo-aléatoire basée sur l'index
    final left = (screenWidth * 0.2) + (index * 100.0) % (screenWidth * 0.6);
    final top = (screenHeight * 0.3) + (index * 80.0) % (screenHeight * 0.4);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => onRadarTapped?.call(radar),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getRadarColor(radar.type).withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getRadarIcon(radar.type),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  List<RadarPoint> _getNearbyRadars() {
    if (currentLocation == null) return [];
    
    return radars.where((radar) {
      final distance = _calculateDistance(currentLocation!, radar.coordinates);
      return distance <= 1000; // 1km
    }).toList();
  }

  double _calculateDistance(GeoCoordinates a, GeoCoordinates b) {
    // Formule de Haversine simplifiée
    const double earthRadius = 6371000; // mètres
    final double lat1Rad = a.latitude * (3.14159 / 180);
    final double lat2Rad = b.latitude * (3.14159 / 180);
    final double deltaLat = (b.latitude - a.latitude) * (3.14159 / 180);
    final double deltaLon = (b.longitude - a.longitude) * (3.14159 / 180);
    
    final double a1 = (deltaLat / 2) * (deltaLat / 2) +
        lat1Rad * lat2Rad * (deltaLon / 2) * (deltaLon / 2);
        
    final double c = 2 * (a1 < 1 ? a1 : 1 - a1);
    
    return earthRadius * c;
  }

  Color _getRadarColor(RadarType type) {
    switch (type) {
      case RadarType.fixed:
        return Colors.red;
      case RadarType.mobile:
        return Colors.orange;
      case RadarType.section:
        return Colors.purple;
      case RadarType.traffic:
        return Colors.amber;
    }
  }

  IconData _getRadarIcon(RadarType type) {
    switch (type) {
      case RadarType.fixed:
        return Icons.videocam;
      case RadarType.mobile:
        return Icons.local_police;
      case RadarType.section:
        return Icons.straighten;
      case RadarType.traffic:
        return Icons.traffic;
    }
  }
}
