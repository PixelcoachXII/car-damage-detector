import 'package:image/image.dart' as img;

class ImageProcessor {
  static const int inputSize = 224; // Standard size for EfficientNet/ResNet

  /// Converts a picked image into a Float32List compatible with TFLite
  static List<double> preprocess(img.Image image) {
    final resized = img.copyResize(image, width: inputSize, height: inputSize);
    final buffer = <double>[];

    // Normalize pixels to [0, 1] range
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        buffer.add(pixel.r / 255.0);
        buffer.add(pixel.g / 255.0);
        buffer.add(pixel.b / 255.0);
      }
    }
    return buffer;
  }
}