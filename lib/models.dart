import 'dart:math' as math;

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 20).toRadixString(36)}';

/// Como o produto é medido. Quantidades são guardadas sempre na unidade base
/// (gramas, mililitros ou unidades).
enum UnitType {
  weight('Peso', 'g', 'kg'),
  volume('Volume', 'ml', 'L'),
  unit('Unidade', 'un', 'un');

  const UnitType(this.label, this.base, this.big);
  final String label;
  final String base;
  final String big;

  /// Quantidade de referência para exibir preço (1 kg, 1 L, 1 un).
  double get refQty => this == UnitType.unit ? 1 : 1000;
  String get refLabel => this == UnitType.unit ? 'un' : big;
}

class Product {
  Product({required this.id, required this.name, required this.unit});
  final String id;
  String name;
  UnitType unit;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'unit': unit.name};
  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'],
    name: j['name'],
    unit: UnitType.values.byName(j['unit']),
  );
}

class Market {
  Market({required this.id, required this.name});
  final String id;
  String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Market.fromJson(Map<String, dynamic> j) =>
      Market(id: j['id'], name: j['name']);
}

/// Preço de um produto em um mercado: o valor pago por uma embalagem.
class Price {
  Price({
    required this.productId,
    required this.marketId,
    required this.price,
    required this.packageQty,
    required this.updatedAt,
  });
  final String productId;
  final String marketId;
  double price;

  /// Tamanho da embalagem na unidade base (ex.: 1000 para 1 kg).
  double packageQty;
  DateTime updatedAt;

  double get perBase => packageQty > 0 ? price / packageQty : 0;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'marketId': marketId,
    'price': price,
    'packageQty': packageQty,
    'updatedAt': updatedAt.toIso8601String(),
  };
  factory Price.fromJson(Map<String, dynamic> j) => Price(
    productId: j['productId'],
    marketId: j['marketId'],
    price: (j['price'] as num).toDouble(),
    packageQty: (j['packageQty'] as num).toDouble(),
    updatedAt: DateTime.parse(j['updatedAt']),
  );
}

enum PanShape {
  round('Redonda'),
  square('Quadrada'),
  rect('Retangular');

  const PanShape(this.label);
  final String label;
}

class Pan {
  Pan({
    required this.id,
    required this.shape,
    required this.a,
    this.b = 0,
    this.name = '',
  });
  final String id;
  PanShape shape;

  /// Diâmetro (redonda), lado (quadrada) ou comprimento (retangular), em cm.
  double a;

  /// Largura da retangular, em cm.
  double b;
  String name;

  double get area => switch (shape) {
    PanShape.round => math.pi * (a / 2) * (a / 2),
    PanShape.square => a * a,
    PanShape.rect => a * b,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'shape': shape.name,
    'a': a,
    'b': b,
    'name': name,
  };
  factory Pan.fromJson(Map<String, dynamic> j) => Pan(
    id: j['id'],
    shape: PanShape.values.byName(j['shape']),
    a: (j['a'] as num).toDouble(),
    b: (j['b'] as num? ?? 0).toDouble(),
    name: j['name'] ?? '',
  );
}

enum RecipeCategory {
  massa('Massa'),
  recheio('Recheio'),
  cobertura('Cobertura'),
  outro('Outro');

  const RecipeCategory(this.label);
  final String label;
}

class RecipeItem {
  RecipeItem({required this.productId, required this.qty});
  String productId;
  double qty;

  Map<String, dynamic> toJson() => {'productId': productId, 'qty': qty};
  factory RecipeItem.fromJson(Map<String, dynamic> j) =>
      RecipeItem(productId: j['productId'], qty: (j['qty'] as num).toDouble());
}

class Recipe {
  Recipe({
    required this.id,
    required this.name,
    required this.category,
    this.panId,
    List<RecipeItem>? items,
    this.notes = '',
  }) : items = items ?? [];
  final String id;
  String name;
  RecipeCategory category;

  /// Forma para a qual a receita foi escrita. Serve de base para recalcular.
  String? panId;
  List<RecipeItem> items;

  /// Modo de preparo / anotações.
  String notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'panId': panId,
    'items': items.map((e) => e.toJson()).toList(),
    'notes': notes,
  };
  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
    id: j['id'],
    name: j['name'],
    category: RecipeCategory.values.byName(j['category']),
    panId: j['panId'],
    items: (j['items'] as List)
        .map((e) => RecipeItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    notes: j['notes'] ?? '',
  );
}

class Settings {
  Settings({
    this.laborPct = 40,
    this.profitPct = 30,
    this.gas = 6,
    this.packaging = 5,
  });
  double laborPct;
  double profitPct;
  double gas;
  double packaging;

  Map<String, dynamic> toJson() => {
    'laborPct': laborPct,
    'profitPct': profitPct,
    'gas': gas,
    'packaging': packaging,
  };
  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    laborPct: (j['laborPct'] as num).toDouble(),
    profitPct: (j['profitPct'] as num).toDouble(),
    gas: (j['gas'] as num).toDouble(),
    packaging: (j['packaging'] as num).toDouble(),
  );
}
