import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../calc.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'recipes_screen.dart';

const _mix = 'mix';
const _maxMarkets = 3;

class SimulateScreen extends StatefulWidget {
  const SimulateScreen({super.key});

  @override
  State<SimulateScreen> createState() => _SimulateScreenState();
}

class _SimulateScreenState extends State<SimulateScreen> {
  String? _panId;
  int _count = 1;

  /// Em quantos discos cada bolo é cortado com a linha.
  int _cuts = 1;
  final List<SimPart> _parts = [];

  /// Partes em que ela mexeu na quantidade de vezes à mão.
  final Set<SimPart> _manual = {};
  String _source = _mix;
  late double _gas, _pack, _labor, _profit;
  double? _slices;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppStore>();
    _gas = s.settings.gas;
    _pack = s.settings.packaging;
    _labor = s.settings.laborPct;
    _profit = s.settings.profitPct;
  }

  void _recalcTimes(AppStore s) {
    final pan = s.pan(_panId);
    for (final p in _parts) {
      if (_manual.contains(p)) continue;
      final r = s.recipe(p.recipeId);
      if (r != null) p.times = autoTimes(s, r, pan, _count, cuts: _cuts);
    }
  }

  void _setShape(AppStore s, VoidCallback change) => setState(() {
    change();
    _recalcTimes(s);
  });

  String _quoteText(AppStore s, PriceBreakdown pb) {
    final names = [for (final p in _parts) s.recipe(p.recipeId)!.name];
    final discs = _count * _cuts;
    final slices = (_slices ?? 0) > 0 ? _slices!.round() : null;
    return [
      'Olá! Segue o orçamento do bolo:',
      '',
      '🎂 ${names.join(' + ')}',
      '${panLabel(s.pan(_panId))}'
          '${discs > 1 ? ' · $discs camadas de massa' : ''}',
      if (slices != null) 'Rende cerca de $slices fatias',
      '',
      'Valor: *${brl(pb.rounded)}*',
    ].join('\n');
  }

  Future<void> _sendQuote(AppStore s, PriceBreakdown pb) async {
    final c = TextEditingController(text: _quoteText(s, pb));
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mandar orçamento', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Pode mudar o texto antes de mandar.'),
            const SizedBox(height: 16),
            TextField(controller: c, minLines: 6, maxLines: 12),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.send),
              label: const Text('Abrir WhatsApp'),
            ),
          ],
        ),
      ),
    );
    if (send != true) return;
    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(c.text)}');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) toast(context, 'Não consegui abrir o WhatsApp');
  }

  Future<void> _addRecipe(AppStore s) async {
    if (s.recipes.isEmpty) {
      toast(context, 'Escreva uma receita primeiro, na aba Receitas');
      return;
    }
    final id = await showModalBottomSheet<String>(
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
              for (final cat in RecipeCategory.values)
                if (s.recipes.any((r) => r.category == cat)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      cat.label,
                      style: Theme.of(c).textTheme.titleSmall,
                    ),
                  ),
                  for (final r in s.recipes.where((r) => r.category == cat))
                    ListTile(
                      leading: Icon(categoryIcon(cat)),
                      title: Text(r.name),
                      subtitle: Text(panLabel(s.pan(r.panId))),
                      onTap: () => Navigator.pop(c, r.id),
                    ),
                ],
            ],
          ),
        ),
      ),
    );
    if (id == null) return;
    final r = s.recipe(id)!;
    setState(
      () => _parts.add(
        SimPart(id, autoTimes(s, r, s.pan(_panId), _count, cuts: _cuts)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    if (_panId == null || s.pan(_panId) == null) {
      _panId = s.pans.length > 1 ? s.pans[1].id : s.pans.firstOrNull?.id;
    }
    _parts.removeWhere((p) => s.recipe(p.recipeId) == null);
    if (_source != _mix && s.market(_source) == null) _source = _mix;

    final need = needs(s, _parts);
    final perMarket = [for (final m in s.markets) costAt(s, need, m)];
    final mix = bestMix(s, need, maxMarkets: _maxMarkets);
    final MarketCost? chosenMarket = _source == _mix
        ? null
        : perMarket.firstWhere((c) => c.market.id == _source);
    final ingredients = chosenMarket?.total ?? mix?.total ?? 0;
    final pb = PriceBreakdown(
      ingredients: ingredients,
      extras: _gas + _pack,
      laborPct: _labor,
      profitPct: _profit,
    );
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simular bolo'),
        actions: [
          if (_parts.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                _parts.clear();
                _manual.clear();
              }),
              child: const Text('Limpar'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ---------- forma ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(s.pans.length),
                    initialValue: _panId,
                    decoration: const InputDecoration(labelText: 'Forma'),
                    items: [
                      for (final p in s.pans)
                        DropdownMenuItem(value: p.id, child: Text(panLabel(p))),
                    ],
                    onChanged: (v) => _setShape(s, () => _panId = v),
                  ),
                  const SizedBox(height: 12),
                  CountRow(
                    label: 'Quantas formas',
                    value: _count,
                    onChanged: (v) => _setShape(s, () => _count = v),
                  ),
                  const SizedBox(height: 8),
                  CountRow(
                    label: 'Cortar cada bolo em',
                    helper: 'Discos separados com a linha',
                    value: _cuts,
                    max: 6,
                    onChanged: (v) => _setShape(s, () => _cuts = v),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: t.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      () {
                        final discs = _count * _cuts;
                        final layers = layersFor(_count, _cuts);
                        return '$discs ${discs == 1 ? 'disco' : 'discos'} de massa · '
                            '$layers ${layers == 1 ? 'camada' : 'camadas'} de recheio';
                      }(),
                      style: t.textTheme.titleSmall?.copyWith(
                        color: t.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------- receitas ----------
          const SectionTitle('O que vai no bolo'),
          if (_parts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Junte as receitas: a massa, o recheio, a cobertura. '
                  'O app ajusta as quantidades para a forma escolhida.',
                  style: t.textTheme.bodyLarge,
                ),
              ),
            ),
          for (final p in _parts) _partCard(s, p),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => _addRecipe(s),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar receita'),
          ),

          if (need.isNotEmpty) ...[
            // ---------- mercados ----------
            const SectionTitle('Quanto custa os ingredientes'),
            if (s.markets.isEmpty)
              const Card(
                child: ListTile(
                  title: Text(
                    'Cadastre um mercado e os preços na aba Mercados.',
                  ),
                ),
              ),
            if (mix != null)
              _sourceTile(
                id: _mix,
                title: s.markets.length > _maxMarkets
                    ? 'Mais barato em cada (até $_maxMarkets mercados)'
                    : 'Mais barato em cada mercado',
                subtitle: [
                  'Indo em ${mix.marketIds.length} ${mix.marketIds.length == 1 ? 'mercado' : 'mercados'}',
                  if (mix.noPrice.isNotEmpty) '${mix.noPrice.length} sem preço',
                ].join(' · '),
                value: mix.total,
                warn: mix.noPrice.isNotEmpty,
                highlight: true,
              ),
            for (final c
                in perMarket..sort((a, b) {
                  if (a.complete != b.complete) return a.complete ? -1 : 1;
                  return a.total.compareTo(b.total);
                }))
              _sourceTile(
                id: c.market.id,
                title: 'Tudo no ${c.market.name}',
                subtitle: c.complete
                    ? 'Tem todos os ingredientes'
                    : 'Falta preço de ${c.missing.length}: ${c.missing.map((id) => s.product(id)?.name).join(', ')}',
                value: c.total,
                warn: !c.complete,
              ),

            // ---------- lista de compras ----------
            SectionTitle(
              _source == _mix
                  ? 'Lista de compras'
                  : 'Lista de compras · ${s.market(_source)?.name}',
            ),
            Card(
              child: Column(
                children: [
                  for (final e in need.entries)
                    _needTile(s, e.key, e.value, mix),
                ],
              ),
            ),

            // ---------- custos e preço ----------
            const SectionTitle('Outros custos e ganho'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: NumInput(
                            label: 'Gás e luz',
                            prefix: 'R\$',
                            value: _gas,
                            onChanged: (v) => setState(() => _gas = v ?? 0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NumInput(
                            label: 'Embalagem, topo',
                            prefix: 'R\$',
                            value: _pack,
                            onChanged: (v) => setState(() => _pack = v ?? 0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: NumInput(
                            label: 'Mão de obra',
                            suffix: '%',
                            value: _labor,
                            onChanged: (v) => setState(() => _labor = v ?? 0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NumInput(
                            label: 'Lucro',
                            suffix: '%',
                            value: _profit,
                            onChanged: (v) => setState(() => _profit = v ?? 0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    NumInput(
                      label: 'Fatias (opcional)',
                      decimal: false,
                      value: _slices,
                      onChanged: (v) => setState(() => _slices = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _resultCard(context, pb, chosenMarket),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _sendQuote(s, pb),
              icon: const Icon(Icons.chat),
              label: const Text('Mandar orçamento no WhatsApp'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _partCard(AppStore s, SimPart p) {
    final r = s.recipe(p.recipeId)!;
    final base = s.pan(r.panId);
    final manual = _manual.contains(p);
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(categoryIcon(r.category), color: t.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: t.textTheme.titleMedium),
                      Text(
                        '${r.category.label} · ${recipeYield(r, base)}',
                        style: t.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tirar do bolo',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _parts.remove(p);
                    _manual.remove(p);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 130,
                  child: NumInput(
                    label: 'Vezes a receita',
                    suffix: '×',
                    value: double.parse(p.times.toStringAsFixed(2)),
                    onChanged: (v) => setState(() {
                      p.times = v ?? 0;
                      _manual.add(p);
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: manual
                      ? TextButton(
                          onPressed: () => setState(() {
                            _manual.remove(p);
                            _recalcTimes(s);
                          }),
                          child: const Text('Voltar ao cálculo pela forma'),
                        )
                      : Text(
                          r.perLayer
                              ? 'Ajustado pelas camadas e pela forma'
                              : 'Ajustado pela forma e quantidade',
                          style: t.textTheme.bodySmall?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceTile({
    required String id,
    required String title,
    required String subtitle,
    required double value,
    bool warn = false,
    bool highlight = false,
  }) {
    final t = Theme.of(context);
    final selected = _source == id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? t.colorScheme.primaryContainer : null,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: t.colorScheme.primary,
        ),
        title: Text(
          title,
          style: highlight ? t.textTheme.titleMedium : t.textTheme.bodyLarge,
        ),
        subtitle: Text(
          subtitle,
          style: warn ? TextStyle(color: t.colorScheme.error) : null,
        ),
        trailing: Text(brl(value), style: t.textTheme.titleMedium),
        onTap: () => setState(() => _source = id),
      ),
    );
  }

  Widget _needTile(AppStore s, String pid, double qty, MixCost? mix) {
    final p = s.product(pid)!;
    final marketId = _source == _mix ? mix?.choice[pid] : _source;
    final price = marketId == null ? null : s.price(pid, marketId);
    final t = Theme.of(context);
    String sub;
    if (price == null) {
      sub = 'sem preço${_source == _mix ? '' : ' neste mercado'}';
    } else {
      final packs = (qty / price.packageQty).ceil();
      sub = [
        if (_source == _mix) s.market(price.marketId)!.name,
        '$packs × ${fmtQty(price.packageQty, p.unit)}',
      ].join(' · ');
    }
    return ListTile(
      dense: true,
      title: Text(
        '${p.name} — ${fmtQty(qty.roundToDouble(), p.unit)}',
        style: t.textTheme.bodyLarge,
      ),
      subtitle: Text(
        sub,
        style: price == null ? TextStyle(color: t.colorScheme.error) : null,
      ),
      trailing: price == null
          ? null
          : Text(brl(qty * price.perBase), style: t.textTheme.bodyLarge),
    );
  }

  Widget _resultCard(
    BuildContext context,
    PriceBreakdown pb,
    MarketCost? chosen,
  ) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    Widget line(String a, String b, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a,
              style: bold ? t.textTheme.titleSmall : t.textTheme.bodyLarge,
            ),
          ),
          Text(b, style: bold ? t.textTheme.titleSmall : t.textTheme.bodyLarge),
        ],
      ),
    );
    final slices = (_slices ?? 0) > 0 ? _slices! : null;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line(
              chosen == null
                  ? 'Ingredientes (mais barato)'
                  : 'Ingredientes (${chosen.market.name})',
              brl(pb.ingredients),
            ),
            line('Gás, luz e embalagem', brl(pb.extras)),
            const Divider(),
            line('Custo do bolo', brl(pb.cost), bold: true),
            line('Mão de obra (${fmtNum(pb.laborPct)}%)', '+ ${brl(pb.labor)}'),
            line('Lucro (${fmtNum(pb.profitPct)}%)', '+ ${brl(pb.profit)}'),
            const Divider(),
            Text(
              'PREÇO SUGERIDO',
              style: t.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                letterSpacing: 1,
              ),
            ),
            Text(
              brl(pb.total),
              style: t.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onPrimaryContainer,
              ),
            ),
            Text(
              'Arredondando: ${brl(pb.rounded)}'
              '${slices == null ? '' : ' · ${brl(pb.total / slices)} a fatia'}',
              style: t.textTheme.bodyLarge,
            ),
            if (chosen != null && !chosen.complete) ...[
              const SizedBox(height: 8),
              Text(
                'Atenção: faltam ${chosen.missing.length} preços nesse mercado, então o custo está menor que o real.',
                style: TextStyle(color: cs.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
