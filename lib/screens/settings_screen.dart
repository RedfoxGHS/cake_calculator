import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final st = s.settings;
    final t = Theme.of(context);
    final products = [...s.products]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionTitle('Valores padrão de cada bolo'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: NumInput(
                          label: 'Mão de obra',
                          suffix: '%',
                          value: st.laborPct,
                          onChanged: (v) {
                            st.laborPct = v ?? 0;
                            s.saveSettings();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: NumInput(
                          label: 'Lucro',
                          suffix: '%',
                          value: st.profitPct,
                          onChanged: (v) {
                            st.profitPct = v ?? 0;
                            s.saveSettings();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: NumInput(
                          label: 'Gás e luz',
                          prefix: 'R\$',
                          value: st.gas,
                          onChanged: (v) {
                            st.gas = v ?? 0;
                            s.saveSettings();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: NumInput(
                          label: 'Embalagem',
                          prefix: 'R\$',
                          value: st.packaging,
                          onChanged: (v) {
                            st.packaging = v ?? 0;
                            s.saveSettings();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esses valores já vêm preenchidos na simulação, e dá pra mudar em cada bolo.',
                    style: t.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          SectionTitle(
            'Minhas formas',
            trailing: TextButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const PanDialog(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Forma'),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final p in s.pans)
                  ListTile(
                    leading: Icon(switch (p.shape) {
                      PanShape.round => Icons.circle_outlined,
                      PanShape.square => Icons.crop_square,
                      PanShape.rect => Icons.crop_landscape,
                    }),
                    title: Text(panLabel(p)),
                    subtitle: Text(
                      'Fundo de ${fmtNum(p.area.roundToDouble())} cm²',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => PanDialog(pan: p),
                    ),
                  ),
              ],
            ),
          ),
          SectionTitle('Produtos', trailing: Text('${products.length}')),
          if (products.isEmpty)
            Text(
              'Os produtos aparecem aqui quando você cadastra nos mercados.',
              style: t.textTheme.bodyMedium,
            )
          else
            Card(
              child: Column(
                children: [
                  for (final p in products)
                    ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                        '${p.unit.label} · em ${s.pricesOfProduct(p.id).length} mercado(s)',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'rename') {
                            final n = await askText(
                              context,
                              'Renomear produto',
                              initial: p.name,
                            );
                            if (n != null && n.isNotEmpty) {
                              s.updateProduct(p, name: n);
                            }
                          } else if (await confirm(
                            context,
                            'Excluir ${p.name}?',
                            'Sai de todos os mercados e de todas as receitas.',
                          )) {
                            s.deleteProduct(p.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text('Renomear'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Excluir'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PanDialog extends StatefulWidget {
  const PanDialog({super.key, this.pan});
  final Pan? pan;

  @override
  State<PanDialog> createState() => _PanDialogState();
}

class _PanDialogState extends State<PanDialog> {
  late PanShape _shape = widget.pan?.shape ?? PanShape.round;
  late double? _a = widget.pan?.a;
  late double? _b = widget.pan?.b == 0 ? null : widget.pan?.b;
  late final _name = TextEditingController(text: widget.pan?.name ?? '');

  bool get _valid =>
      (_a ?? 0) > 0 && (_shape != PanShape.rect || (_b ?? 0) > 0);

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    return AlertDialog(
      title: Text(widget.pan == null ? 'Nova forma' : 'Editar forma'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<PanShape>(
              showSelectedIcon: false,
              segments: [
                for (final sh in PanShape.values)
                  ButtonSegment(value: sh, label: Text(sh.label)),
              ],
              selected: {_shape},
              onSelectionChanged: (v) => setState(() => _shape = v.first),
            ),
            const SizedBox(height: 16),
            NumInput(
              label: switch (_shape) {
                PanShape.round => 'Diâmetro',
                PanShape.square => 'Lado',
                PanShape.rect => 'Comprimento',
              },
              suffix: 'cm',
              value: _a,
              onChanged: (v) => setState(() => _a = v),
            ),
            if (_shape == PanShape.rect) ...[
              const SizedBox(height: 12),
              NumInput(
                label: 'Largura',
                suffix: 'cm',
                value: _b,
                onChanged: (v) => setState(() => _b = v),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Apelido (opcional)',
                hintText: 'Ex.: Forma da vó',
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.pan != null)
          TextButton(
            onPressed: () {
              if (s.deletePan(widget.pan!.id)) {
                Navigator.pop(context);
              } else {
                toast(
                  context,
                  'Uma receita usa essa forma. Troque a forma da receita antes.',
                );
              }
            },
            child: const Text('Excluir'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _valid
              ? () {
                  final p = widget.pan ?? Pan(id: newId(), shape: _shape, a: 0);
                  p
                    ..shape = _shape
                    ..a = _a!
                    ..b = _shape == PanShape.rect ? _b! : 0
                    ..name = _name.text.trim();
                  s.savePan(p);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
