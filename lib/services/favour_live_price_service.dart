import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/offer.dart';
import '../models/price_source.dart';
import '../models/product.dart';
import '../models/retailer.dart';

class FavourLivePriceService {
  FavourLivePriceService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<Offer>> search(Product product, {required String pincode, required String endpoint, String token = ''}) async {
    if (endpoint.trim().isEmpty || pincode.trim().length != 6) return const [];
    final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json'};
    if (token.trim().isNotEmpty) headers['Authorization'] = 'Bearer ' + token.trim();
    final response = await _client.post(Uri.parse(endpoint.trim()), headers: headers, body: jsonEncode({'query': product.displayName, 'product': product.toJson(), 'pincode': pincode.trim()}));
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final decoded = jsonDecode(response.body);
    final raw = decoded is Map ? (decoded['offers'] ?? decoded['data']?['offers']) : null;
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => _offer(item, product)).whereType<Offer>().toList();
  }

  Offer? _offer(Map item, Product product) {
    final retailerName = item['retailer']?.toString();
    final price = double.tryParse(item['price']?.toString() ?? '');
    if (retailerName == null || price == null || price <= 0) return null;
    Retailer retailer;
    try { retailer = Retailer.values.byName(retailerName); } catch (_) { return null; }
    return Offer(id: '${retailer.name}-${item['id'] ?? DateTime.now().microsecondsSinceEpoch}', product: product, retailer: retailer, price: price, checkedAt: DateTime.tryParse(item['checkedAt']?.toString() ?? '') ?? DateTime.now(), available: item['available'] != false, source: PriceSource.live, sourceNote: item['source']?.toString() ?? 'Favour live gateway', deliveryFee: double.tryParse(item['deliveryFee']?.toString() ?? ''), handlingFee: double.tryParse(item['handlingFee']?.toString() ?? ''), otherFee: double.tryParse(item['otherFee']?.toString() ?? ''));
  }
}