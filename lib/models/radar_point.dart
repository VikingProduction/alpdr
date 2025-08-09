import 'package:here_sdk/core.dart';

class RadarPoint {
  final GeoCoordinates coordinates;
  final RadarType type;
  final int? speedLimit;
  final String? description;
  final DateTime? lastUpdated;

  const RadarPoint({
    required this.coordinates,
    required this.type,
    this.speedLimit,
    this.description,
    this.lastUpdated,
  });

  factory RadarPoint.fromJson(Map<String, dynamic> json) {
    return RadarPoint(
      coordinates: GeoCoordinates(
        json['latitude'] as double,
        json['longitude'] as double,
      ),
      type: RadarType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RadarType.fixed,
      ),
      speedLimit: json['speed_limit'] as int?,
      description: json['description'] as String?,
      lastUpdated: json['last_updated'] != null 
        ? DateTime.parse(json['last_updated']) 
        : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': coordinates.latitude,
    'longitude': coordinates.longitude,
    'type': type.name,
    'speed_limit': speedLimit,
    'description': description,
    'last_updated': lastUpdated?.toIso8601String(),
  };
}

enum RadarType {
  fixed,     // Radar fixe
  mobile,    // Radar mobile
  section,   // Radar de section
  traffic,   // Feu rouge
}
