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

String slug(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

class PriceEntry {
  final String retailer;
  final double price;
  final DateTime time;
  PriceEntry(this.retailer, this.price, this.time);
  Map<String,dynamic> toJson()=>{'retailer':retailer,'price':price,'time':time.toIso8601String()};
  factory PriceEntry.fromJson(Map<String,dynamic> j)=>PriceEntry(
    j['retailer'], (j['price'] as num).toDouble(), DateTime.parse(j['time']));
}

class FavourApp extends StatelessWidget {
  const FavourApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'Favour',
    theme:ThemeData(colorSchemeSeed:Colors.indigo,useMaterial3:true),
    home:const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override State<Home> createState()=>_HomeState();
}

class _HomeState extends State<Home> {
  final q=TextEditingController();
  final pin=TextEditingController();
  List<PriceEntry> history=[];
  List<String> saved=[];
  String query='';
  int tab=0;

  @override void initState(){super.initState();load();}

  Future<void> load() async {
    final p=await SharedPreferences.getInstance();
    final h=p.getStringList('history')??[];
    setState((){
      history=h.map((x)=>PriceEntry.fromJson(jsonDecode(x))).toList();
      saved=p.getStringList('saved')??[];
      pin.text=p.getString('pin')??'';
    });
  }

  Future<void> persist() async {
    final p=await SharedPreferences.getInstance();
    await p.setStringList('history',history.map((x)=>jsonEncode(x.toJson())).toList());
    await p.setStringList('saved',saved);
    await p.setString('pin',pin.text);
  }

  Future<void> addPrice(String retailer) async {
    final c=TextEditingController();
    await showDialog(context:context,builder:(_)=>AlertDialog(
      title:Text('Record $retailer price'),
      content:TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:const InputDecoration(prefixText:'₹ ',hintText:'Price')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),
        FilledButton(onPressed:(){
          final v=double.tryParse(c.text.trim());
          if(v!=null && v>0){
            setState(()=>history.add(PriceEntry(retailer,v,DateTime.now())));
            persist();
          }
          Navigator.pop(context);
        },child:const Text('Save'))
      ],
    ));
  }

  Future<void> openRetailer(String retailer) async {
    final queryUri=Uri.encodeComponent(query.trim().isEmpty?'groceries':query.trim());
    final urls={
      'Blinkit':'https://blinkit.com/s/?q=$queryUri',
      'Zepto':'https://www.zepto.com/search?query=$queryUri',
      'Instamart':'https://www.swiggy.com/instamart/search?query=$queryUri',
      'BB Now':'https://www.bigbasket.com/ps/?q=$queryUri',
      'Flipkart Minutes':'https://www.flipkart.com/search?q=$queryUri',
      'Amazon Now':'https://www.amazon.in/s?k=$queryUri',
      'JioMart':'https://www.jiomart.com/search/$queryUri',
    };
    final u=Uri.parse(urls[retailer]!);
    await launchUrl(u,mode:LaunchMode.externalApplication);
  }

  Map<String,double> currentPrices(){
    final m=<String,double>{};
    for(final e in history.where((x)=>x.time.difference(DateTime.now()).inDays.abs()<2)){
      m[e.retailer]=e.price;
    }
    return m;
  }

  double? bestPrice(){
    final m=currentPrices();
    if(m.isEmpty)return null;
    return m.values.reduce((a,b)=>a<b?a:b);
  }

  String? bestRetailer(){
    final m=currentPrices();
    if(m.isEmpty)return null;
    return m.entries.reduce((a,b)=>a.value<b.value?a:b).key;
  }

  @override Widget build(BuildContext context){
    final pages=[home(),savedPage(),historyPage(),settingsPage()];
    return Scaffold(
      body:SafeArea(child:pages[tab]),
      bottomNavigationBar:NavigationBar(
        selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),
        destinations:const[
          NavigationDestination(icon:Icon(Icons.search),label:'Compare'),
          NavigationDestination(icon:Icon(Icons.star_outline),label:'Saved'),
          NavigationDestination(icon:Icon(Icons.history),label:'History'),
          NavigationDestination(icon:Icon(Icons.settings_outlined),label:'Settings'),
        ]),
    );
  }

  Widget home()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text('Favour',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
    const Text('Your personal shopping assistant'),
    const SizedBox(height:16),
    TextField(controller:q,onChanged:(v)=>setState(()=>query=v),
      onSubmitted:(_)=>setState((){}),
      decoration:InputDecoration(hintText:'What do you want to buy?',prefixIcon:const Icon(Icons.search),
        suffixIcon:IconButton(onPressed:()=>setState((){}),icon:const Icon(Icons.arrow_forward)),
        filled:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none))),
    const SizedBox(height:14),
    if(bestPrice()!=null) Card(
      child:ListTile(
        leading:const CircleAvatar(child:Icon(Icons.emoji_events)),
        title:Text('Best recorded price: ₹${bestPrice()!.toStringAsFixed(0)}'),
        subtitle:Text(bestRetailer()!),
      )),
    const SizedBox(height:8),
    Text('Retailers',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    ...retailers.map((r)=>retailerCard(r)),
    const SizedBox(height:16),
    const Card(child:Padding(padding:EdgeInsets.all(14),child:Text(
      'Live price note: Favour does not fake live prices. For retailers without an authorized live API, use Open to check the current price and Record price to save it. Favour then builds your own price history.'))),
  ]);

  Widget retailerCard(String r){
    final entries=history.where((e)=>e.retailer==r).toList()..sort((a,b)=>b.time.compareTo(a.time));
    final latest=entries.isEmpty?null:entries.first;
    return Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(
      leading:CircleAvatar(child:Text(r[0])),
      title:Text(r),
      subtitle:latest==null?const Text('No price recorded yet'):Text('Latest: ₹${latest.price.toStringAsFixed(0)}'),
      trailing:Wrap(spacing:0,children:[
        IconButton(tooltip:'Open retailer',onPressed:()=>openRetailer(r),icon:const Icon(Icons.open_in_new)),
        IconButton(tooltip:'Record price',onPressed:()=>addPrice(r),icon:const Icon(Icons.add_circle_outline)),
      ]),
    ));
  }

  Widget savedPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text('Saved items',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
    const SizedBox(height:12),
    if(saved.isEmpty) const Text('Save products here in the next step.'),
    ...saved.map((x)=>ListTile(title:Text(x),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:(){
      setState(()=>saved.remove(x));persist();
    }))),
  ]);

  Widget historyPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text('Price history',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
    const SizedBox(height:12),
    if(history.isEmpty) const Text('No recorded prices yet.'),
    ...history.reversed.map((e)=>ListTile(
      leading:const Icon(Icons.price_check),
      title:Text('${e.retailer}  •  ₹${e.price.toStringAsFixed(0)}'),
      subtitle:Text(e.time.toLocal().toString().substring(0,16)),
    )),
  ]);

  Widget settingsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text('Settings',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
    const SizedBox(height:12),
    TextField(controller:pin,keyboardType:TextInputType.number,
      decoration:const InputDecoration(labelText:'My pincode',prefixIcon:Icon(Icons.location_on))),
    const SizedBox(height:12),
    FilledButton(onPressed:()async{await persist();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Saved')));},
      child:const Text('Save settings')),
    const SizedBox(height:20),
    const Text('Favour will use this pincode for future authorized retailer integrations.'),
  ]);
}
