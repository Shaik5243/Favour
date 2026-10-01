import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const retailers = [
  'Blinkit',
  'Zepto',
  'Instamart',
  'BB Now',
  'Flipkart Minutes',
  'Amazon Now',
  'JioMart',
];

class PriceRecord {
  final String product;
  final String retailer;
  final double price;
  final DateTime time;

  PriceRecord(
    this.product,
    this.retailer,
    this.price,
    this.time,
  );

  Map<String, dynamic> toJson() {
    return {
      'product': product,
      'retailer': retailer,
      'price': price,
      'time': time.toIso8601String(),
    };
  }

  factory PriceRecord.fromJson(Map<String, dynamic> json) {
    return PriceRecord(
      '${json['product']}',
      '${json['retailer']}',
      (json['price'] as num).toDouble(),
      DateTime.parse('${json['time']}'),
    );
  }
}

void main() {
  runApp(const FavourApp());
}

class FavourApp extends StatelessWidget {
  const FavourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Favour',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const FavourHome(),
    );
  }
}

class FavourHome extends StatefulWidget {
  const FavourHome({super.key});

  @override
  State<FavourHome> createState() => _FavourHomeState();
}

class _FavourHomeState extends State<FavourHome> {
  final TextEditingController searchController =
      TextEditingController();

  final TextEditingController pincodeController =
      TextEditingController();

  List<PriceRecord> records = [];
  List<String> favourites = [];

  String query = '';
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final storedRecords =
        prefs.getStringList('price_records') ?? [];

    setState(() {
      records = storedRecords
          .map(
            (item) => PriceRecord.fromJson(
              jsonDecode(item),
            ),
          )
          .toList();

      favourites =
          prefs.getStringList('favourites') ?? [];

      pincodeController.text =
          prefs.getString('pincode') ?? '';
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'price_records',
      records
          .map((item) => jsonEncode(item.toJson()))
          .toList(),
    );

    await prefs.setStringList(
      'favourites',
      favourites,
    );

    await prefs.setString(
      'pincode',
      pincodeController.text.trim(),
    );
  }

  List<PriceRecord> get productRecords {
    final search =
        query.trim().toLowerCase();

    return records
        .where(
          (record) =>
              record.product.toLowerCase() ==
              search,
        )
        .toList()
      ..sort(
        (a, b) => b.time.compareTo(a.time),
      );
  }

  Map<String, PriceRecord> get latestPrices {
    final Map<String, PriceRecord> result = {};

    for (final record in productRecords) {
      if (!result.containsKey(record.retailer)) {
        result[record.retailer] = record;
      }
    }

    return result;
  }

