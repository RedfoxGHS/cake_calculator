import 'package:cake_calculator/calc.dart';
import 'package:cake_calculator/format.dart';
import 'package:cake_calculator/models.dart';
import 'package:cake_calculator/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppStore s;
  late Product farinha, ovos;
  late Market a, b, c, d;
  late Recipe massa;

  setUp(() {
    s = AppStore.memory();
    farinha = s.addProduct('Farinha', UnitType.weight);
    ovos = s.addProduct('Ovos', UnitType.unit);
    a = s.addMarket('A');
    b = s.addMarket('B');
    c = s.addMarket('C');
    d = s.addMarket('D');
    s.setPrice(farinha.id, a.id, 6, 1000); // 0,006/g
    s.setPrice(farinha.id, b.id, 5, 1000); // mais barata
    s.setPrice(ovos.id, a.id, 24, 30); // 0,80/un
    s.setPrice(ovos.id, c.id, 21, 30); // 0,70/un
    s.setPrice(ovos.id, d.id, 18, 30); // 0,60/un, a mais barata
    final pan20 = s.pans.firstWhere(
      (p) => p.shape == PanShape.round && p.a == 20,
    );
    massa = Recipe(
      id: 'm',
      name: 'Massa',
      category: RecipeCategory.massa,
      panId: pan20.id,
      items: [
        RecipeItem(productId: farinha.id, qty: 200),
        RecipeItem(productId: ovos.id, qty: 4),
      ],
    );
    s.saveRecipe(massa);
  });

  test('ajusta a receita pela área da forma e pela quantidade', () {
    final pan25 = s.pans.firstWhere(
      (p) => p.shape == PanShape.round && p.a == 25,
    );
    expect(autoTimes(s, massa, pan25, 1), closeTo(1.5625, 1e-9));
    expect(autoTimes(s, massa, pan25, 2), closeTo(3.125, 1e-9));
  });

  test('receita que rende 2 formas não dobra com 2 formas', () {
    final pan20 = s.pans.firstWhere(
      (p) => p.shape == PanShape.round && p.a == 20,
    );
    final pan25 = s.pans.firstWhere(
      (p) => p.shape == PanShape.round && p.a == 25,
    );
    massa.yieldPans = 2;
    expect(autoTimes(s, massa, pan20, 2), closeTo(1, 1e-9));
    expect(autoTimes(s, massa, pan25, 2), closeTo(1.5625, 1e-9));
    expect(autoTimes(s, massa, pan20, 1, cuts: 3), closeTo(0.5, 1e-9));
  });

  test('recheio por camada multiplica pelas camadas', () {
    final pan20 = s.pans.firstWhere(
      (p) => p.shape == PanShape.round && p.a == 20,
    );
    final recheio = Recipe(
      id: 'r',
      name: 'Brigadeiro',
      category: RecipeCategory.recheio,
      panId: pan20.id,
      perLayer: true,
    );
    expect(layersFor(2, 2), 3); // 4 discos, 3 camadas
    expect(autoTimes(s, recheio, pan20, 2, cuts: 2), closeTo(3, 1e-9));
    expect(autoTimes(s, recheio, pan20, 1), 0);
  });

  test('custo em um mercado marca o que falta', () {
    final n = needs(s, [SimPart(massa.id, 1)]);
    final atA = costAt(s, n, a);
    expect(atA.complete, isTrue);
    expect(atA.total, closeTo(200 * 0.006 + 4 * 0.8, 1e-9));
    final atB = costAt(s, n, b);
    expect(atB.missing, [ovos.id]);
  });

  test('mais barato em cada usa no máximo 3 mercados', () {
    final n = needs(s, [SimPart(massa.id, 1)]);
    final mix = bestMix(s, n, maxMarkets: 3)!;
    expect(mix.choice[farinha.id], b.id);
    expect(mix.choice[ovos.id], d.id);
    expect(mix.total, closeTo(200 * 0.005 + 4 * 0.6, 1e-9));
    final one = bestMix(s, n, maxMarkets: 1)!;
    expect(one.marketIds, {a.id}); // único mercado que tem tudo
  });

  test('preço sugerido soma mão de obra e lucro sobre o custo', () {
    final pb = PriceBreakdown(
      ingredients: 40,
      extras: 10,
      laborPct: 40,
      profitPct: 30,
    );
    expect(pb.cost, 50);
    expect(pb.total, closeTo(85, 1e-9));
    expect(pb.rounded, 85);
  });

  test('lê números com vírgula', () {
    expect(parseNum('5,49'), 5.49);
    expect(parseNum('1.234,5'), 1234.5);
    expect(parseNum('7.5'), 7.5);
    expect(parseNum(''), isNull);
  });
}
