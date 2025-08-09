// Dans la méthode getNearbyRadars, change l'URL :
Future<List<RadarPoint>> getNearbyRadars(
  GeoCoordinates center, 
  double radiusMeters,
) async {
  try {
    // URL HERE Fleet Telematics avec App ID + API Key
    final url = 'https://fleet.ls.hereapi.com/2/search/proximity.json'
        '?apikey=${HereConfig.apiKey}'
        '&app_id=${HereConfig.appId}'
        '&layer_ids=ADAS_ATTRIB_FC1'
        '&proximity=${center.latitude},${center.longitude},$radiusMeters'
        '&attributes=SPEED_LIMIT_ATTR,CAMERA_TYPE';
        
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'ALPR-Navigation-Flutter/1.0',
      },
    );
    
    debugPrint('Radar API Response: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List? ?? [];
      
      debugPrint('Radars trouvés: ${results.length}');
      
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
      debugPrint('Erreur API radar: ${response.statusCode} - ${response.body}');
      return _generateMockRadars(center, radiusMeters);
    }
    
  } catch (e) {
    debugPrint('Exception API radar: $e');
    return _generateMockRadars(center, radiusMeters);
  }
}
