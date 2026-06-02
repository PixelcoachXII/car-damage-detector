import 'dart:typed_data'; // Για τύπους όπως Float32List (αν απαιτηθεί)

/// Εκτελεί συμπερασμό TFLite: flat input → 4D tensor → inference → prediction
Future<List<double>> runModel(List<double> flatInput, dynamic _interpreter) async {
  
  // 1. Μετατροπή επίπεδης λίστας [224×224×3] σε 4D tensor [1, 224, 224, 3]
  // Διάταξη: [batch, height, width, channels] — απαιτούμενη από TFLite
  var inputBuffer = List<List<List<List<double>>>>.generate(1, (i) =>
      List.generate(224, (y) =>
          List.generate(224, (x) =>
              List.generate(3, (c) => flatInput[y * 224 * 3 + x * 3 + c])
          )
      )
  );

  // 2. Προετοιμασία εξόδου: [1, 1] για δυαδική ταξινόμηση (clean/damaged)
  var output = List<List<double>>.generate(1, (i) => List.filled(1, 0.0));

  // 3. Εκτέλεση συμπερασμού: ο interpreter επιστρέφει πιθανότητα κλάσης
  _interpreter!.run(inputBuffer, output);

  // Επιστροφή προβλέψεως: [confidence_score] → σύγκριση με κατώφλι 0.62
  return output[0];
}
