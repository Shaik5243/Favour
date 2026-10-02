import 'price_source.dart';
import 'product.dart';
import 'retailer.dart';

class Offer {
  const Offer({required this.id, required this.product, required this.retailer, required this.price, required this.checkedAt, required this.available, required this.source, this.deliveryFee, this.handlingFee, this.otherFee, this.sourceNote});
  final String id;
  final Product product;
  final Retailer retailer;
  final double price;
  final DateTime checkedAt;
  final bool available;
  final PriceSource source;
  final double? deliveryFee;
  final double? handlingFee;
  final double? otherFee;
  final String? sourceNote;
  double get unitPrice => price / product.normalizedQuantity;
  double get knownFees => (deliveryFee ?? 0) + (handlingFee ?? 0) + (otherFee ?? 0);
  double get knownTotal => price + knownFees;
  Map<String, dynamic> toJson() => {'id': id, 'product': product.toJson(), 'retailer': retailer.name, 'price': price, 'checkedAt': checkedAt.toIso8601String(), 'available': available, 'source': source.name, 'deliveryFee': deliveryFee, 'handlingFee': handlingFee, 'otherFee': otherFee, 'sourceNote': sourceNote};
  factory Offer.fromJson(Map<String, dynamic> json) => Offer(id: json['id'] as String, product: Product.fromJson(Map<String, dynamic>.from(json['product'] as Map)), retailer: Retailer.values.byName(json['retailer'] as String), price: (json['price'] as num).toDouble(), checkedAt: DateTime.parse(json['checkedAt'] as String), available: json['available'] as bool? ?? true, source: PriceSource.values.byName(json['source'] as String? ?? 'recorded'), deliveryFee: (json['deliveryFee'] as num?)?.toDouble(), handlingFee: (json['handlingFee'] as num?)?.toDouble(), otherFee: (json['otherFee'] as num?)?.toDouble(), sourceNote: json['sourceNote'] as String?);
}

class BasketItem { const BasketItem({required this.product, this.quantity = 1}); final Product product; final int quantity; Map<String, dynamic> toJson() => {'product': product.toJson(), 'quantity': quantity}; factory BasketItem.fromJson(Map<String, dynamic> json) => BasketItem(product: Product.fromJson(Map<String, dynamic>.from(json['product'] as Map)), quantity: json['quantity'] as int? ?? 1); }
class PriceAlert { const PriceAlert({required this.product, required this.targetPrice, this.enabled = true}); final Product product; final double targetPrice; final bool enabled; Map<String, dynamic> toJson() => {'product': product.toJson(), 'targetPrice': targetPrice, 'enabled': enabled}; factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(product: Product.fromJson(Map<String, dynamic>.from(json['product'] as Map)), targetPrice: (json['targetPrice'] as num).toDouble(), enabled: json['enabled'] as bool? ?? true); }
