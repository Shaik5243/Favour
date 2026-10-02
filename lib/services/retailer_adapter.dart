import '../models/offer.dart';
import '../models/product.dart';
import '../models/retailer.dart';

/// Boundary for official retailer APIs or other explicitly authorised sources.
/// No implementation is supplied: Favour never scrapes or fabricates live prices.
abstract interface class RetailerAdapter { Retailer get retailer; Future<List<Offer>> findOffers(Product product, {String? pincode}); }
