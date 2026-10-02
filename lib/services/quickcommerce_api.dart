import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/offer.dart';
import '../models/price_source.dart';
import '../models/product.dart';
import '../models/retailer.dart';

class QuickCommerceApi {
  QuickCommerceApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const baseUrl = 'https://api.quickcommerceapi.com/v1';
  static const _platforms = <Retailer, String>{
    Retailer.blinkit: 'BlinkIt',
    Retailer.zepto: 'Zepto',
    Retailer.swiggyInstamart: 'Swiggy',
    Retailer.bigBasketNow: 'BigBasket',
    Retailer.flipkartMinutes: 'Minutes',
    Retailer.jioMart: 'JioMart',
  };

  Future<List<Offer>> search(Product product, {required String pincode, required String apiKey, double? latitude, double? longitude}) async {
    if (apiKey.trim().isEmpty || latitude == null || longitude == null) return const [];
    final results = <Offer>[];
    for (final entry in _platforms.entries) {
      try {
        final uri = Uri.parse('$baseUrl/search').replace(queryParameters: {
          'q': product.displayName,
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'platform': entry.value,
          if (pincode.trim().isNotEmpty) 'pincode': pincode.trim(),
        });
        final response = await _client.get(uri, headers: {'X-API-Key': apiKey.trim(), 'Accept': 'application/json'});
        if (response.statusCode != 200) continue;
        final body = jsonDecode(response.body);
        final products = body is Map ? (body['data']?['products'] as List? ?? const []) : const [];
        for (final item in products) {
          if (item is Map) {
            final offer = _parseOffer(item, product, entry.key);
            if (offer != null) results.add(offer);
          }
        }
      } catch (_) {}
    }
    return results;
  }

  Offer? _parseOffer(Map item, Product requested, Retailer retailer) {
    final name = item['name']?.toString() ?? '';
    final price = _number(item['offer_price'] ?? item['price']);
    if (name.isEmpty || price == null || price <= 0) return null;
    final q = _parseQuantity(item['quantity']?.toString() ?? '', requested);
    final brand = item['brand']?.toString() ?? '';
    final candidate = Product(name: _stripBrand(name, brand), brand: brand, packSize: q.size, unit: q.unit, packCount: q.count);
    if (!_sameEnough(requested, candidate)) return null;
    return Offer(id: '${retailer.name}-${item['id'] ?? DateTime.now().microsecondsSinceEpoch}', product: requested, retailer: retailer, price: price, checkedAt: DateTime.now(), available: item['available'] != false, source: PriceSource.live, sourceNote: 'Live connector');
  }

  bool _sameEnough(Product a, Product b) {
    final aw = ('${a.brand} ${a.name}').toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').split(' ').where((x) => x.isNotEmpty).toSet();
    final bw = ('${b.brand} ${b.name}').toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').split(' ').where((x) => x.isNotEmpty).toSet();
    final ratio = aw.isEmpty ? 0 : aw.intersection(bw).length / aw.length;
    final quantityRatio = a.normalizedQuantity == 0 ? 0 : b.normalizedQuantity / a.normalizedQuantity;
    return ratio >= (a.brand.isEmpty ? 0.5 : 0.6) && a.unit.normalizedLabel == b.unit.normalizedLabel && quantityRatio >= 0.8 && quantityRatio <= 1.25;
  }

  ({double size, Unit unit, int count}) _parseQuantity(String text, Product fallback) {
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*(kg|g|ml|l|litre|litres|pc|pcs|piece|pieces)(?:\s*[x×]\s*(\d+))?', caseSensitive: false).firstMatch(text);
    if (m == null) return (size: fallback.packSize, unit: fallback.unit, count: fallback.packCount);
    final size = double.tryParse(m.group(1)!) ?? fallback.packSize;
    final raw = m.group(2)!.toLowerCase();
    final unit = raw == 'kg' ? Unit.kilogram : raw == 'g' ? Unit.gram : raw == 'ml' ? Unit.millilitre : (raw == 'l' || raw.startsWith('litre')) ? Unit.litre : Unit.piece;
    return (size: size, unit: unit, count: int.tryParse(m.group(3) ?? '1') ?? 1);
  }

  double? _number(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
  String _stripBrand(String name, String brand) => brand.isEmpty ? name : name.toLowerCase().startsWith(brand.toLowerCase()) ? name.substring(brand.length).trim() : name;
}
