import 'package:flutter/material.dart';

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
  final searchController = TextEditingController();

  final retailers = [
    'Blinkit',
    'Zepto',
    'Instamart',
    'BB Now',
    'Flipkart Minutes',
    'Amazon Now',
    'JioMart',
  ];

  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Favour',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Compare',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (selectedTab) {
      case 1:
        return _savedPage();
      case 2:
        return _historyPage();
      case 3:
        return _settingsPage();
      default:
        return _comparePage();
    }
  }

  Widget _comparePage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Your personal shopping assistant',
          style: Theme.of(context).textTheme.titleMedium,
        ),

        const SizedBox(height: 16),

        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'What do you want to buy?',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {
                setState(() {});
              },
            ),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) {
            setState(() {});
          },
        ),

        const SizedBox(height: 24),

        Text(
          searchController.text.isEmpty
              ? 'Shopping platforms'
              : 'Search: ${searchController.text}',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        ...retailers.map(
          (retailer) => _retailerCard(retailer),
        ),

        const SizedBox(height: 20),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: const [
                Icon(
                  Icons.auto_awesome,
                  size: 40,
                ),
                SizedBox(height: 10),
                Text(
                  'Favour will compare prices across your shopping apps and recommend the best option.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _retailerCard(String retailer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(retailer.substring(0, 1)),
        ),
        title: Text(retailer),
        subtitle: const Text(
          'Live price integration coming',
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: () {},
      ),
    );
  }

  Widget _savedPage() {
    return const Center(
      child: Text(
        '⭐ Saved products\n\nYour regular products will appear here.',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _historyPage() {
    return const Center(
      child: Text(
        '📊 Price History\n\nYour recorded prices will appear here.',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _settingsPage() {
    return const Center(
      child: Text(
        '⚙️ Settings\n\nYour location and shopping preferences will appear here.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
