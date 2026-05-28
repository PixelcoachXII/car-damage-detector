import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/live_detector_provider.dart';
import 'screens/live_camera_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => LiveDetectorProvider()..initModel(),
      child: const CarDamageApp(),
    ),
  );
}

class CarDamageApp extends StatelessWidget {
  const CarDamageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Car Damage Detector',
      theme: ThemeData.dark().copyWith(primaryColor: Colors.blueAccent),
      home: const LiveCameraScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}