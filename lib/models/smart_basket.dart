import 'offer.dart';
import 'product.dart';
import 'retailer.dart';

class BasketAllocation { const BasketAllocation({required this.item, required this.offer}); final BasketItem item; final Offer offer; }
class BasketPlan { const BasketPlan({required this.total, required this.allocations, this.retailer}); final double total; final List<BasketAllocation> allocations; final Retailer? retailer; }
class SmartBasketResult { const SmartBasketResult({required this.complete, this.split, this.single}); final bool complete; final BasketPlan? split; final BasketPlan? single; double get savings => split == null || single == null ? 0 : (single!.total - split!.total).abs(); bool get splitWins => split != null && single != null && split!.total < single!.total; }

class SmartBasketCalculator {
  static SmartBasketResult calculate(List<BasketItem> items, List<Offer> offers) {
    if (items.isEmpty) return const SmartBasketResult(complete: false);
    Offer? latest(Product product, Retailer retailer) { final matches = offers.where((offer) => offer.product.id == product.id && offer.retailer == retailer && offer.available).toList()..sort((a, b) => b.checkedAt.compareTo(a.checkedAt)); return matches.isEmpty ? null : matches.first; }
    final split = <BasketAllocation>[];
    for (final item in items) { final choices = Retailer.values.map((retailer) => latest(item.product, retailer)).whereType<Offer>().toList()..sort((a, b) => a.knownTotal.compareTo(b.knownTotal)); if (choices.isEmpty) return const SmartBasketResult(complete: false); split.add(BasketAllocation(item: item, offer: choices.first)); }
    final splitPlan = BasketPlan(total: split.fold(0, (sum, value) => sum + value.offer.knownTotal * value.item.quantity), allocations: split);
    final singles = <BasketPlan>[];
    for (final retailer in Retailer.values) { final allocations = <BasketAllocation>[]; for (final item in items) { final offer = latest(item.product, retailer); if (offer == null) break; allocations.add(BasketAllocation(item: item, offer: offer)); } if (allocations.length == items.length) singles.add(BasketPlan(retailer: retailer, allocations: allocations, total: allocations.fold(0, (sum, value) => sum + value.offer.knownTotal * value.item.quantity))); }
    singles.sort((a, b) => a.total.compareTo(b.total));
    return SmartBasketResult(complete: true, split: splitPlan, single: singles.isEmpty ? null : singles.first);
  }
}
