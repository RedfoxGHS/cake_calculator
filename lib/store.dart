import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _storageKey = 'custo_do_bolo_v1';

/// Guarda tudo como JSON no próprio aparelho (no navegador, durante os testes).
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);

  final SharedPreferences? _prefs;
  final List<Product> products = [];
  final List<Market> markets = [];
  final List<Price> prices = [];
  final List<Pan> pans = [];
  final List<Recipe> recipes = [];
  Settings settings = Settings();

  static Future<AppStore> open() async {
    final store = AppStore._(await SharedPreferences.getInstance());
    store._load();
    return store;
  }

  /// Usado nos testes: começa com as formas padrão e não grava nada.
  factory AppStore.memory() => AppStore._(null).._seedPans();

  void _load() {
    final raw = _prefs?.getString(_storageKey);
    if (raw == null) {
      _seedPans();
      return;
    }
    final j = jsonDecode(raw) as Map<String, dynamic>;
    List<Map<String, dynamic>> list(String k) =>
        (j[k] as List? ?? []).cast<Map<String, dynamic>>();
    products.addAll(list('products').map(Product.fromJson));
    markets.addAll(list('markets').map(Market.fromJson));
    prices.addAll(list('prices').map(Price.fromJson));
    pans.addAll(list('pans').map(Pan.fromJson));
    recipes.addAll(list('recipes').map(Recipe.fromJson));
    if (j['settings'] != null) settings = Settings.fromJson(j['settings']);
    if (pans.isEmpty) _seedPans();
  }

  void _seedPans() {
    pans.addAll([
      Pan(id: newId(), shape: PanShape.round, a: 15),
      Pan(id: newId(), shape: PanShape.round, a: 20),
      Pan(id: newId(), shape: PanShape.round, a: 25),
      Pan(id: newId(), shape: PanShape.square, a: 20),
      Pan(id: newId(), shape: PanShape.rect, a: 30, b: 20),
    ]);
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final data = jsonEncode({
      'version': 1,
      'products': products.map((e) => e.toJson()).toList(),
      'markets': markets.map((e) => e.toJson()).toList(),
      'prices': prices.map((e) => e.toJson()).toList(),
      'pans': pans.map((e) => e.toJson()).toList(),
      'recipes': recipes.map((e) => e.toJson()).toList(),
      'settings': settings.toJson(),
    });
    await prefs.setString(_storageKey, data);
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ---------- consultas ----------

  Product? product(String id) => _find(products, (p) => p.id == id);
  Market? market(String id) => _find(markets, (m) => m.id == id);
  Pan? pan(String? id) => id == null ? null : _find(pans, (p) => p.id == id);
  Recipe? recipe(String id) => _find(recipes, (r) => r.id == id);

  Price? price(String productId, String marketId) =>
      _find(prices, (p) => p.productId == productId && p.marketId == marketId);

  List<Price> pricesOfMarket(String marketId) =>
      prices.where((p) => p.marketId == marketId).toList();

  List<Price> pricesOfProduct(String productId) =>
      prices.where((p) => p.productId == productId).toList();

  /// Produtos que ainda não têm preço neste mercado.
  List<Product> productsMissingIn(String marketId) =>
      products.where((p) => price(p.id, marketId) == null).toList();

  /// Produtos com preço em outro mercado mas não neste (dá para puxar).
  List<Product> importableTo(String marketId) => productsMissingIn(
    marketId,
  ).where((p) => prices.any((x) => x.productId == p.id)).toList();

  /// Preço mais recente do produto em qualquer mercado (para sugerir).
  Price? latestPrice(String productId) {
    final list = pricesOfProduct(productId)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.isEmpty ? null : list.first;
  }

  // ---------- alterações ----------

  Product addProduct(String name, UnitType unit) {
    final p = Product(id: newId(), name: name.trim(), unit: unit);
    products.add(p);
    _changed();
    return p;
  }

  void updateProduct(Product p, {String? name, UnitType? unit}) {
    if (name != null) p.name = name.trim();
    if (unit != null) p.unit = unit;
    _changed();
  }

  void deleteProduct(String id) {
    products.removeWhere((p) => p.id == id);
    prices.removeWhere((p) => p.productId == id);
    for (final r in recipes) {
      r.items.removeWhere((i) => i.productId == id);
    }
    _changed();
  }

  Market addMarket(String name) {
    final m = Market(id: newId(), name: name.trim());
    markets.add(m);
    _changed();
    return m;
  }

  void renameMarket(Market m, String name) {
    m.name = name.trim();
    _changed();
  }

  void deleteMarket(String id) {
    markets.removeWhere((m) => m.id == id);
    prices.removeWhere((p) => p.marketId == id);
    _changed();
  }

  void setPrice(
    String productId,
    String marketId,
    double value,
    double packageQty,
  ) {
    _setPrice(productId, marketId, value, packageQty);
    _changed();
  }

  /// Grava vários preços de uma vez (ao importar produtos para um mercado).
  void setPrices(List<Price> list) {
    for (final p in list) {
      _setPrice(p.productId, p.marketId, p.price, p.packageQty);
    }
    _changed();
  }

  void _setPrice(String productId, String marketId, double v, double pkg) {
    final existing = price(productId, marketId);
    if (existing != null) {
      existing
        ..price = v
        ..packageQty = pkg
        ..updatedAt = DateTime.now();
    } else {
      prices.add(
        Price(
          productId: productId,
          marketId: marketId,
          price: v,
          packageQty: pkg,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  void removePrice(String productId, String marketId) {
    prices.removeWhere(
      (p) => p.productId == productId && p.marketId == marketId,
    );
    _changed();
  }

  void savePan(Pan pan) {
    if (!pans.contains(pan)) pans.add(pan);
    _changed();
  }

  /// Retorna false se alguma receita usa a forma.
  bool deletePan(String id) {
    if (recipes.any((r) => r.panId == id)) return false;
    pans.removeWhere((p) => p.id == id);
    _changed();
    return true;
  }

  void saveRecipe(Recipe r) {
    final i = recipes.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      recipes[i] = r;
    } else {
      recipes.add(r);
    }
    _changed();
  }

  void deleteRecipe(String id) {
    recipes.removeWhere((r) => r.id == id);
    _changed();
  }

  void saveSettings() => _changed();

  static T? _find<T>(List<T> list, bool Function(T) test) {
    for (final e in list) {
      if (test(e)) return e;
    }
    return null;
  }
}
