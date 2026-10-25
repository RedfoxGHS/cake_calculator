import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';

class MarketsScreen extends StatelessWidget {
  const MarketsScreen({super.key});

  Future<void> _newMarket(BuildContext context) async {
    final store = context.read<AppStore>();
    final name = await askText(
      context,
      'Novo mercado',
      label: 'Nome do mercado',
      ok: 'Criar',
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final m = store.addMarket(name);
    if (store.importableTo(m.id).isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ImportProductsScreen(marketId: m.id)),
      );
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MarketDetailScreen(marketId: m.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mercados')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newMarket(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo mercado'),
      ),
      body: store.markets.isEmpty
          ? EmptyState(
              icon: Icons.storefront,
              title: 'Nenhum mercado ainda',
              text:
                  'Cadastre o mercado onde você compra e o preço de cada produto.',
              action: FilledButton.icon(
                onPressed: () => _newMarket(context),
                icon: const Icon(Icons.add),
                label: const Text('Cadastrar mercado'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [for (final m in store.markets) _MarketTile(market: m)],
            ),
    );
  }
}

class _MarketTile extends StatelessWidget {
  const _MarketTile({required this.market});
  final Market market;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final ps = store.pricesOfMarket(market.id);
    final stale = ps.where((p) => isStale(p.updatedAt)).length;
    final missing = store.importableTo(market.id).length;
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: t.colorScheme.primaryContainer,
          child: Icon(
            Icons.storefront,
            color: t.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(market.name, style: t.textTheme.titleMedium),
        subtitle: Text(
          [
            '${ps.length} ${ps.length == 1 ? 'produto' : 'produtos'}',
            if (missing > 0) '$missing sem preço aqui',
            if (stale > 0) '$stale desatualizados',
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MarketDetailScreen(marketId: market.id),
          ),
        ),
      ),
    );
  }
}

class MarketDetailScreen extends StatefulWidget {
  const MarketDetailScreen({super.key, required this.marketId});
  final String marketId;

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  String _q = '';

  Future<void> _addProduct(AppStore store, Market m) async {
    final missing = store.productsMissingIn(m.id)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(c).size.height * .75,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle),
                title: const Text('Produto novo'),
                subtitle: const Text('Ainda não cadastrado em nenhum mercado'),
                onTap: () => Navigator.pop(c, 'new'),
              ),
              if (missing.isNotEmpty) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Já cadastrados em outros mercados'),
                ),
                for (final p in missing)
                  ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.unit.label),
                    onTap: () => Navigator.pop(c, p),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    Product? product = picked is Product ? picked : null;
    if (picked == 'new') {
      product = await showDialog<Product>(
        context: context,
        builder: (_) => const NewProductDialog(),
      );
    }
    if (product == null || !mounted) return;
    await showPriceSheet(context, product, m);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final m = store.market(widget.marketId);
    if (m == null) return const Scaffold();
    final missing = store.importableTo(m.id).length;
    final items =
        store
            .pricesOfMarket(m.id)
            .map((p) => (p, store.product(p.productId)!))
            .where((e) => e.$2.name.toLowerCase().contains(_q.toLowerCase()))
            .toList()
          ..sort(
            (a, b) =>
                a.$2.name.toLowerCase().compareTo(b.$2.name.toLowerCase()),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(m.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                final n = await askText(
                  context,
                  'Renomear mercado',
                  initial: m.name,
                );
                if (n != null && n.isNotEmpty) store.renameMarket(m, n);
              } else if (v == 'delete') {
                final ok = await confirm(
                  context,
                  'Excluir ${m.name}?',
                  'Os preços deste mercado serão apagados. Os produtos continuam nos outros mercados.',
                );
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  store.deleteMarket(m.id);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Renomear')),
              PopupMenuItem(value: 'delete', child: Text('Excluir mercado')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addProduct(store, m),
        icon: const Icon(Icons.add),
        label: const Text('Produto'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (missing > 0)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.download),
                title: Text(
                  '$missing ${missing == 1 ? 'produto' : 'produtos'} de outros mercados',
                ),
                subtitle: const Text('Puxe para cá e só ajuste o preço'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImportProductsScreen(marketId: m.id),
                  ),
                ),
              ),
            ),
          if (store.pricesOfMarket(m.id).length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar produto',
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          const SizedBox(height: 8),
          if (store.pricesOfMarket(m.id).isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.sell_outlined,
                title: 'Nenhum produto aqui',
                text:
                    'Toque em “Produto” e coloque o preço da embalagem, do jeito que está na prateleira.',
              ),
            ),
          for (final (p, prod) in items)
            _PriceTile(price: p, product: prod, market: m),
        ],
      ),
    );
  }
}

