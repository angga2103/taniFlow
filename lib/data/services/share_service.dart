import 'dart:io';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/weight_formatter.dart';

class ShareService {
  ShareService._();

  /// Share file via Android Native Share Sheet
  static Future<void> shareFile({
    required File file,
    required String text,
    String? subject,
  }) async {
    final xFile = XFile(file.path);
    await Share.shareXFiles(
      [xFile],
      text: text,
      subject: subject,
    );
  }

  /// Format & Share Bukti Setoran ke WhatsApp / Media Sosial
  static Future<void> shareSubmissionText({
    required String businessName,
    required String transactionNumber,
    required DateTime date,
    required String farmerName,
    required List<Map<String, dynamic>> items,
    required double totalNet,
  }) async {
    final sb = StringBuffer();
    sb.writeln('*$businessName*');
    sb.writeln('📋 *BUKTI SETORAN HASIL PANEN*');
    sb.writeln('--------------------------------');
    sb.writeln('No Transaksi : $transactionNumber');
    sb.writeln('Tanggal      : ${DateFormatter.formatDateTime(date)}');
    sb.writeln('Petani       : $farmerName');
    sb.writeln('--------------------------------');
    sb.writeln('Rincian Timbangan:');

    for (final item in items) {
      final name = item['commodity'].toString();
      final gross = WeightFormatter.format(item['gross'] as double, hideZeroDecimals: true);
      final tare = WeightFormatter.format(item['tare'] as double, hideZeroDecimals: true);
      final net = WeightFormatter.format(item['net'] as double);
      sb.writeln('• $name');
      sb.writeln('  Kotor: $gross | Tara: $tare | *Bersih: $net*');
    }

    sb.writeln('--------------------------------');
    sb.writeln('*TOTAL BERSIH : ${WeightFormatter.format(totalNet)}*');
    sb.writeln('--------------------------------');
    sb.writeln('📌 _Catatan: Harga dan pembayaran ditentukan setelah hasil panen terjual._');
    sb.writeln('');
    sb.writeln('Terima kasih atas setoran panen Anda.');

    await Share.share(sb.toString(), subject: 'Bukti Setoran $transactionNumber');
  }

  /// Format & Share Nota Penjualan ke WhatsApp
  static Future<void> shareSalesInvoiceText({
    required String businessName,
    required String invoiceNumber,
    required DateTime date,
    required String buyerName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double paidAmount,
    required double remainingAmount,
  }) async {
    final sb = StringBuffer();
    sb.writeln('*$businessName*');
    sb.writeln('🛒 *NOTA PENJUALAN KOMODITAS*');
    sb.writeln('--------------------------------');
    sb.writeln('No Faktur : $invoiceNumber');
    sb.writeln('Tanggal   : ${DateFormatter.formatDateTime(date)}');
    sb.writeln('Pembeli   : $buyerName');
    sb.writeln('--------------------------------');

    for (final it in items) {
      final name = '${it['commodity']} (${it['grade']})';
      final weight = WeightFormatter.format(it['weight'] as double);
      final price = CurrencyFormatter.format(it['price'] as double);
      final subtotal = CurrencyFormatter.format(it['subtotal'] as double);
      sb.writeln('• $name');
      sb.writeln('  $weight × $price = $subtotal');
    }

    sb.writeln('--------------------------------');
    sb.writeln('*Total Tagihan : ${CurrencyFormatter.format(totalAmount)}*');
    sb.writeln('Dibayar Tunai  : ${CurrencyFormatter.format(paidAmount)}');
    sb.writeln('*Sisa Piutang  : ${CurrencyFormatter.format(remainingAmount)}*');
    sb.writeln('--------------------------------');
    sb.writeln('Terima kasih atas transaksi Anda.');

    await Share.share(sb.toString(), subject: 'Nota Penjualan $invoiceNumber');
  }
}
