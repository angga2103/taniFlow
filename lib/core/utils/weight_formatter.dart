import 'package:intl/intl.dart';

class WeightFormatter {
  WeightFormatter._();

  static final NumberFormat _formatter = NumberFormat('#,##0.00', 'id_ID');
  static final NumberFormat _integerFormatter = NumberFormat('#,##0', 'id_ID');

  static String format(double? weight, {String unit = 'kg', bool hideZeroDecimals = false}) {
    if (weight == null) return '0,00 $unit';
    if (hideZeroDecimals && (weight % 1 == 0)) {
      return '${_integerFormatter.format(weight)} $unit';
    }
    return '${_formatter.format(weight)} $unit';
  }

  static double parse(String text) {
    final normalized = text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }
}
