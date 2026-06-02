import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

/// Provider για live ανίχνευση ζημιών: camera → preprocessing → TFLite → UI
class LiveDetectorProvider extends ChangeNotifier {
  Interpreter? _interpreter;           // TFLite interpreter για on-device inference
  CameraController? _cameraController; // Controller για live camera stream
  bool _isModelLoaded = false;         // Flag: μοντέλο φορτωμένο;
  bool _isCameraReady = false;         // Flag: κάμερα έτοιμη;
  String _verdict = 'Initializing...'; // Τρέχουσα ετυμηγορία (UI binding)
  double _confidence = 0.0;            // Confidence score για τρέχουσα πρόβλεψη
  int _inferenceTimeMs = 0;            // Χρόνος συμπερασμού σε ms (performance metric)

  // 🔑 Μετρητές FPS για real-time απόδοση
  int _framesProcessed = 0;
  double _currentFPS = 0.0;
  DateTime _lastFPSCalc = DateTime.now();

  DateTime _lastInference = DateTime.now(); // Throttling: τελευταία εκτέλεση inference
  static const double THRESHOLD = 0.50;     // Κατώφλι απόφασης για binary classification

  // Getters για reactive UI updates μέσω Provider
  bool get isModelLoaded => _isModelLoaded;
  bool get isCameraReady => _isCameraReady;
  String get verdict => _verdict;
  double get confidence => _confidence;
  int get inferenceTimeMs => _inferenceTimeMs;
  double get fps => _currentFPS;
  CameraController? get cameraController => _cameraController;

  /// Φόρτωση TFLite μοντέλου από assets (async, non-blocking)
  Future<void> initModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model/car_damage.tflite');
      _isModelLoaded = true;
      notifyListeners(); // Ενημέρωση UI: μοντέλο έτοιμο
    } catch (e) {
      _verdict = '❌ Model Error: $e';
      notifyListeners();
    }
  }

  /// Αρχικοποίηση κάμερας: επιλογή φακού, ρύθμιση ανάλυσης, start streaming
  Future<void> initCamera(List<CameraDescription> cameras) async {
    if (cameras.isEmpty) return;
    try {
      _cameraController = CameraController(cameras[0], ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      _isCameraReady = true;
      notifyListeners();
      _cameraController!.startImageStream(_processCameraImage); // Start YUV frame stream
    } catch (e) {
      _verdict = '❌ Camera Error: $e';
      notifyListeners();
    }
  }

  /// Κύριος βρόχος επεξεργασίας: throttling → YUV→RGB → inference → UI update → logging
  void _processCameraImage(CameraImage image) {
    // 🔑 Throttling: max 1 inference κάθε 500ms (~2 FPS) για thermal stability
    if (DateTime.now().difference(_lastInference).inMilliseconds < 500) return;
    _lastInference = DateTime.now();
    if (_interpreter == null || !_isModelLoaded) return;

    try {
      final stopwatch = Stopwatch()..start(); // Μέτρηση latency
      
      // Βήμα 1: YUV420 → RGB conversion (Android camera output format)
      final rgbImage = _convertYUV420ToRGB(image);
      if (rgbImage == null) return;

      // Βήμα 2: Resize σε 224×224 + normalization σε [0,1] + flattening σε 4D tensor
      final resized = img.copyResize(rgbImage, width: 224, height: 224);
      var input = List.generate(224, (y) =>
          List.generate(224, (x) =>
              List.generate(3, (c) {
                var pixel = resized.getPixel(x, y);
                return c == 0 ? (pixel.r ?? 0)/255.0 : c == 1 ? (pixel.g ?? 0)/255.0 : (pixel.b ?? 0)/255.0;
              })
          )
      );

      // Βήμα 3: TFLite inference → output [probability]
      var output = List<List<double>>.generate(1, (_) => List.filled(1, 0.0));
      _interpreter!.run(input, output);
      double prediction = output[0][0];

      stopwatch.stop();
      _inferenceTimeMs = stopwatch.elapsedMilliseconds; // Καταγραφή latency

      // Βήμα 4: Thresholding + UI update
      if (prediction >= THRESHOLD) {
        _verdict = '⚠️ Damage Detected';
        _confidence = prediction;
      } else {
        _verdict = '✅ No Damage';
        _confidence = 1.0 - prediction; // Αντίστροφη εμπιστοσύνη για clean class
      }

      // 🔑 FPS calculation: rolling average ανά δευτερόλεπτο
      _framesProcessed++;
      final now = DateTime.now();
      final diff = now.difference(_lastFPSCalc).inMilliseconds;
      if (diff >= 1000) {
        _currentFPS = (_framesProcessed * 1000) / diff;
        _framesProcessed = 0;
        _lastFPSCalc = now;
        notifyListeners();
      }

      _logResult(); // Async logging σε CSV για academic transparency
      notifyListeners(); // Trigger UI rebuild με νέα metrics
    } catch (e) { debugPrint("📸 Inference skipped: $e"); } // Fail-safe: skip frame on error
  }

  /// Χειροκίνητη YUV420 → RGB conversion (Android camera format compatibility)
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
          // YUV → RGB conversion formula (ITU-R BT.601)
          final r = (y + 1.402 * (v - 128)).round().clamp(0, 255);
          final g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round().clamp(0, 255);
          final b = (y + 1.772 * (u - 128)).round().clamp(0, 255);
          image.setPixelRgba(w, h, r, g, b, 255);
        }
      }
    } catch (e) { return null; } // Fail-safe: skip frame on conversion error
    return image;
  }

  /// Async logging σε τοπικό CSV: timestamp, verdict, confidence, latency
  Future<void> _logResult() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/thesis_results_live.csv');
      final exists = await file.exists();
      final row = '${DateTime.now()},$_verdict,$_confidence,$_inferenceTimeMs\n';
      if (!exists) await file.writeAsString('timestamp,verdict,confidence,ms\n'); // Header
      await file.writeAsString(row, mode: FileMode.append); // Append new result
    } catch (_) {} // Silent fail: logging is non-critical for UX
  }

  /// Cleanup: release camera & TFLite resources on provider dispose
  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }
}
