import 'package:image/image.dart' as img;

/// Προεπεξεργασία εικόνας για TFLite (EfficientNet-B0).
class ImageProcessor {
  static const int inputSize = 224; // Μέγεθος εισόδου μοντέλου

  /// Επιστρέφει κανονικοποιημένη λίστα [R/255, G/255, B/255, ...] έτοιμη για TFLite.
  static List<double> preprocess(img.Image image) {
    // Αλλαγή μεγέθους σε 224×224 με bilinear interpolation
    final resized = img.copyResize(image, width: inputSize, height: inputSize);
    final buffer = <double>[];

    // Κανονικοποίηση pixel σε [0, 1] και flattening σε row-major RGB διάταξη
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        buffer.add(pixel.r / 255.0); // R
        buffer.add(pixel.g / 255.0); // G
        buffer.add(pixel.b / 255.0); // B
      }
    }
    return buffer; // Flattened tensor: [224×224×3]
  }
}