class _PriceTile extends StatelessWidget {
  const _PriceTile({
    required this.price,
    required this.product,
    required this.market,
  });
  final Price price;
  final Product product;
  final Market market;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final others = store.pricesOfProduct(product.id);
    final cheapest =
        others.length > 1 &&
        others.every((o) => price.perBase <= o.perBase + 1e-9);
    final t = Theme.of(context);
    final stale = isStale(price.updatedAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
        title: Row(
          children: [
            Flexible(child: Text(product.name, style: t.textTheme.titleMedium)),
            if (cheapest) ...[
              const SizedBox(width: 8),
              _Pill(
                'mais barato',
                t.colorScheme.tertiaryContainer,
                t.colorScheme.onTertiaryContainer,
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${fmtQty(price.packageQty, product.unit)} · ${perRef(price, product.unit)}\n'
          'Atualizado ${ago(price.updatedAt)}',
          style: stale ? TextStyle(color: t.colorScheme.error) : null,
        ),
        isThreeLine: true,
        trailing: Text(brl(price.price), style: t.textTheme.titleMedium),
        onTap: () => showPriceSheet(context, product, market),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.bg, this.fg);
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

/// Folha para digitar/atualizar o preço de um produto em um mercado.
Future<void> showPriceSheet(
  BuildContext context,
  Product product,
  Market market,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PriceSheet(product: product, market: market),
  );
}

class _PriceSheet extends StatefulWidget {
  const _PriceSheet({required this.product, required this.market});
  final Product product;
  final Market market;

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  double? _price;
  double? _pkg;
  late final Price? _existing;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _existing = store.price(widget.product.id, widget.market.id);
    final ref = _existing ?? store.latestPrice(widget.product.id);
    _price = _existing?.price;
    _pkg = ref?.packageQty;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final u = widget.product.unit;
    final pkg = _pkg ?? PackUnit.of(u).first.factor;
    final per = (_price ?? 0) > 0 && pkg > 0 ? _price! / pkg * u.refQty : null;
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.product.name, style: t.textTheme.titleLarge),
          Text('no ${widget.market.name}', style: t.textTheme.bodyMedium),
          const SizedBox(height: 16),
          NumInput(
            label: 'Preço da embalagem',
            prefix: 'R\$',
            value: _price,
            autofocus: true,
            onChanged: (v) => setState(() => _price = v),
          ),
          const SizedBox(height: 12),
          PackageInput(
            unit: u,
            baseQty: _pkg,
            onChanged: (v) => setState(() => _pkg = v),
          ),
          const SizedBox(height: 12),
          Text(
            per == null
                ? 'Coloque o preço para ver quanto sai o ${u.refLabel}.'
                : 'Sai ${brl(per)} o ${u.refLabel}',
            style: t.textTheme.titleMedium?.copyWith(
              color: t.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_price ?? 0) > 0 && pkg > 0
                ? () {
                    store.setPrice(
                      widget.product.id,
                      widget.market.id,
                      _price!,
                      pkg,
                    );
                    Navigator.pop(context);
                  }
                : null,
            child: const Text('Salvar preço'),
          ),
          if (_existing != null)
            TextButton(
              onPressed: () {
                store.removePrice(widget.product.id, widget.market.id);
                Navigator.pop(context);
              },
              child: const Text('Tirar deste mercado'),
            ),
        ],
      ),
    );
  }
}

