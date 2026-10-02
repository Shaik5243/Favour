import 'package:flutter/material.dart';

import 'models/offer.dart';
import 'models/product.dart';
import 'models/retailer.dart';
import 'screens/comparison_results_screen.dart';
import 'screens/search_screen.dart';
import 'services/local_store.dart';
import 'services/retailer_adapter.dart';

void main() {
  runApp(const FavourApp());
}

class FavourApp extends StatefulWidget {
  const FavourApp({super.key});

  @override
  State<FavourApp> createState() => _FavourAppState();
}

class _FavourAppState extends State<FavourApp> {
  final LocalStore _store = LocalStore();
  AppData _data = AppData.empty();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _data = await _store.load();
    } catch (_) {
      _error = 'Your saved data could not be loaded.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save(AppData data) async {
    setState(() => _data = data);
    try {
      await _store.save(data);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save changes locally.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xff225c48), brightness: Brightness.light);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Favour',
      theme: ThemeData(
        colorScheme: colors,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff7f8f5),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : HomeScreen(data: _data, error: _error, onSave: _save),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.data, required this.onSave, this.error});
  final AppData data;
  final String? error;
  final ValueChanged<AppData> onSave;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  Future<void> _openSearch([String? query]) async {
    final product = await Navigator.of(context).push<Product>(MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: query)));
    if (product == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComparisonResultsScreen(product: product, data: widget.data, onSave: widget.onSave)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_dashboard(), _saved(), _basket(), _settings()];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Compare'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.shopping_basket_outlined), selectedIcon: Icon(Icons.shopping_basket), label: 'Basket'),
          NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on), label: 'Location'),
        ],
      ),
    );
  }

  Widget _header(String title, String subtitle) => Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: Theme.of(context).textTheme.bodyMedium)]));

  Widget _dashboard() => ListView(padding: const EdgeInsets.only(bottom: 24), children: [
    _header('Favour', 'Compare recorded grocery prices with confidence.'),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: InkWell(onTap: _openSearch, borderRadius: BorderRadius.circular(16), child: IgnorePointer(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search a grocery product'))))),
    if (widget.error != null) Padding(padding: const EdgeInsets.all(20), child: _notice(widget.error!, Icons.error_outline)),
    Padding(padding: const EdgeInsets.all(20), child: _notice('Prices are recorded by you, not live. Open a retailer to check and save the price you see.', Icons.verified_user_outlined)),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Supported retailers', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
    const SizedBox(height: 12),
    SizedBox(height: 108, child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: supportedRetailers.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, index) { final retailer = supportedRetailers[index]; return SizedBox(width: 132, child: Card(color: retailer.color.withOpacity(.12), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(backgroundColor: retailer.color, radius: 14, child: Text(retailer.shortName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))), const Spacer(), Text(retailer.name, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w700))]))); })),
    if (widget.data.offers.isNotEmpty) ...[const SizedBox(height: 24), Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Recent recorded prices', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), const SizedBox(height: 10), ...([...widget.data.offers]..sort((a, b) => b.timestamp.compareTo(a.timestamp))).take(3).map((offer) => Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Card(child: ListTile(leading: Icon(Icons.history, color: offer.retailer.color), title: Text(offer.product.displayName), subtitle: Text('${offer.retailer.name} • ${offer.product.packLabel}'), trailing: Text('₹${offer.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))))))],
  ]);

  Widget _notice(String text, IconData icon) => Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(width: 12), Expanded(child: Text(text))])));

  Widget _saved() => ListView(padding: const EdgeInsets.only(bottom: 24), children: [
    _header('Saved products', 'Your favourite comparisons, stored on this device.'),
    if (widget.data.favourites.isEmpty) const _EmptyState(icon: Icons.bookmark_border, title: 'Nothing saved yet', body: 'Search for a product, then tap Save on its comparison screen.'),
    ...widget.data.favourites.map((product) => Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Card(child: ListTile(onTap: () => _openSearch(product.name), title: Text(product.displayName), subtitle: Text(product.packLabel), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => widget.onSave(widget.data.copyWith(favourites: widget.data.favourites.where((item) => item.id != product.id).toList())))))),
  ]);

  Widget _basket() {
    final calculation = SmartBasket.calculate(widget.data.basket, widget.data.offers);
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      _header('Your basket', 'Recorded prices only — fees are shown only when recorded.'),
      if (widget.data.basket.isEmpty) const _EmptyState(icon: Icons.shopping_basket_outlined, title: 'Your basket is empty', body: 'Add a product from a comparison to plan your shop.'),
      ...widget.data.basket.map((item) => Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Card(child: ListTile(title: Text(item.product.displayName), subtitle: Text('${item.quantity} × ${item.product.packLabel}'), trailing: IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => widget.onSave(widget.data.copyWith(basket: widget.data.basket.where((entry) => entry.product.id != item.product.id).toList())))))),
      if (widget.data.basket.isNotEmpty) Padding(padding: const EdgeInsets.all(20), child: _SmartBasketCard(calculation: calculation)),
    ]);
  }

  Widget _settings() {
    final controller = TextEditingController(text: widget.data.pincode);
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [_header('Your location', 'Pincode stays on your device for future authorised integrations.'), Padding(padding: const EdgeInsets.all(20), child: TextField(controller: controller, maxLength: 6, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pincode', prefixIcon: Icon(Icons.location_on_outlined))),), Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: FilledButton(onPressed: () { widget.onSave(widget.data.copyWith(pincode: controller.text.trim())); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location saved locally.'))); }, child: const Text('Save pincode')))]);
  }
}

class _SmartBasketCard extends StatelessWidget { const _SmartBasketCard({required this.calculation}); final SmartBasket calculation; @override Widget build(BuildContext context) { if (!calculation.hasCompletePrices) return Card(color: Theme.of(context).colorScheme.secondaryContainer, child: const Padding(padding: EdgeInsets.all(16), child: Text('Smart Basket needs one recorded, available offer for every basket item. Record more prices to compare totals.'))); return Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Smart Basket', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Split basket: ₹${calculation.splitTotal.toStringAsFixed(2)}'), if (calculation.oneRetailer != null) Text('One retailer (${calculation.oneRetailer!.retailer.name}): ₹${calculation.oneRetailer!.total.toStringAsFixed(2)}'), const SizedBox(height: 8), Text(calculation.isSplitCheaper ? 'Splitting saves ₹${(calculation.oneRetailer!.total - calculation.splitTotal).toStringAsFixed(2)} on recorded item prices.' : 'One retailer is as good as or cheaper than splitting.', style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), const Text('Delivery, handling and other fees are excluded unless you record them.', style: TextStyle(fontSize: 12))]))); } }
class _EmptyState extends StatelessWidget { const _EmptyState({required this.icon, required this.title, required this.body}); final IconData icon; final String title; final String body; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(36), child: Column(children: [Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline), const SizedBox(height: 12), Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6), Text(body, textAlign: TextAlign.center)])); }
