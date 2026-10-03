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
  late final TextEditingController _endpointController;
  late final TextEditingController _credentialController;
  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController(text: widget.controller.data.pincode);
    _endpointController = TextEditingController(text: widget.controller.data.liveEndpoint);
    _credentialController = TextEditingController(text: widget.controller.data.apiKey);
  }
  @override
  void dispose() { _pinController.dispose(); _endpointController.dispose(); _credentialController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final alerts = widget.controller.data.alerts;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Location & alerts', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        TextField(controller: _pinController, maxLength: 6, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN code', prefixIcon: Icon(Icons.location_on_outlined))),
        TextField(controller: _endpointController, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Favour live gateway URL', prefixIcon: Icon(Icons.cloud_outlined), hintText: 'https://your-gateway.example/compare')),\n        const SizedBox(height: 12),\n        TextField(controller: _credentialController, obscureText: true, decoration: const InputDecoration(labelText: 'Gateway token (optional)', prefixIcon: Icon(Icons.lock_outline))),\n        const SizedBox(height: 12),\n        FilledButton(onPressed: () => widget.controller.save(widget.controller.data.copyWith(pincode: _pinController.text.trim(), liveEndpoint: _endpointController.text.trim(), apiKey: _credentialController.text.trim())), child: const Text('Save live settings')),

        const SizedBox(height: 20),
        Text('Price alerts', style: Theme.of(context).textTheme.titleLarge),
        const Text('Alerts run when you save a newly recorded or authorised price that reaches a target.'),
        ...alerts.map((alert) => _AlertTile(alert: alert, controller: widget.controller)),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _addAlert, icon: const Icon(Icons.add_alert), label: const Text('Create target alert')),
        const SizedBox(height: 20),
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Your PIN code, price history, screenshots-derived observations and alerts remain local.'))),
      ],
    );
  }

  Future<void> _addAlert() async {
    final favourites = widget.controller.data.favourites;
    if (favourites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save a product before creating an alert.')));
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
              initialValue: selectedProduct,
              items: favourites.map((product) => DropdownMenuItem<Product>(value: product, child: Text(product.displayName))).toList(),
              onChanged: (product) { if (product != null) selectedProduct = product; },
            ),
            TextField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target price', prefixText: '₹ ')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final target = double.tryParse(priceController.text);
              if (target == null || target <= 0) return;
              Navigator.pop(dialogContext, PriceAlert(product: selectedProduct, targetPrice: target));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    priceController.dispose();
    if (alert != null) {
      final updated = [...widget.controller.data.alerts.where((item) => item.product.id != alert.product.id), alert];
      await widget.controller.save(widget.controller.data.copyWith(alerts: updated));
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
        subtitle: Text('Target ₹' + alert.targetPrice.toStringAsFixed(2)),
        trailing: Switch(
          value: alert.enabled,
          onChanged: (enabled) {
            final alerts = controller.data.alerts.map((item) {
              if (item.product.id != alert.product.id) return item;
              return PriceAlert(product: item.product, targetPrice: item.targetPrice, enabled: enabled);
            }).toList();
            controller.save(controller.data.copyWith(alerts: alerts));
          },
        ),
      ),
    );
  }
}