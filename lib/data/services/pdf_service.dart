import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/weight_formatter.dart';

class PdfService {
  PdfService._();

  static pw.Widget _buildHeader({
    required String businessName,
    String? address,
    String? phone,
    required String documentTitle,
    required String transactionNumber,
    required DateTime date,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  businessName,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                ),
                if (address != null && address.isNotEmpty)
                  pw.Text(address, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                if (phone != null && phone.isNotEmpty)
                  pw.Text('Telp: $phone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  documentTitle,
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                ),
                pw.Text('No: $transactionNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('Tanggal: ${DateFormatter.formatDateTime(date)}', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 1, color: PdfColors.grey400),
        pw.SizedBox(height: 8),
      ],
    );
  }

  /// 1. BUKTI SETORAN PETANI
  static Future<File> generateSubmissionReceipt({
    required String businessName,
    String? businessAddress,
    String? businessPhone,
    required String transactionNumber,
    required DateTime date,
    required String farmerName,
    String? farmerAddress,
    required List<Map<String, dynamic>> items, // commodity, gross, tare, net
    required double totalGross,
    required double totalTare,
    required double totalNet,
    String? notes,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  businessName: businessName,
                  address: businessAddress,
                  phone: businessPhone,
                  documentTitle: 'BUKTI SETORAN HASIL PANEN',
                  transactionNumber: transactionNumber,
                  date: date,
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text('Petani: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(farmerName, style: const pw.TextStyle(fontSize: 10)),
                      if (farmerAddress != null) ...[
                        pw.Text('  |  Alamat: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(farmerAddress, style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellAlignment: pw.Alignment.centerLeft,
                  headers: ['No', 'Komoditas', 'Kotor (kg)', 'Tara (kg)', 'Bersih (kg)'],
                  data: List.generate(items.length, (i) {
                    final item = items[i];
                    return [
                      '${i + 1}',
                      item['commodity'].toString(),
                      WeightFormatter.format(item['gross'] as double, hideZeroDecimals: true),
                      WeightFormatter.format(item['tare'] as double, hideZeroDecimals: true),
                      WeightFormatter.format(item['net'] as double),
                    ];
                  }),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Total Berat Bersih: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text(WeightFormatter.format(totalNet),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.green900)),
                  ],
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text('Catatan: $notes', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
                pw.Spacer(),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.amber800),
                    color: PdfColors.amber50,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'PENTING: Harga dan pembayaran ditentukan setelah hasil panen terjual di pasar.',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('Petani Penyetor', style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 35),
                        pw.Text('($farmerName)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Penerima / Timbangan', style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 35),
                        pw.Text('($businessName)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Bukti_Setoran_$transactionNumber.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// 2. NOTA PENJUALAN PEMBELI
  static Future<File> generateSalesInvoice({
    required String businessName,
    String? businessAddress,
    String? businessPhone,
    required String invoiceNumber,
    required DateTime date,
    required String buyerName,
    String? buyerPhone,
    required List<Map<String, dynamic>> items, // commodity, grade, weight, price, subtotal
    required double totalAmount,
    required double paidAmount,
    required double remainingAmount,
    String? notes,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  businessName: businessName,
                  address: businessAddress,
                  phone: businessPhone,
                  documentTitle: 'NOTA PENJUALAN KOMODITAS',
                  transactionNumber: invoiceNumber,
                  date: date,
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text('Pembeli: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(buyerName, style: const pw.TextStyle(fontSize: 10)),
                      if (buyerPhone != null) ...[
                        pw.Text('  |  Telp: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(buyerPhone, style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  headers: ['No', 'Komoditas', 'Grade', 'Berat', 'Harga/kg', 'Total'],
                  data: List.generate(items.length, (i) {
                    final it = items[i];
                    return [
                      '${i + 1}',
                      it['commodity'].toString(),
                      it['grade'].toString(),
                      WeightFormatter.format(it['weight'] as double),
                      CurrencyFormatter.format(it['price'] as double),
                      CurrencyFormatter.format(it['subtotal'] as double),
                    ];
                  }),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Total Tagihan: ${CurrencyFormatter.format(totalAmount)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('Dibayar Tunai: ${CurrencyFormatter.format(paidAmount)}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.green900)),
                        pw.Text('Sisa Piutang: ${CurrencyFormatter.format(remainingAmount)}',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                                color: remainingAmount > 0 ? PdfColors.red900 : PdfColors.green900)),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('Tanda Terima Pembeli', style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 35),
                        pw.Text('($buyerName)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Hormat Kami', style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 35),
                        pw.Text('($businessName)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Nota_Penjualan_$invoiceNumber.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// 3. BUKTI PEMBAYARAN PETANI
  static Future<File> generateFarmerPaymentReceipt({
    required String businessName,
    String? businessAddress,
    String? businessPhone,
    required String paymentNumber,
    required DateTime date,
    required String farmerName,
    required double paymentAmount,
    required double totalPayable,
    required double remainingPayable,
    String? notes,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  businessName: businessName,
                  address: businessAddress,
                  phone: businessPhone,
                  documentTitle: 'KUITANSI PEMBAYARAN PETANI',
                  transactionNumber: paymentNumber,
                  date: date,
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.green700),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Telah dibayarkan kepada: $farmerName',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text('Nominal Pembayaran: ${CurrencyFormatter.format(paymentAmount)}',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      pw.SizedBox(height: 6),
                      pw.Text('Total Hak Pembayaran: ${CurrencyFormatter.format(totalPayable)}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Sisa Kewajiban: ${CurrencyFormatter.format(remainingPayable)}',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Text('Keterangan: $notes', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                ],
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('Penerima (Petani)', style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 35),
                        pw.Text('($farmerName)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Yang Membayar', style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 35),
                        pw.Text('($businessName)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Kuitansi_Petani_$paymentNumber.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
