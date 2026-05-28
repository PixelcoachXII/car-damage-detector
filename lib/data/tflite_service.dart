import 'dart:typed_data'; // Only needed if using Float32List

Future<List<double>> runModel(List<double> flatInput, dynamic _interpreter) async {
  // 1. Format input to [1, 224, 224, 3]
  var inputBuffer = List<List<List<List<double>>>>.generate(1, (i) =>
      List.generate(224, (y) =>
          List.generate(224, (x) =>
              List.generate(3, (c) => flatInput[y * 224 * 3 + x * 3 + c])
          )
      )
  );

  // 2. Prepare output buffer
  var output = List<List<double>>.generate(1, (i) => List.filled(1, 0.0));

  // 3. Run inference
  _interpreter!.run(inputBuffer, output);

  return output[0];
}