import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// TEMPORARY OCR IMPLEMENTATION:
// Google ML Kit is used on-device for early Foloo validation.
// Final card extraction will move behind the Foloo backend
// according to the architecture specification.
class CardTextRecognitionService {
  CardTextRecognitionService()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<List<String>> recognizeLines(String imagePath) async {
    final image = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(image);
    return result.blocks
        .expand((block) => block.lines)
        .map((line) => line.text.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> close() => _recognizer.close();
}
