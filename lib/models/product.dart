enum Unit { gram, kilogram, millilitre, litre, piece }

extension UnitDetails on Unit {
  String get label => switch (this) {
        Unit.gram => 'g', Unit.kilogram => 'kg', Unit.millilitre => 'ml',
        Unit.litre => 'L', Unit.piece => 'pc',
      };
  String get normalizedLabel => switch (this) {
        Unit.gram || Unit.kilogram => 'kg', Unit.millilitre || Unit.litre => 'L', Unit.piece => 'pc',
      };
  double get normalizedMultiplier => switch (this) {
        Unit.gram || Unit.millilitre => 0.001, _ => 1,
      };
}

class Product {
  const Product({required this.name, this.brand = '', required this.packSize, required this.unit, this.packCount = 1});
  final String name;
  final String brand;
  final double packSize;
  final Unit unit;
  final int packCount;
  String get id => '${brand.trim().toLowerCase()}|${name.trim().toLowerCase()}|$packSize|${unit.name}|$packCount';
  String get displayName => brand.trim().isEmpty ? name : '$brand $name';
  String get packLabel => '${_number(packSize)} ${unit.label}${packCount > 1 ? ' × $packCount' : ''}';
  double get normalizedQuantity => packSize * packCount * unit.normalizedMultiplier;
  Map<String, dynamic> toJson() => {'name': name, 'brand': brand, 'packSize': packSize, 'unit': unit.name, 'packCount': packCount};
  factory Product.fromJson(Map<String, dynamic> json) => Product(name: json['name'] as String, brand: json['brand'] as String? ?? '', packSize: (json['packSize'] as num).toDouble(), unit: Unit.values.byName(json['unit'] as String), packCount: json['packCount'] as int? ?? 1);
}

String _number(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();
