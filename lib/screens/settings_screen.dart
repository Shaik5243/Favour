import 'package:flutter/material.dart';

import '../main.dart';
import '../models/offer.dart';
import '../models/product.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final FavourController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _pinController;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController(text: widget.controller.data.pincode);
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alerts = widget.controller.data.alerts;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Location & alerts',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _pinController,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'PIN code',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        FilledButton(
          onPressed: () => widget.controller.save(
            widget.controller.data.copyWith(pincode: _pinController.text.trim()),
          ),
          child: const Text('Save PIN code'),
        ),
        const SizedBox(height: 20),
        Text('Price alerts', style: Theme.of(context).textTheme.titleLarge),
        const Text(
          'Alerts run when you save a newly recorded or authorised price that reaches a target.',
        ),
        ...alerts.map((alert) => _AlertTile(alert: alert, controller: widget.controller)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addAlert,
          icon: const Icon(Icons.add_alert),
          label: const Text('Create target alert'),
        ),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Your PIN code, price history, screenshots-derived observations and alerts remain local. '
              'Location is passed only to a future authorised retailer adapter.',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addAlert() async {
    final favourites = widget.controller.data.favourites;
    if (favourites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save a product before creating an alert.')),
      );
      return;
    }

    final priceController = TextEditingController();
    Product selectedProduct = favourites.first;
    final alert = await showDialog<PriceAlert>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Target price alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Product>(
              value: selectedProduct,
              items: favourites
                  .map(
                    (product) => DropdownMenuItem<Product>(
                      value: product,
                      child: Text(product.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (product) {
                if (product != null) {
                  selectedProduct = product;
                }
              },
            ),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Target price',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final target = double.tryParse(priceController.text);
              if (target == null || target <= 0) return;
              Navigator.pop(
                dialogContext,
                PriceAlert(product: selectedProduct, targetPrice: target),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    priceController.dispose();

    if (alert != null) {
      await widget.controller.save(
        widget.controller.data.copyWith(
          alerts: [
            ...widget.controller.data.alerts
                .where((item) => item.product.id != alert.product.id),
            alert,
          ],
        ),
      );
    }
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.controller});

  final PriceAlert alert;
  final FavourController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(alert.product.displayName),
        subtitle: Text('Target ₹${alert.targetPrice.toStringAsFixed(2)}'),
        trailing: Switch(
          value: alert.enabled,
          onChanged: (enabled) => controller.save(
            controller.data.copyWith(
              alerts: controller.data.alerts
                  .map(
                    (item) => item.product.id == alert.product.id
                        ? PriceAlert(
                            product: item.product,
                            targetPrice: item.targetPrice,
                            enabled: enabled,
                          )
                        : item,
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
