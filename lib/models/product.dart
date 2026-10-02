class Product {
  const Product({required this.name, this.brand = '', required this.packSize, required this.unit});
  final String name; final String brand; final double packSize; final Unit unit;
  String get id => '${brand.trim().toLowerCase()}|${name.trim().toLowerCase()}|${packSize.toStringAsFixed(3)}|${unit.name}';
  String get displayName => brand.trim().isEmpty ? name : '$brand $name';
  String get packLabel => '${packSize % 1 == 0 ? packSize.toInt() : packSize} ${unit.label}';
  Map<String, dynamic> toJson() => {'name': name, 'brand': brand, 'packSize': packSize, 'unit': unit.name};
  factory Product.fromJson(Map<String, dynamic> value) => Product(name: value['name'] as String, brand: (value['brand'] ?? '') as String, packSize: (value['packSize'] as num).toDouble(), unit: Unit.values.byName(value['unit'] as String));
}
enum Unit { gram, kilogram, millilitre, litre, piece }
extension UnitDetails on Unit { String get label => const {Unit.gram: 'g', Unit.kilogram: 'kg', Unit.millilitre: 'ml', Unit.litre: 'L', Unit.piece: 'pc'}[this]!; String get baseLabel => const {Unit.gram: 'kg', Unit.kilogram: 'kg', Unit.millilitre: 'L', Unit.litre: 'L', Unit.piece: 'pc'}[this]!; double get baseFactor => const {Unit.gram: .001, Unit.kilogram: 1, Unit.millilitre: .001, Unit.litre: 1, Unit.piece: 1}[this]!; }
