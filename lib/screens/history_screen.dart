import 'package:flutter/material.dart';

import '../main.dart';
import '../models/price_source.dart';
import '../models/product.dart';
import '../models/retailer.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.controller});

  final FavourController controller;

  @override
  Widget build(BuildContext context) {
    final offers = [...controller.data.offers]
      ..sort((first, second) => second.checkedAt.compareTo(first.checkedAt));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Price history',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const Text('Every observation stays on this device.'),
        const SizedBox(height: 12),
        if (offers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: Text('No price observations yet.')),
          ),
        ...offers.map(
          (offer) => Card(
            child: ListTile(
              leading: const Icon(Icons.price_check),
              title: Text(
                '${offer.product.displayName} • ₹${offer.price.toStringAsFixed(2)}',
              ),
              subtitle: Text(
                '${offer.retailer.name} • ${offer.source.label} • '
                '${offer.checkedAt.toLocal().toString().substring(0, 16)}',
              ),
              trailing: Text(
                '₹${offer.unitPrice.toStringAsFixed(2)}/'
                '${offer.product.unit.normalizedLabel}',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
