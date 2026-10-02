import 'package:flutter/material.dart';
import '../main.dart';
import 'basket_screen.dart';
import 'history_screen.dart';
import 'saved_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget { const AppShell({super.key, required this.controller}); final FavourController controller; @override State<AppShell> createState() => _AppShellState(); }
class _AppShellState extends State<AppShell> { int tab = 0; @override Widget build(BuildContext context) { final pages = [SearchScreen(controller: widget.controller), SavedScreen(controller: widget.controller), BasketScreen(controller: widget.controller), HistoryScreen(controller: widget.controller), SettingsScreen(controller: widget.controller)]; return Scaffold(body: SafeArea(child: pages[tab]), bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value), destinations: const [NavigationDestination(icon: Icon(Icons.search), label: 'Search'), NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: 'Saved'), NavigationDestination(icon: Icon(Icons.shopping_basket_outlined), selectedIcon: Icon(Icons.shopping_basket), label: 'Basket'), NavigationDestination(icon: Icon(Icons.history), label: 'History'), NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings')])); } }
