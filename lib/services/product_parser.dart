import '../models/product.dart';

class ParsedProduct {
  const ParsedProduct(this.product, {this.detected = false});
  final Product product;
  final bool detected;
}

class ProductParser {
  static ParsedProduct parse(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(kg|g|kgs?|ml|l|litre|litres|pcs?|pieces?)\b',
      caseSensitive: false,
    ).firstMatch(cleaned);
    final multi =
        RegExp(r'(\d+)\s*[x×]', caseSensitive: false).firstMatch(cleaned);

    if (match == null) {
      return ParsedProduct(Product(name: cleaned, packSize: 1, unit: Unit.piece));
    }

    final size = double.parse(match.group(1)!);
    final rawUnit = match.group(2)!.toLowerCase();
    final unit = rawUnit.startsWith('kg')
        ? Unit.kilogram
        : rawUnit == 'g'
            ? Unit.gram
            : rawUnit == 'ml'
                ? Unit.millilitre
                : rawUnit == 'l' || rawUnit.startsWith('litre')
                    ? Unit.litre
                    : Unit.piece;

    var name = cleaned.replaceFirst(match.group(0)!, '').trim();

    if (multi != null) {
      final packMarker = RegExp(
        '\\b${multi.group(1)!}\\s*[x×]\\s*\\$',
        caseSensitive: false,
      );
      name = name.replaceFirst(packMarker, '').trim();
    }

    final words = name.split(' ');
    return ParsedProduct(
      Product(
        name: words.length > 1 ? words.skip(1).join(' ') : name,
        brand: words.length > 1 ? words.first : '',
        packSize: size,
        unit: unit,
        packCount: multi == null ? 1 : int.parse(multi.group(1)!),
      ),
      detected: true,
    );
  }
}
