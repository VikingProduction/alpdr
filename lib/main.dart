import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ui/scan_page.dart';
import 'ui/watchlist_page.dart';
import 'ui/navigation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Demander les permissions nécessaires
  await _requestPermissions();
  
  runApp(const AlprApp());
}

Future<void> _requestPermissions() async {
  await [
    Permission.camera,
    Permission.location,
    Permission.locationWhenInUse,
    Permission.notification,
  ].request();
}

class AlprApp extends StatefulWidget {
  const AlprApp({super.key});

  @override
  State<AlprApp> createState() => _AlprAppState();
}

class _AlprAppState extends State<AlprApp> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALPR Navigation',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: const [
            ScanPage(),
            WatchlistPage(),
            NavigationPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              label: 'Scanner',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt),
              label: 'Watchlist',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              label: 'Navigation',
            ),
          ],
        ),
      ),
    );
  }
}
