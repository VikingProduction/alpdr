import 'package:flutter/material.dart';
import 'ui/scan_page.dart';
import 'ui/watchlist_page.dart';
// TODO: import 'ui/navigation_page.dart'; // À ajouter plus tard

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlprApp());
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
      title: 'ALPR Watchlist',
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
            // TODO: NavigationPage(), // À ajouter plus tard
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
            // TODO: À décommenter plus tard pour la navigation
            // NavigationDestination(
            //   icon: Icon(Icons.map_outlined),
            //   label: 'Navigation',
            // ),
          ],
        ),
      ),
    );
  }
}
