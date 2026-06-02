import 'package:flutter/material.dart';        // Core Flutter UI framework
import 'package:provider/provider.dart';        // State management via ChangeNotifier
import 'providers/live_detector_provider.dart'; // Business logic: camera + TFLite inference
import 'screens/live_camera_screen.dart';       // UI: live camera preview + overlay

/// Entry point: initializes Provider + preloads TFLite model before UI launch
void main() {
  runApp(
    ChangeNotifierProvider(                   // Global state management wrapper
      create: (_) => LiveDetectorProvider()..initModel(), // Preload model async
      child: const CarDamageApp(),            // Root widget
    ),
  );
}

/// Root application widget: configures MaterialApp theme & entry screen
class CarDamageApp extends StatelessWidget {
  const CarDamageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Car Damage Detector',      // App title (task switcher)
      theme: ThemeData.dark().copyWith(       // Dark theme + custom accent
        primaryColor: Colors.blueAccent,      // Brand color for buttons/indicators
      ),
      home: const LiveCameraScreen(),         // Entry screen: live camera + inference UI
      debugShowCheckedModeBanner: false,      // Hide "DEBUG" banner for production polish
    );
  }
}
