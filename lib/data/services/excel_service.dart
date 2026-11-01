import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';

class ExcelService {
  ExcelService._();

  static Future<File> exportFinancialReport({
    required String businessName,
    required DateTime startDate,
    required DateTime endDate,
    required double totalOmzet,
    required double totalHakPetani,
    required double marginKotor,
    required double totalPengeluaran,
    required double labaBersih,
    required List<Map<String, dynamic>> salesRows,
    required List<Map<String, dynamic>> expenseRows,
  }) async {
    final excel = Excel.createExcel();
    final Sheet sheetSummary = excel['Ringkasan Keuangan'];
    excel.delete('Sheet1'); // Remove default sheet

    // Header Styles
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString('#1B5E20'),
    );
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#2E7D32'),
      fontColorHex: ExcelColor.white,
    );
    final boldStyle = CellStyle(bold: true);

    // 1. Sheet Ringkasan
    sheetSummary.cell(CellIndex.indexByString('A1')).value = TextCellValue(businessName);
    sheetSummary.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;

    sheetSummary.cell(CellIndex.indexByString('A2')).value =
        TextCellValue('Laporan Keuangan: ${DateFormatter.formatDate(startDate)} s/d ${DateFormatter.formatDate(endDate)}');
    sheetSummary.cell(CellIndex.indexByString('A2')).cellStyle = boldStyle;

    sheetSummary.appendRow([TextCellValue('')]);
    sheetSummary.appendRow([TextCellValue('Indikator Keuangan'), TextCellValue('Nilai (Rp)')]);
    sheetSummary.cell(CellIndex.indexByString('A4')).cellStyle = headerStyle;
    sheetSummary.cell(CellIndex.indexByString('B4')).cellStyle = headerStyle;

    sheetSummary.appendRow([TextCellValue('Total Omzet Penjualan'), TextCellValue(CurrencyFormatter.format(totalOmzet))]);
    sheetSummary.appendRow([TextCellValue('Total Hak Petani'), TextCellValue(CurrencyFormatter.format(totalHakPetani))]);
    sheetSummary.appendRow([TextCellValue('Margin Kotor Usaha'), TextCellValue(CurrencyFormatter.format(marginKotor))]);
    sheetSummary.appendRow([TextCellValue('Total Pengeluaran Operasional'), TextCellValue(CurrencyFormatter.format(totalPengeluaran))]);
    sheetSummary.appendRow([TextCellValue('Laba Bersih Usaha'), TextCellValue(CurrencyFormatter.format(labaBersih))]);

    // 2. Sheet Penjualan
    final Sheet sheetSales = excel['Detail Penjualan'];
    sheetSales.appendRow([
      TextCellValue('No'),
      TextCellValue('Tanggal'),
      TextCellValue('No Faktur'),
      TextCellValue('Pembeli'),
      TextCellValue('Total Nilai'),
      TextCellValue('Dibayar'),
      TextCellValue('Piutang'),
    ]);
    for (int col = 0; col < 7; col++) {
      sheetSales.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (int i = 0; i < salesRows.length; i++) {
      final s = salesRows[i];
      sheetSales.appendRow([
        IntCellValue(i + 1),
        TextCellValue(DateFormatter.formatDate(s['date'] as DateTime?)),
        TextCellValue(s['invoice'].toString()),
        TextCellValue(s['buyer'].toString()),
        TextCellValue(CurrencyFormatter.format(s['total'] as double?)),
        TextCellValue(CurrencyFormatter.format(s['paid'] as double?)),
        TextCellValue(CurrencyFormatter.format(s['remaining'] as double?)),
      ]);
    }

    // 3. Sheet Pengeluaran
    final Sheet sheetExpenses = excel['Detail Pengeluaran'];
    sheetExpenses.appendRow([
      TextCellValue('No'),
      TextCellValue('Tanggal'),
      TextCellValue('No Bukti'),
      TextCellValue('Kategori'),
      TextCellValue('Keterangan'),
      TextCellValue('Nominal'),
    ]);
    for (int col = 0; col < 6; col++) {
      sheetExpenses.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (int i = 0; i < expenseRows.length; i++) {
      final e = expenseRows[i];
      sheetExpenses.appendRow([
        IntCellValue(i + 1),
        TextCellValue(DateFormatter.formatDate(e['date'] as DateTime?)),
        TextCellValue(e['number'].toString()),
        TextCellValue(e['category']?.toString() ?? '-'),
        TextCellValue(e['notes']?.toString() ?? '-'),
        TextCellValue(CurrencyFormatter.format(e['amount'] as double?)),
      ]);
    }

    final fileBytes = excel.save();
    final tempDir = await getTemporaryDirectory();
    final fileName = 'Laporan_Keuangan_${DateFormatter.toIsoDateOnly(startDate)}_${DateFormatter.toIsoDateOnly(endDate)}.xlsx';
    final file = File('${tempDir.path}/$fileName');
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);
    }
    return file;
  }
}
