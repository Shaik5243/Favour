import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/offer.dart';
import '../models/product.dart';
import '../models/price_source.dart';
import '../models/retailer.dart';

class AppData {
  const AppData({required this.offers, required this.favourites, required this.basket, required this.alerts, required this.pincode});
  final List<Offer> offers; final List<Product> favourites; final List<BasketItem> basket; final List<PriceAlert> alerts; final String pincode;
  const AppData.empty() : offers = const [], favourites = const [], basket = const [], alerts = const [], pincode = '';
  AppData copyWith({List<Offer>? offers, List<Product>? favourites, List<BasketItem>? basket, List<PriceAlert>? alerts, String? pincode}) => AppData(offers: offers ?? this.offers, favourites: favourites ?? this.favourites, basket: basket ?? this.basket, alerts: alerts ?? this.alerts, pincode: pincode ?? this.pincode);
}
class LocalStore {
  static const _key = 'favour_app_data_v5';
  Future<AppData> load() async { final prefs = await SharedPreferences.getInstance(); final raw = prefs.getString(_key); if (raw == null) return _migrateV4(prefs); final json = Map<String, dynamic>.from(jsonDecode(raw) as Map); return AppData(offers: (json['offers'] as List).map((item) => Offer.fromJson(Map<String, dynamic>.from(item as Map))).toList(), favourites: (json['favourites'] as List).map((item) => Product.fromJson(Map<String, dynamic>.from(item as Map))).toList(), basket: (json['basket'] as List).map((item) => BasketItem.fromJson(Map<String, dynamic>.from(item as Map))).toList(), alerts: (json['alerts'] as List? ?? []).map((item) => PriceAlert.fromJson(Map<String, dynamic>.from(item as Map))).toList(), pincode: json['pincode'] as String? ?? ''); }
  Future<AppData> _migrateV4(SharedPreferences prefs) async { final raw = prefs.getString('favour_app_data_v4'); if (raw == null) return const AppData.empty(); final json = Map<String, dynamic>.from(jsonDecode(raw) as Map); final offers = (json['offers'] as List? ?? []).map((item) { final old = Map<String, dynamic>.from(item as Map); return Offer(id: '${old['timestamp']}-${old['retailer']}', product: Product.fromJson(Map<String, dynamic>.from(old['product'] as Map)), retailer: Retailer.values.byName(old['retailer'] as String), price: (old['price'] as num).toDouble(), checkedAt: DateTime.parse(old['timestamp'] as String), available: old['available'] as bool? ?? true, source: PriceSource.recorded, deliveryFee: (old['deliveryFee'] as num?)?.toDouble(), handlingFee: (old['handlingFee'] as num?)?.toDouble(), otherFee: (old['otherFee'] as num?)?.toDouble()); }).toList(); return AppData(offers: offers, favourites: (json['favourites'] as List? ?? []).map((item) => Product.fromJson(Map<String, dynamic>.from(item as Map))).toList(), basket: (json['basket'] as List? ?? []).map((item) => BasketItem.fromJson(Map<String, dynamic>.from(item as Map))).toList(), alerts: const [], pincode: json['pincode'] as String? ?? ''); }
  Future<void> save(AppData data) async { final prefs = await SharedPreferences.getInstance(); await prefs.setString(_key, jsonEncode({'offers': data.offers.map((item) => item.toJson()).toList(), 'favourites': data.favourites.map((item) => item.toJson()).toList(), 'basket': data.basket.map((item) => item.toJson()).toList(), 'alerts': data.alerts.map((item) => item.toJson()).toList(), 'pincode': data.pincode})); }
}
