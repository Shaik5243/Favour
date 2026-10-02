import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/offer.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void> initialize() async { if (_ready) return; await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'))); await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission(); _ready = true; }
  Future<void> notifyIfMatched(Offer offer, List<PriceAlert> alerts) async { final matches = alerts.where((item) => item.enabled && item.product.id == offer.product.id && offer.price <= item.targetPrice); if (matches.isEmpty) return; await initialize(); await _plugin.show(offer.id.hashCode, 'Favour target reached', '${offer.product.displayName} is ₹${offer.price.toStringAsFixed(2)} at ${offer.retailer.name}.', const NotificationDetails(android: AndroidNotificationDetails('price_alerts', 'Price alerts', channelDescription: 'Favour target-price alerts', importance: Importance.high))); }
}
