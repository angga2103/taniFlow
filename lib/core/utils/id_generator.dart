import 'dart:math';
import 'package:intl/intl.dart';

class IdGenerator {
  IdGenerator._();

  static final Random _random = Random();

  static String generate(String prefix) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final randomSuffix = _random.nextInt(9000) + 1000; // 4-digit random number
    return '$prefix-$dateStr-$randomSuffix';
  }

  static String submissionId() => generate('STR');
  static String gradingId() => generate('SRT');
  static String shipmentId() => generate('KRM');
  static String saleId() => generate('PJL');
  static String farmerPaymentId() => generate('BYR');
  static String buyerPaymentId() => generate('KWT');
  static String expenseId() => generate('BIA');
  static String damageId() => generate('RSK');
  static String closingId() => generate('CLS');
  static String uuid() => DateTime.now().microsecondsSinceEpoch.toString();
}
