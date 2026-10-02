import 'package:flutter_test/flutter_test.dart';
import 'package:favour/models/offer.dart';
import 'package:favour/models/price_source.dart';
import 'package:favour/models/product.dart';
import 'package:favour/models/retailer.dart';
import 'package:favour/models/smart_basket.dart';
import 'package:favour/services/product_parser.dart';
import 'package:favour/services/product_matcher.dart';

void main() {
  test('normalizes grams, kilograms, millilitres and multipacks', () {
    final halfKg = Product(name: 'Flour', packSize: 500, unit: Unit.gram);
    final kilo = Product(name: 'Flour', packSize: 1, unit: Unit.kilogram);
    final multi = Product(name: 'Juice', packSize: 500, unit: Unit.millilitre, packCount: 2);
    expect(Offer(id: 'a', product: halfKg, retailer: Retailer.blinkit, price: 100, checkedAt: DateTime(2025), available: true, source: PriceSource.recorded).unitPrice, 200);
    expect(Offer(id: 'b', product: kilo, retailer: Retailer.zepto, price: 180, checkedAt: DateTime(2025), available: true, source: PriceSource.recorded).unitPrice, 180);
    expect(multi.normalizedQuantity, 1);
  });
  test('parses product description where a pack is supplied', () { final parsed = ProductParser.parse('Amul Taaza Milk 1L').product; expect(parsed.brand, 'Amul'); expect(parsed.name, 'Taaza Milk'); expect(parsed.unit, Unit.litre); expect(parsed.packSize, 1); });
  test('matches equivalent brand and product words', () { expect(ProductMatcher.sameProduct(const Product(brand: 'Amul', name: 'Taaza Milk', packSize: 500, unit: Unit.millilitre), const Product(brand: 'amul', name: 'Milk Taaza', packSize: 1, unit: Unit.litre)), isTrue); });
  test('smart basket finds cheaper split allocation', () { final milk = Product(name: 'Milk', packSize: 1, unit: Unit.litre); final bread = Product(name: 'Bread', packSize: 1, unit: Unit.piece); Offer offer(String id, Product product, Retailer retailer, double price) => Offer(id: id, product: product, retailer: retailer, price: price, checkedAt: DateTime(2025), available: true, source: PriceSource.recorded); final result = SmartBasketCalculator.calculate([BasketItem(product: milk), BasketItem(product: bread)], [offer('1', milk, Retailer.blinkit, 50), offer('2', bread, Retailer.blinkit, 60), offer('3', milk, Retailer.zepto, 55), offer('4', bread, Retailer.zepto, 40)]); expect(result.complete, isTrue); expect(result.split!.total, 90); expect(result.single!.total, 110); expect(result.splitWins, isTrue); });
}
