import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

class LiveDetectorProvider extends ChangeNotifier {
  Interpreter? _interpreter;
  CameraController? _cameraController;
  bool _isModelLoaded = false;
  bool _isCameraReady = false;
  String _verdict = 'Initializing...';
  double _confidence = 0.0;
  int _inferenceTimeMs = 0;

  // 🔑 FPS Tracking Variables
  int _framesProcessed = 0;
  double _currentFPS = 0.0;
  DateTime _lastFPSCalc = DateTime.now();

  DateTime _lastInference = DateTime.now();
  static const double THRESHOLD = 0.50;

  bool get isModelLoaded => _isModelLoaded;
  bool get isCameraReady => _isCameraReady;
  String get verdict => _verdict;
  double get confidence => _confidence;
  int get inferenceTimeMs => _inferenceTimeMs;
  double get fps => _currentFPS;
  CameraController? get cameraController => _cameraController;

  Future<void> initModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model/car_damage.tflite');
      _isModelLoaded = true;
      notifyListeners();
    } catch (e) {
      _verdict = '❌ Model Error: $e';
      notifyListeners();
    }
  }

  Future<void> initCamera(List<CameraDescription> cameras) async {
    if (cameras.isEmpty) return;
    try {
      _cameraController = CameraController(cameras[0], ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      _isCameraReady = true;
      notifyListeners();
      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      _verdict = '❌ Camera Error: $e';
      notifyListeners();
    }
  }

  void _processCameraImage(CameraImage image) {
    if (DateTime.now().difference(_lastInference).inMilliseconds < 500) return;
    _lastInference = DateTime.now();
    if (_interpreter == null || !_isModelLoaded) return;

    try {
      final stopwatch = Stopwatch()..start();
      final rgbImage = _convertYUV420ToRGB(image);
      if (rgbImage == null) return;

      final resized = img.copyResize(rgbImage, width: 224, height: 224);
      var input = List.generate(224, (y) =>
          List.generate(224, (x) =>
              List.generate(3, (c) {
                var pixel = resized.getPixel(x, y);
                return c == 0 ? (pixel.r ?? 0)/255.0
                    : c == 1 ? (pixel.g ?? 0)/255.0
                    : (pixel.b ?? 0)/255.0;
              })
          )
      );

      var output = List<List<double>>.generate(1, (_) => List.filled(1, 0.0));
      _interpreter!.run(input, output);
      double prediction = output[0][0];

      stopwatch.stop();
      _inferenceTimeMs = stopwatch.elapsedMilliseconds;

      if (prediction >= THRESHOLD) {
        _verdict = '⚠️ Damage Detected';
        _confidence = prediction;
      } else {
        _verdict = '✅ No Damage';
        _confidence = 1.0 - prediction;
      }

      // 🔑 FPS Calculation
      _framesProcessed++;
      final now = DateTime.now();
      final diff = now.difference(_lastFPSCalc).inMilliseconds;
      if (diff >= 1000) {
        _currentFPS = (_framesProcessed * 1000) / diff;
        _framesProcessed = 0;
        _lastFPSCalc = now;
        notifyListeners();
      }

      _logResult();
      notifyListeners();
    } catch (e) { debugPrint("📸 Inference skipped: $e"); }
  }

  img.Image? _convertYUV420ToRGB(CameraImage yuvImage) {
    final width = yuvImage.width; final height = yuvImage.height;
    if (width == 0 || height == 0) return null;
    final image = img.Image(width: width, height: height);
    try {
      final yPlane = yuvImage.planes[0].bytes; final uPlane = yuvImage.planes[1].bytes; final vPlane = yuvImage.planes[2].bytes;
      final yRowStride = yuvImage.planes[0].bytesPerRow; final uvRowStride = yuvImage.planes[1].bytesPerRow; final uvPixelStride = yuvImage.planes[1].bytesPerPixel!;
      for (int h = 0; h < height; h++) {
        for (int w = 0; w < width; w++) {
          final uvIndex = uvPixelStride * (w ~/ 2) + uvRowStride * (h ~/ 2);
          final index = h * yRowStride + w;
          final y = yPlane[index]; final u = uPlane[uvIndex]; final v = vPlane[uvIndex];
          final r = (y + 1.402 * (v - 128)).round().clamp(0, 255);
          final g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round().clamp(0, 255);
          final b = (y + 1.772 * (u - 128)).round().clamp(0, 255);
          image.setPixelRgba(w, h, r, g, b, 255);
        }
      }
    } catch (e) { return null; }
    return image;
  }

  Future<void> _logResult() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/thesis_results_live.csv');
      final exists = await file.exists();
      final row = '${DateTime.now()},$_verdict,$_confidence,$_inferenceTimeMs\n';
      if (!exists) await file.writeAsString('timestamp,verdict,confidence,ms\n');
      await file.writeAsString(row, mode: FileMode.append);
    } catch (_) {}
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }
}