class NewProductDialog extends StatefulWidget {
  const NewProductDialog({super.key, this.initialName = ''});
  final String initialName;

  @override
  State<NewProductDialog> createState() => _NewProductDialogState();
}

class _NewProductDialogState extends State<NewProductDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  UnitType _unit = UnitType.weight;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Produto novo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Ex.: Leite condensado',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Como é medido?'),
          const SizedBox(height: 8),
          SegmentedButton<UnitType>(
            segments: const [
              ButtonSegment(value: UnitType.weight, label: Text('Peso')),
              ButtonSegment(value: UnitType.volume, label: Text('Litro')),
              ButtonSegment(value: UnitType.unit, label: Text('Unid.')),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => setState(() => _unit = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final n = _name.text.trim();
            if (n.isEmpty) return;
            Navigator.pop(
              context,
              context.read<AppStore>().addProduct(n, _unit),
            );
          },
          child: const Text('Criar'),
        ),
      ],
    );
  }
}

/// Puxa produtos já cadastrados em outros mercados para este, com o preço
/// sugerido para ela só ajustar.
class ImportProductsScreen extends StatefulWidget {
  const ImportProductsScreen({super.key, required this.marketId});
  final String marketId;

  @override
  State<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportRow {
  _ImportRow(this.product, this.ref)
    : price = ref?.price,
      pkg = ref?.packageQty;
  final Product product;
  final Price? ref;
  bool selected = true;
  double? price;
  double? pkg;
}

class _ImportProductsScreenState extends State<ImportProductsScreen> {
  late final List<_ImportRow> _rows;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _rows =
        store
            .importableTo(widget.marketId)
            .map((p) => _ImportRow(p, store.latestPrice(p.id)))
            .toList()
          ..sort(
            (a, b) => a.product.name.toLowerCase().compareTo(
              b.product.name.toLowerCase(),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final m = store.market(widget.marketId)!;
    final chosen = _rows
        .where((r) => r.selected && (r.price ?? 0) > 0 && (r.pkg ?? 0) > 0)
        .toList();
    final t = Theme.of(context);
    final allOn = _rows.every((r) => r.selected);

    return Scaffold(
      appBar: AppBar(
        title: Text('Produtos no ${m.name}'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              for (final r in _rows) {
                r.selected = !allOn;
              }
            }),
            child: Text(allOn ? 'Desmarcar todos' : 'Marcar todos'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(
            'Esses produtos você já tem em outros mercados. O preço veio de lá: '
            'ajuste para o preço deste mercado e desmarque o que ele não vende.',
            style: t.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          for (final r in _rows)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CheckboxListTile(
                      value: r.selected,
                      contentPadding: const EdgeInsets.only(left: 4),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        r.product.name,
                        style: t.textTheme.titleMedium,
                      ),
                      subtitle: r.ref == null
                          ? null
                          : Text(
                              '${store.market(r.ref!.marketId)?.name}: ${brl(r.ref!.price)} '
                              '(${fmtQty(r.ref!.packageQty, r.product.unit)})',
                            ),
                      onChanged: (v) => setState(() => r.selected = v ?? false),
                    ),
                    if (r.selected)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: NumInput(
                                label: 'Preço aqui',
                                prefix: 'R\$',
                                value: r.price,
                                onChanged: (v) => setState(() => r.price = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 5,
                              child: PackageInput(
                                unit: r.product.unit,
                                baseQty: r.pkg,
                                onChanged: (v) => setState(() => r.pkg = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Pular'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: chosen.isEmpty
                      ? null
                      : () {
                          store.setPrices([
                            for (final r in chosen)
                              Price(
                                productId: r.product.id,
                                marketId: m.id,
                                price: r.price!,
                                packageQty: r.pkg!,
                                updatedAt: DateTime.now(),
                              ),
                          ]);
                          toast(
                            context,
                            chosen.length == 1
                                ? '1 produto adicionado'
                                : '${chosen.length} produtos adicionados',
                          );
                          Navigator.pop(context);
                        },
                  child: Text('Adicionar ${chosen.length}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
