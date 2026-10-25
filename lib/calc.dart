import 'dart:math' as math;

import 'models.dart';
import 'store.dart';

/// Uma receita dentro da simulação e quantas vezes ela entra no bolo.
class SimPart {
  SimPart(this.recipeId, this.times);
  final String recipeId;
  double times;
}

/// Camadas de recheio: cada bolo cortado em [cuts] discos, empilhados.
int layersFor(int count, int cuts) => math.max(0, count * cuts - 1);

/// Quantas vezes a receita precisa ser feita para [count] formas [target],
/// cada bolo cortado em [cuts] discos. Compara a área do fundo com a forma
/// em que a receita foi escrita e quantas formas ela rende.
double autoTimes(AppStore s, Recipe r, Pan? target, int count, {int cuts = 1}) {
  final base = s.pan(r.panId);
  final ratio = base == null || target == null || base.area <= 0
      ? 1.0
      : target.area / base.area;
  if (r.perLayer) return ratio * layersFor(count, cuts);
  return ratio * count / math.max(1, r.yieldPans);
}

/// Soma de tudo que o bolo usa, por produto (na unidade base).
Map<String, double> needs(AppStore s, List<SimPart> parts) {
  final out = <String, double>{};
  for (final part in parts) {
    final r = s.recipe(part.recipeId);
    if (r == null) continue;
    for (final it in r.items) {
      out[it.productId] = (out[it.productId] ?? 0) + it.qty * part.times;
    }
  }
  return out;
}

class MarketCost {
  MarketCost(this.market, this.total, this.missing);
  final Market market;
  final double total;

  /// Produtos sem preço neste mercado.
  final List<String> missing;
  bool get complete => missing.isEmpty;
}

/// Custo dos ingredientes comprando tudo em um só mercado.
MarketCost costAt(AppStore s, Map<String, double> need, Market m) {
  var total = 0.0;
  final missing = <String>[];
  need.forEach((pid, qty) {
    final p = s.price(pid, m.id);
    if (p == null) {
      missing.add(pid);
    } else {
      total += qty * p.perBase;
    }
  });
  return MarketCost(m, total, missing);
}

class MixCost {
  MixCost(this.total, this.choice, this.noPrice);
  final double total;

  /// Produto -> mercado onde comprar.
  final Map<String, String> choice;

  /// Produtos sem preço em nenhum dos mercados considerados.
  final List<String> noPrice;
  Set<String> get marketIds => choice.values.toSet();
}

MixCost _mixOver(AppStore s, Map<String, double> need, List<Market> ms) {
  var total = 0.0;
  final choice = <String, String>{};
  final noPrice = <String>[];
  need.forEach((pid, qty) {
    Price? best;
    for (final m in ms) {
      final p = s.price(pid, m.id);
      if (p != null && (best == null || p.perBase < best.perBase)) best = p;
    }
    if (best == null) {
      noPrice.add(pid);
    } else {
      total += qty * best.perBase;
      choice[pid] = best.marketId;
    }
  });
  return MixCost(total, choice, noPrice);
}

/// Pega cada produto no mercado mais barato, indo em no máximo [maxMarkets]
/// mercados. Testa todas as combinações (são poucos mercados).
MixCost? bestMix(AppStore s, Map<String, double> need, {int maxMarkets = 3}) {
  if (s.markets.isEmpty || need.isEmpty) return null;
  final all = _mixOver(s, need, s.markets);
  if (s.markets.length <= maxMarkets) return all;

  MixCost? best;
  for (final combo in _combos(s.markets, maxMarkets)) {
    final mix = _mixOver(s, need, combo);
    // Só vale a combinação que encontra tudo que dá pra encontrar.
    if (mix.noPrice.length > all.noPrice.length) continue;
    if (best == null || mix.total < best.total) best = mix;
  }
  return best ?? all;
}

Iterable<List<T>> _combos<T>(List<T> items, int max) sync* {
  final n = items.length;
  for (var mask = 1; mask < (1 << n); mask++) {
    var bits = 0;
    for (var m = mask; m > 0; m >>= 1) {
      bits += m & 1;
    }
    if (bits > max) continue;
    yield [
      for (var i = 0; i < n; i++)
        if (mask & (1 << i) != 0) items[i],
    ];
  }
}

class PriceBreakdown {
  PriceBreakdown({
    required this.ingredients,
    required this.extras,
    required this.laborPct,
    required this.profitPct,
  });
  final double ingredients;
  final double extras;
  final double laborPct;
  final double profitPct;

  double get cost => ingredients + extras;
  double get labor => cost * laborPct / 100;
  double get profit => cost * profitPct / 100;
  double get total => cost + labor + profit;

  /// Arredonda para cima, de 5 em 5 reais.
  double get rounded => (total / 5).ceil() * 5.0;
}
