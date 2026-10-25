import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'models.dart';

/// Campo numérico que aceita vírgula. Guarda o próprio controller e só
/// sobrescreve o texto quando o valor muda por fora.
class NumInput extends StatefulWidget {
  const NumInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.prefix,
    this.suffix,
    this.decimal = true,
    this.autofocus = false,
  });

  final double? value;
  final ValueChanged<double?> onChanged;
  final String? label;
  final String? prefix;
  final String? suffix;
  final bool decimal;
  final bool autofocus;

  @override
  State<NumInput> createState() => _NumInputState();
}

class _NumInputState extends State<NumInput> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value == null ? '' : inputNum(widget.value!),
  );

  @override
  void didUpdateWidget(NumInput old) {
    super.didUpdateWidget(old);
    final current = parseNum(_c.text);
    final v = widget.value;
    if (v != null && (current == null || (current - v).abs() > 0.005)) {
      _c.text = inputNum(v);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(widget.decimal ? r'[0-9.,]' : r'[0-9]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: widget.prefix == null ? null : '${widget.prefix} ',
        suffixText: widget.suffix,
      ),
      onChanged: (t) => widget.onChanged(parseNum(t)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: t.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: t.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: t.textTheme.bodyLarge?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String text, {
  String ok = 'Excluir',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> askText(
  BuildContext context,
  String title, {
  String label = 'Nome',
  String initial = '',
  String ok = 'Salvar',
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: Text(ok),
        ),
      ],
    ),
  );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Unidade em que a embalagem é digitada (g ou kg, ml ou L, un).
class PackUnit {
  const PackUnit(this.label, this.factor);
  final String label;
  final double factor;

  static List<PackUnit> of(UnitType u) => switch (u) {
    UnitType.weight => const [PackUnit('kg', 1000), PackUnit('g', 1)],
    UnitType.volume => const [PackUnit('L', 1000), PackUnit('ml', 1)],
    UnitType.unit => const [PackUnit('un', 1)],
  };

  /// Escolhe a unidade mais natural para mostrar uma embalagem.
  static (double, PackUnit) natural(UnitType u, double baseQty) {
    final units = of(u);
    final big = units.first;
    if (big.factor > 1 && baseQty >= big.factor) {
      return (baseQty / big.factor, big);
    }
    return (baseQty, units.last);
  }
}

/// Campos "embalagem de [1] [kg]".
class PackageInput extends StatefulWidget {
  const PackageInput({
    super.key,
    required this.unit,
    required this.baseQty,
    required this.onChanged,
  });
  final UnitType unit;
  final double? baseQty;
  final ValueChanged<double?> onChanged;

  @override
  State<PackageInput> createState() => _PackageInputState();
}

class _PackageInputState extends State<PackageInput> {
  late double? _qty;
  late PackUnit _u;

  @override
  void initState() {
    super.initState();
    final base = widget.baseQty ?? PackUnit.of(widget.unit).first.factor;
    final (q, u) = PackUnit.natural(widget.unit, base);
    _qty = q;
    _u = u;
  }

  void _emit() => widget.onChanged(_qty == null ? null : _qty! * _u.factor);

  @override
  Widget build(BuildContext context) {
    final units = PackUnit.of(widget.unit);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: NumInput(
            label: 'Embalagem de',
            value: _qty,
            onChanged: (v) {
              _qty = v;
              _emit();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<PackUnit>(
            initialValue: _u,
            items: [
              for (final u in units)
                DropdownMenuItem(value: u, child: Text(u.label)),
            ],
            onChanged: units.length == 1
                ? null
                : (u) {
                    setState(() => _u = u!);
                    _emit();
                  },
          ),
        ),
      ],
    );
  }
}

/// Texto "R$ 5,49 o kg" para um preço.
String perRef(Price p, UnitType u) =>
    '${brl(p.perBase * u.refQty)} o ${u.refLabel}';
