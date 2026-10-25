import 'package:intl/intl.dart';

import 'models.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _num = NumberFormat('#,##0.##', 'pt_BR');

String brl(double v) => _brl.format(v);
String fmtNum(double v) => _num.format(v);

/// Valor para colocar num campo de texto (sem separador de milhar).
String inputNum(double v) => v == v.roundToDouble()
    ? v.toInt().toString()
    : v.toStringAsFixed(2).replaceAll('.', ',');

/// Aceita "5,49", "5.49" e "1.234,56".
double? parseNum(String s) {
  var t = s.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

String fmtQty(double q, UnitType u) {
  if (u == UnitType.unit) return '${fmtNum(q)} un';
  if (q >= 1000) return '${fmtNum(q / 1000)} ${u.big}';
  return '${fmtNum(q)} ${u.base}';
}

String panLabel(Pan? p) {
  if (p == null) return 'Sem forma';
  final dims = p.shape == PanShape.rect
      ? '${fmtNum(p.a)}×${fmtNum(p.b)} cm'
      : '${fmtNum(p.a)} cm';
  final base = '${p.shape.label} $dims';
  return p.name.isEmpty ? base : '${p.name} ($dims)';
}

String ago(DateTime d) {
  final days = DateTime.now().difference(d).inDays;
  if (days <= 0) return 'hoje';
  if (days == 1) return 'ontem';
  return 'há $days dias';
}

bool isStale(DateTime d) => DateTime.now().difference(d).inDays > 30;

/// "Rende 2 formas Redonda 20 cm", "1 camada na Redonda 20 cm"...
String recipeYield(Recipe r, Pan? base) {
  if (r.perLayer) return '1 camada na ${panLabel(base)}';
  final n = r.yieldPans;
  return 'rende $n ${n == 1 ? 'forma' : 'formas'} ${panLabel(base)}';
}
