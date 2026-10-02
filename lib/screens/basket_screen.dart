import 'package:flutter/material.dart';
import '../main.dart';
import '../models/smart_basket.dart';

class BasketScreen extends StatelessWidget {
  const BasketScreen({super.key, required this.controller});
  final FavourController controller;

  @override
  Widget build(BuildContext context) {
    final basket = controller.data.basket;
    final result = SmartBasketCalculator.calculate(basket, controller.data.offers);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Smart Basket', style: Theme.of(context).textTheme.headlineSmall),
        const Text('Uses latest available offers and known recorded fees.'),
        const SizedBox(height: 16),
        if (basket.isEmpty)
          const Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: Text('Add products from comparisons to calculate your basket.')),
          ),
        ...basket.map((item) {
          return Card(
            child: ListTile(
              title: Text(item.product.displayName),
              subtitle: Text(item.quantity.toString() + ' × ' + item.product.packLabel),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Remove from basket',
                onPressed: () {
                  final remaining = basket.where((entry) => entry.product.id != item.product.id).toList();
                  controller.save(controller.data.copyWith(basket: remaining));
                },
              ),
            ),
          );
        }),
        if (basket.isNotEmpty) const SizedBox(height: 16),
        if (!result.complete && basket.isNotEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Insufficient price data: record at least one available price for every item.'),
            ),
          ),
        if (result.complete) _Plan(result: result),
      ],
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.result});
  final SmartBasketResult result;

  @override
  Widget build(BuildContext context) {
    final split = result.split!;
    final single = result.single;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Best split basket: ₹' + split.total.toStringAsFixed(2)),
            ...split.allocations.map((allocation) {
              return Text(allocation.item.product.displayName + ': ' + allocation.offer.retailer.name);
            }),
            const SizedBox(height: 10),
            if (single != null)
              Text('Best complete retailer: ' + single.retailer!.name + ' — ₹' + single.total.toStringAsFixed(2)),
            if (single != null)
              Text(result.splitWins ? 'Splitting saves ₹' + result.savings.toStringAsFixed(2) + '.' : 'One retailer is cheaper by ₹' + result.savings.toStringAsFixed(2) + '.'),
            const SizedBox(height: 6),
            const Text('Totals include item prices and only explicitly recorded fees.', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}