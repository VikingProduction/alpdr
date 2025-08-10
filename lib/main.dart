import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:here_sdk/here_sdk.dart';
import 'ui/scan_page.dart';
import 'ui/watchlist_page.dart';
import 'ui/navigation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser HERE SDK
  await _initializeHereSDK();

  // Initialiser les notifications
  await _initializeNotifications();

  // Demander les permissions nécessaires
  await _requestPermissions();

  runApp(const AlprApp());
}

Future<void> _initializeHereSDK() async {
  try {
    // Initialisation du contexte HERE SDK
    SdkContext.init(IsolateOrigin.main);
    print('HERE SDK initialisé avec succès');
  } catch (e) {
    print('Erreur initialisation HERE SDK: $e');
    // L'app peut fonctionner sans HERE SDK (mode dégradé)
  }
}

Future<void> _initializeNotifications() async {
  await AwesomeNotifications().initialize(
    'resource://drawable/app_icon', // Icône de l'app
    [
      NotificationChannel(
        channelKey: 'alpr_alerts',
        channelName: 'ALPR Alerts',
        channelDescription: 'Alertes de détection de plaques surveillées',
        defaultColor: const Color(0xFFFF0000),
        ledColor: Colors.red,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        playSound: true,
        enableVibration: true,
      ),
      NotificationChannel(
        channelKey: 'navigation',
        channelName: 'Navigation',
        channelDescription: 'Instructions de navigation',
        defaultColor: const Color(0xFF0078D4),
        ledColor: Colors.blue,
        importance: NotificationImportance.Default,
        playSound: false,
        enableVibration: false,
      ),
    ],
  );

  // Demander permission notifications
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });
}

Future<void> _requestPermissions() async {
  // Liste des permissions nécessaires
  Map<Permission, String> permissions = {
    Permission.camera: 'Accès à la caméra pour scanner les plaques',
    Permission.location: 'Localisation pour la navigation',
    Permission.locationWhenInUse: 'Localisation en cours d\'utilisation',
    Permission.notification: 'Notifications pour les alertes',
    Permission.storage: 'Stockage pour sauvegarder les données',
  };

  // Demander toutes les permissions
  for (MapEntry<Permission, String> entry in permissions.entries) {
    PermissionStatus status = await entry.key.request();

    if (status.isDenied) {
      print('Permission ${entry.key} refusée: ${entry.value}');
    } else if (status.isGranted) {
      print('Permission ${entry.key} accordée');
    }
  }
}

class AlprApp extends StatefulWidget {
  const AlprApp({super.key});

  @override
  State<AlprApp> createState() => _AlprAppState();
}

class _AlprAppState extends State<AlprApp> with WidgetsBindingObserver {
  int _selectedTab = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Gérer les changements d'état de l'application
    switch (state) {
      case AppLifecycleState.resumed:
        print('App resumed');
        break;
      case AppLifecycleState.inactive:
        print('App inactive');
        break;
      case AppLifecycleState.paused:
        print('App paused');
        break;
      case AppLifecycleState.detached:
        print('App detached');
        break;
      case AppLifecycleState.hidden:
        print('App hidden');
        break;
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedTab = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALPR Navigation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Thème principal
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,

        // Thème de l'AppBar
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 4,
        ),

        // Thème des boutons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(120, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // Thème des cartes
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        // Thème des champs de texte
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
        ),
      ),

      // Thème sombre
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 4,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(120, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
        ),
      ),

      // Détection automatique du thème
      themeMode: ThemeMode.system,

      home: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedTab = index;
            });
          },
          children: const [
            ScanPage(),
            WatchlistPage(),
            NavigationPage(),
          ],
        ),

        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedTab,
          onDestinationSelected: _onTabSelected,
          animationDuration: const Duration(milliseconds: 300),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.camera_alt_outlined),
              selectedIcon: const Icon(Icons.camera_alt),
              label: 'Scanner',
              tooltip: 'Scanner les plaques d\'immatriculation',
            ),
            NavigationDestination(
              icon: const Icon(Icons.list_alt_outlined),
              selectedIcon: const Icon(Icons.list_alt),
              label: 'Watchlist',
              tooltip: 'Gérer les plaques surveillées',
            ),
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map),
              label: 'Navigation',
              tooltip: 'Navigation GPS avec HERE Maps',
            ),
          ],
        ),
      ),
    );
  }
}
