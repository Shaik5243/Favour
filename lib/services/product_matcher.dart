import '../models/product.dart';

class ProductMatcher {
  static bool sameProduct(Product first, Product second) => _words('${first.brand} ${first.name}') == _words('${second.brand} ${second.name}') && first.unit.normalizedLabel == second.unit.normalizedLabel;
  static String _words(String value) { final words = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim().split(' ').where((word) => word.isNotEmpty).toList()..sort(); return words.join(' '); }
}
