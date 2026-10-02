import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/product.dart';
import 'product_parser.dart';

class OcrCandidate {
  const OcrCandidate({required this.rawText, required this.product, this.price});
  final String rawText;
  final Product product;
  final double? price;
}

class OcrService {
  Future<OcrCandidate> read(File image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text = (await recognizer.processImage(InputImage.fromFile(image))).text;
      final priceMatch = RegExp(r'(?:₹|rs\.?|inr)\s*([0-9]+(?:\.[0-9]{1,2})?)', caseSensitive: false).firstMatch(text) ?? RegExp(r'\b([0-9]+(?:\.[0-9]{1,2})?)\b').firstMatch(text);
      final productLine = text.split('\n').firstWhere((line) => RegExp(r'[a-zA-Z]').hasMatch(line), orElse: () => 'Imported product');
      return OcrCandidate(rawText: text, product: ProductParser.parse(productLine).product, price: priceMatch == null ? null : double.tryParse(priceMatch.group(1)!));
    } finally { recognizer.close(); }
  }
}
