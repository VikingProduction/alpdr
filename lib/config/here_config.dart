class HereConfig {
  // ⚠️ Ces valeurs seront remplacées automatiquement par le workflow CI
  static const String apiKey = 'YOUR_API_KEY_HERE';
  static const String appId = 'YOUR_APP_ID_HERE';
  
  // Configuration radar/alertes
  static const double radarAlertDistance = 1000.0; // 1km
  static const double speedTolerance = 5.0; // +5 km/h tolérance
  
  // Configuration navigation
  static const bool offlineMapsEnabled = true;
  static const String voiceLanguage = 'fr-FR';
  
  // URLs APIs HERE avec authentification
  static String get geocodingUrl => 
    'https://geocode.search.hereapi.com/v1/geocode?apikey=$apiKey';
    
  static String get routingUrl => 
    'https://router.hereapi.com/v8/routes?apikey=$apiKey';
    
  static String get safetyUrl => 
    'https://fleet.ls.hereapi.com/2/search/proximity.json?apikey=$apiKey';
}
