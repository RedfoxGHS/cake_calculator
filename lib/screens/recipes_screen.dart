import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../calc.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'markets_screen.dart';

IconData categoryIcon(RecipeCategory c) => switch (c) {
  RecipeCategory.massa => Icons.cake_outlined,
  RecipeCategory.recheio => Icons.layers_outlined,
  RecipeCategory.cobertura => Icons.icecream_outlined,
  RecipeCategory.outro => Icons.restaurant_outlined,
};

/// Custo da receita uma vez, pegando cada item no mercado mais barato.
MixCost? recipeCost(AppStore s, Recipe r) =>
    bestMix(s, needs(s, [SimPart(r.id, 1)]));

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  RecipeCategory? _filter;

  void _new() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => RecipeEditScreen(category: _filter)),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final list =
        store.recipes
            .where((r) => _filter == null || r.category == _filter)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Receitas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.add),
        label: const Text('Receita'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final c in RecipeCategory.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: Icon(categoryIcon(c), size: 18),
                    label: Text(c.label),
                    selected: _filter == c,
                    onSelected: (_) => setState(() => _filter = c),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.menu_book,
                    title: _filter == null
                        ? 'Seu livro de receitas'
                        : 'Nenhuma receita de ${_filter!.label.toLowerCase()}',
                    text:
                        'Guarde massas, recheios e coberturas. Depois é só juntar na simulação.',
                    action: FilledButton.icon(
                      onPressed: _new,
                      icon: const Icon(Icons.add),
                      label: const Text('Escrever receita'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [for (final r in list) _RecipeTile(recipe: r)],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cost = recipeCost(store, recipe);
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: t.colorScheme.primaryContainer,
          child: Icon(
            categoryIcon(recipe.category),
            color: t.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(recipe.name, style: t.textTheme.titleMedium),
        subtitle: Text(
          '${recipe.category.label} · ${recipeYield(recipe, store.pan(recipe.panId))} · '
          '${recipe.items.length} ingredientes',
        ),
        trailing: cost == null
            ? null
            : Text(brl(cost.total), style: t.textTheme.titleSmall),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
          ),
        ),
      ),
    );
  }
}

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final r = store.recipe(recipeId);
    if (r == null) return const Scaffold();
    final cost = recipeCost(store, r);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(r.name),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RecipeEditScreen(recipe: r)),
            ),
          ),
          IconButton(
            tooltip: 'Excluir',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirm(
                    context,
                    'Excluir ${r.name}?',
                    'A receita sai do seu livro.',
                  ) &&
                  context.mounted) {
                Navigator.pop(context);
                store.deleteRecipe(r.id);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(categoryIcon(r.category), size: 18),
                label: Text(r.category.label),
              ),
              Chip(
                avatar: const Icon(Icons.crop_square, size: 18),
                label: Text(recipeYield(r, store.pan(r.panId))),
              ),
            ],
          ),
          const SectionTitle('Ingredientes'),
          Card(
            child: Column(
              children: [
                for (final it in r.items)
                  if (store.product(it.productId) case final p?)
                    ListTile(
                      dense: true,
                      title: Text(p.name, style: t.textTheme.bodyLarge),
                      trailing: Text(
                        fmtQty(it.qty, p.unit),
                        style: t.textTheme.bodyLarge,
                      ),
                    ),
              ],
            ),
          ),
          if (cost != null) ...[
            const SizedBox(height: 8),
            Text(
              'Custa cerca de ${brl(cost.total)} em ingredientes, pegando o mais barato.'
              '${cost.noPrice.isEmpty ? '' : ' Falta preço de ${cost.noPrice.length} item(ns).'}',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (r.notes.trim().isNotEmpty) ...[
            const SectionTitle('Modo de preparo'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  r.notes,
                  style: t.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RecipeEditScreen extends StatefulWidget {
  const RecipeEditScreen({super.key, this.recipe, this.category});
  final Recipe? recipe;
  final RecipeCategory? category;

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  late final _name = TextEditingController(text: widget.recipe?.name ?? '');
  late final _notes = TextEditingController(text: widget.recipe?.notes ?? '');
  late RecipeCategory _cat =
      widget.recipe?.category ?? widget.category ?? RecipeCategory.massa;
  String? _panId;
  late int _yield = widget.recipe?.yieldPans ?? 1;
  late bool _perLayer =
      widget.recipe?.perLayer ?? _cat == RecipeCategory.recheio;
  late final List<RecipeItem> _items = [
    for (final i in widget.recipe?.items ?? <RecipeItem>[])
      RecipeItem(productId: i.productId, qty: i.qty),
  ];

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _panId =
        widget.recipe?.panId ??
        (store.pans.length > 1 ? store.pans[1].id : store.pans.firstOrNull?.id);
  }

  Future<String?> _pickProduct() async {
    final store = context.read<AppStore>();
    final used = _items.map((i) => i.productId).toSet();
    final list = store.products.where((p) => !used.contains(p.id)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final r = await showModalBottomSheet<Object>(
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
                onTap: () => Navigator.pop(c, 'new'),
              ),
              const Divider(),
              for (final p in list)
                ListTile(
                  title: Text(p.name),
                  subtitle: Text(
                    store.pricesOfProduct(p.id).isEmpty
                        ? 'sem preço ainda'
                        : p.unit.label,
                  ),
                  onTap: () => Navigator.pop(c, p.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (r == 'new' && mounted) {
      final p = await showDialog<Product>(
        context: context,
        builder: (_) => const NewProductDialog(),
      );
      return p?.id;
    }
    return r is String ? r : null;
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Dê um nome para a receita');
      return;
    }
    final items = _items.where((i) => i.qty > 0).toList();
    final store = context.read<AppStore>();
    store.saveRecipe(
      Recipe(
        id: widget.recipe?.id ?? newId(),
        name: name,
        category: _cat,
        panId: _panId,
        items: items,
        notes: _notes.text,
        yieldPans: _yield,
        perLayer: _cat == RecipeCategory.recheio && _perLayer,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Nova receita' : 'Editar receita'),
        actions: [TextButton(onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Ex.: Massa de chocolate',
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<RecipeCategory>(
            showSelectedIcon: false,
            segments: [
              for (final c in RecipeCategory.values)
                ButtonSegment(value: c, label: Text(c.label)),
            ],
            selected: {_cat},
            onSelectionChanged: (s) => setState(() {
              _cat = s.first;
              // Recheio novo já começa "por camada", que é o mais comum.
              if (widget.recipe == null) {
                _perLayer = _cat == RecipeCategory.recheio;
              }
            }),
          ),
          const SizedBox(height: 16),
          if (_cat == RecipeCategory.recheio) ...[
            Card(
              child: SwitchListTile(
                value: _perLayer,
                onChanged: (v) => setState(() => _perLayer = v),
                title: const Text('Essa quantidade é para 1 camada'),
                subtitle: const Text(
                  'Na simulação o app multiplica pelas camadas do bolo.',
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            initialValue: _panId,
            decoration: InputDecoration(
              labelText: _cat == RecipeCategory.recheio && _perLayer
                  ? 'Camada da forma'
                  : 'Forma da receita',
              helperText:
                  'Na simulação o app aumenta ou diminui pela forma escolhida.',
            ),
            items: [
              for (final p in store.pans)
                DropdownMenuItem(value: p.id, child: Text(panLabel(p))),
            ],
            onChanged: (v) => setState(() => _panId = v),
          ),
          if (!(_cat == RecipeCategory.recheio && _perLayer)) ...[
            const SizedBox(height: 12),
            CountRow(
              label: 'Rende quantas formas',
              helper: 'Ex.: uma massa que você divide em 2 formas',
              value: _yield,
              max: 10,
              onChanged: (v) => setState(() => _yield = v),
            ),
          ],
          SectionTitle('Ingredientes', trailing: Text('${_items.length}')),
          for (final (i, it) in _items.indexed)
            if (store.product(it.productId) case final p?)
              Padding(
                key: ValueKey(it.productId),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(p.name, style: t.textTheme.bodyLarge),
                    ),
                    Expanded(
                      flex: 4,
                      child: NumInput(
                        value: it.qty == 0 ? null : it.qty,
                        suffix: p.unit.base,
                        onChanged: (v) => it.qty = v ?? 0,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remover',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _items.removeAt(i)),
                    ),
                  ],
                ),
              ),
          OutlinedButton.icon(
            onPressed: () async {
              final id = await _pickProduct();
              if (id != null) {
                setState(() => _items.add(RecipeItem(productId: id, qty: 0)));
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Adicionar ingrediente'),
          ),
          const SectionTitle('Modo de preparo'),
          TextField(
            controller: _notes,
            minLines: 4,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Opcional. Escreva do seu jeito.',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Salvar receita')),
        ],
      ),
    );
  }
}
