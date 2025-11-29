import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'models/trip.dart';
import 'screens/home_screen.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Geolocator.requestPermission();
  await LocationService.initialize();

  // Initialize Hive
  final appDocumentDir = await path_provider.getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  
  // Register Hive adapters
  Hive.registerAdapter(TripAdapter());
  Hive.registerAdapter(TripLocationAdapter());
  
  // Open Hive boxes
  await Hive.openBox<Trip>('trips');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracker',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        primaryColor: const Color(0xFF3F51B5), // Indigo Blue
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          secondary: const Color(0xFFFF7043), // Deep Orange
          surface: const Color(0xFFF5F5F5), // Background Light Gray
          error: const Color(0xFFD32F2F), // Error Red
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF3F51B5),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF424242)), // Dark Gray Text
          bodyMedium: TextStyle(color: Color(0xFF424242)),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
