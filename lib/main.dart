import 'package:flutter/material.dart';
import 'models/offer.dart';
import 'screens/app_shell.dart';
import 'services/local_store.dart';
import 'services/notification_service.dart';

void main() async { WidgetsFlutterBinding.ensureInitialized(); await NotificationService.instance.initialize(); runApp(const FavourApp()); }
class FavourController extends ChangeNotifier { FavourController(this._store); final LocalStore _store; AppData data=const AppData.empty(); bool loading=true; String? error; Future<void> load() async { try { data=await _store.load(); } catch (_) { error='Saved data could not be loaded.'; } loading=false; notifyListeners(); } Future<void> save(AppData next) async { data=next; notifyListeners(); await _store.save(next); } Future<void> addOffer(Offer offer) async { await save(data.copyWith(offers:[...data.offers,offer])); await NotificationService.instance.notifyIfMatched(offer,data.alerts); } }
class FavourApp extends StatefulWidget { const FavourApp({super.key}); @override State<FavourApp> createState()=>_FavourAppState(); }
class _FavourAppState extends State<FavourApp> { final controller=FavourController(LocalStore()); @override void initState(){super.initState();controller.load();} @override void dispose(){controller.dispose();super.dispose();} @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Favour',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff176b50)),scaffoldBackgroundColor:const Color(0xfff8faf7),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(16)),borderSide:BorderSide.none))),home:AnimatedBuilder(animation:controller,builder:(_,__){if(controller.loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));return AppShell(controller:controller);}));} }
