import '../models/offer.dart';
import '../models/product.dart';
import '../models/retailer.dart';

abstract interface class RetailerAdapter {
  Retailer get retailer;
  Future<List<Offer>> search(Product product, {required String pincode});
}

class UnavailableRetailerAdapter implements RetailerAdapter {
  const UnavailableRetailerAdapter(this.retailer);
  @override final Retailer retailer;
  @override Future<List<Offer>> search(Product product, {required String pincode}) async => const [];
}

class RetailerCatalog {
  RetailerCatalog({Iterable<RetailerAdapter>? adapters}) : _adapters = {for (final adapter in adapters ?? Retailer.values.map(UnavailableRetailerAdapter.new)) adapter.retailer: adapter};
  final Map<Retailer, RetailerAdapter> _adapters;
  Future<List<Offer>> searchAll(Product product, {required String pincode}) async => Future.wait(_adapters.values.map((adapter) => adapter.search(product, pincode: pincode))).then((lists) => lists.expand((list) => list).toList());
}
