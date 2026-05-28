import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../providers/live_detector_provider.dart';

class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({super.key});
  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  late List<CameraDescription> _cameras;
  @override
  void initState() {
    super.initState();
    _setupCamera();
  }
  Future<void> _setupCamera() async {
    WidgetsFlutterBinding.ensureInitialized();
    _cameras = await availableCameras();
    final provider = Provider.of<LiveDetectorProvider>(context, listen: false);
    await provider.initCamera(_cameras);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<LiveDetectorProvider>(
        builder: (context, provider, child) {
          if (!provider.isCameraReady || !provider.isModelLoaded) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          return Stack(
            children: [
              CameraPreview(provider.cameraController!),
              Positioned(
                bottom: 40, left: 20, right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.verdict,
                        style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold,
                          color: provider.verdict.contains('Damage') ? Colors.redAccent : Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Confidence: ${(provider.confidence * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(color: Colors.white, fontSize: 15)),
                          // 🔑 FPS DISPLAYED HERE
                          Text('${provider.inferenceTimeMs}ms | ${provider.fps.toStringAsFixed(1)} FPS',
                              style: const TextStyle(color: Colors.cyan, fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}