  PriceRecord? get bestPrice {
    final prices =
        latestPrices.values.toList();

    if (prices.isEmpty) {
      return null;
    }

    prices.sort(
      (a, b) => a.price.compareTo(b.price),
    );

    return prices.first;
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void searchProduct() {
    setState(() {
      query =
          searchController.text.trim();
    });
  }

  Future<void> recordPrice(
    String retailer,
  ) async {
    if (searchController.text.trim().isEmpty) {
      showMessage(
        'Search for a product first.',
      );
      return;
    }

    final priceController =
        TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Record $retailer price',
          ),
          content: TextField(
            controller: priceController,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration:
                const InputDecoration(
              prefixText: '₹ ',
              hintText: 'Current price',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final value =
                    double.tryParse(
                  priceController.text.trim(),
                );

                if (value == null ||
                    value <= 0) {
                  showMessage(
                    'Enter a valid price.',
                  );
                  return;
                }

                setState(() {
                  records.add(
                    PriceRecord(
                      searchController.text.trim(),
                      retailer,
                      value,
                      DateTime.now(),
                    ),
                  );

                  query =
                      searchController.text.trim();
                });

                await saveData();

                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> openRetailer(
    String retailer,
  ) async {
    final product =
        searchController.text.trim();

    if (product.isEmpty) {
      showMessage(
        'Search for a product first.',
      );
      return;
    }

    final encoded =
        Uri.encodeQueryComponent(product);

    final urls = {
      'Blinkit':
          'https://blinkit.com/s/?q=$encoded',
      'Zepto':
          'https://www.zeptonow.com/search?query=$encoded',
      'Instamart':
          'https://www.swiggy.com/instamart/search?query=$encoded',
      'BB Now':
          'https://www.bigbasket.com/ps/?q=$encoded',
      'Flipkart Minutes':
          'https://www.flipkart.com/search?q=$encoded',
      'Amazon Now':
          'https://www.amazon.in/s?k=$encoded',
      'JioMart':
          'https://www.jiomart.com/search/$encoded',
    };

    try {
      await launchUrl(
        Uri.parse(urls[retailer]!),
        mode:
            LaunchMode.externalApplication,
      );
    } catch (_) {
      showMessage(
        'Could not open $retailer.',
      );
    }
  }

  Future<void> toggleFavourite() async {
    final product =
        searchController.text.trim();

    if (product.isEmpty) {
      return;
    }

    setState(() {
      if (favourites.contains(product)) {
        favourites.remove(product);
      } else {
        favourites.add(product);
      }
    });

    await saveData();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      comparePage(),
      savedPage(),
      historyPage(),
      settingsPage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: pages[selectedTab],
      ),
      bottomNavigationBar:
          NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected:
            (index) {
          setState(() {
            selectedTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon:
                Icon(Icons.compare_arrows),
            label: 'Compare',
          ),
          NavigationDestination(
            icon:
                Icon(Icons.star_outline),
            selectedIcon:
                Icon(Icons.star),
            label: 'Saved',
          ),
          NavigationDestination(
            icon:
                Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon:
                Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget comparePage() {
    final best = bestPrice;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Favour',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const Text(
          'Find the best price for what you want to buy.',
        ),

        const SizedBox(height: 18),

        TextField(
          controller: searchController,
          textInputAction:
              TextInputAction.search,
          onSubmitted: (_) {
            searchProduct();
          },
          decoration:
              InputDecoration(
            hintText:
                'e.g. Amul Taaza Milk 1L',
            prefixIcon:
                const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: searchProduct,
              icon: const Icon(
                Icons.arrow_forward,
              ),
            ),
            filled: true,
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(18),
              borderSide:
                  BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 12),

        if (query.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: Text(
                  query,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed:
                    toggleFavourite,
                icon: Icon(
                  favourites.contains(
                          query)
                      ? Icons.star
                      : Icons.star_border,
                ),
              ),
            ],
          ),

        if (best != null)
          Card(
            child: ListTile(
              leading:
                  const CircleAvatar(
                child: Icon(
                  Icons.emoji_events,
                ),
              ),
              title: Text(
                '🏆 Best recorded price ₹${best.price.toStringAsFixed(0)}',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              subtitle:
                  Text(best.retailer),
            ),
          ),

        const SizedBox(height: 8),

        Text(
          'Retailers',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
        ),

        const SizedBox(height: 8),

        ...retailers.map(
          (retailer) {
            return retailerCard(
              retailer,
              latestPrices[retailer],
            );
          },
        ),

        const SizedBox(height: 12),

        const Card(
          child: Padding(
            padding:
                EdgeInsets.all(14),
            child: Text(
              'Favour never invents live prices. Open a retailer, check the current price, and record it. Favour remembers the price and identifies the cheapest recorded option.',
            ),
          ),
        ),
      ],
    );
  }

  Widget retailerCard(
    String retailer,
    PriceRecord? record,
  ) {
    final isBest =
        bestPrice?.retailer ==
            retailer;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: Column(
        children: [
          ListTile(
            leading:
                CircleAvatar(
              child: Text(
                retailer.substring(0, 1),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    retailer,
                  ),
                ),
                if (isBest)
                  const Text(
                    '🏆 BEST',
                    style:
                        TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              record == null
                  ? 'Price not recorded'
                  : '₹${record.price.toStringAsFixed(0)} • ${priceAge(record.time)}',
            ),
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    openRetailer(
                  retailer,
                ),
                icon: const Icon(
                  Icons.open_in_new,
                  size: 18,
                ),
                label:
                    const Text('Open'),
              ),

              const SizedBox(width: 8),

              FilledButton.tonalIcon(
                onPressed: () =>
                    recordPrice(
                  retailer,
                ),
                icon: const Icon(
                  Icons.add,
                  size: 18,
                ),
                label:
                    const Text('Record'),
              ),

              const SizedBox(width: 8),
            ],
          ),

          const SizedBox(height: 5),
        ],
      ),
    );
  }

  String priceAge(DateTime time) {
    final difference =
        DateTime.now().difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    return '${difference.inDays} day(s) ago';
  }

  Widget savedPage() {
    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        Text(
          'Saved products',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
        ),

        const SizedBox(height: 12),

        if (favourites.isEmpty)
          const Text(
            'Search a product and tap ⭐ to save it.',
          ),

        ...favourites.map(
          (product) {
            return Card(
              child: ListTile(
                title: Text(product),
                onTap: () {
                  searchController.text =
                      product;

                  setState(() {
                    query = product;
                    selectedTab = 0;
                  });
                },
                trailing:
                    IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                  onPressed: () async {
                    setState(() {
                      favourites
                          .remove(product);
                    });

                    await saveData();
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget historyPage() {
    final history =
        [...records]..sort(
            (a, b) =>
                b.time.compareTo(a.time),
          );

    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        Text(
          'Price history',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
        ),

        const SizedBox(height: 12),

        if (history.isEmpty)
          const Text(
            'No prices recorded yet.',
          ),

        ...history.map(
          (record) {
            return ListTile(
              leading: const Icon(
                Icons.price_check,
              ),
              title: Text(
                '${record.product} • ₹${record.price.toStringAsFixed(0)}',
              ),
              subtitle: Text(
                '${record.retailer} • ${record.time.toLocal().toString().substring(0, 16)}',
              ),
            );
          },
        ),
      ],
    );
  }

  Widget settingsPage() {
    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        Text(
          'Settings',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
        ),

        const SizedBox(height: 16),

        TextField(
          controller:
              pincodeController,
          keyboardType:
              TextInputType.number,
          decoration:
              const InputDecoration(
            labelText: 'Your pincode',
            prefixIcon: Icon(
              Icons.location_on_outlined,
            ),
            border:
                OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 12),

        FilledButton(
          onPressed: () async {
            await saveData();

            showMessage(
              'Settings saved.',
            );
          },
          child:
              const Text('Save'),
        ),

        const SizedBox(height: 20),

        const Card(
          child: Padding(
            padding:
                EdgeInsets.all(14),
            child: Text(
              'Your pincode is stored locally. It will be used by future authorized live integrations.',
            ),
          ),
        ),
      ],
    );
  }
}
