import 'package:flutter/material.dart';

enum Retailer { blinkit, zepto, swiggyInstamart, bigBasketNow, flipkartMinutes, amazonNow, jioMart }

extension RetailerDetails on Retailer {
  String get name => const {Retailer.blinkit: 'Blinkit', Retailer.zepto: 'Zepto', Retailer.swiggyInstamart: 'Swiggy Instamart', Retailer.bigBasketNow: 'BigBasket Now', Retailer.flipkartMinutes: 'Flipkart Minutes', Retailer.amazonNow: 'Amazon Now', Retailer.jioMart: 'JioMart'}[this]!;
  String get shortName => const {Retailer.blinkit: 'B', Retailer.zepto: 'Z', Retailer.swiggyInstamart: 'S', Retailer.bigBasketNow: 'BB', Retailer.flipkartMinutes: 'F', Retailer.amazonNow: 'A', Retailer.jioMart: 'J'}[this]!;
  Color get color => const {Retailer.blinkit: Color(0xfff5c400), Retailer.zepto: Color(0xff7b2cbf), Retailer.swiggyInstamart: Color(0xfffc8019), Retailer.bigBasketNow: Color(0xff84c225), Retailer.flipkartMinutes: Color(0xff2874f0), Retailer.amazonNow: Color(0xffff9900), Retailer.jioMart: Color(0xffe30613)}[this]!;
}
const supportedRetailers = Retailer.values;
