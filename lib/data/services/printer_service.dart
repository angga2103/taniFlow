import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/weight_formatter.dart';

enum PaperSizeWidth { mm58, mm80 }

class ThermalPrinterService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _savedPrinterMacKey = 'saved_printer_mac';
  static const String _paperSizeKey = 'saved_paper_size';

  // Check if bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  // Check bluetooth permission
  Future<bool> checkPermission() async {
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  // Scan paired/available bluetooth devices
  Future<List<BluetoothInfo>> getDevices() async {
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {
      return [];
    }
  }

  // Connect to printer by MAC address
  Future<bool> connect(String macAddress) async {
    try {
      final isConnected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      if (isConnected) {
        await _storage.write(key: _savedPrinterMacKey, value: macAddress);
      }
      return isConnected;
    } catch (_) {
      return false;
    }
  }

  // Disconnect printer
  Future<bool> disconnect() async {
    try {
      return await PrintBluetoothThermal.disconnect;
    } catch (_) {
      return false;
    }
  }

  // Check connection status
  Future<bool> isConnected() async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  // Get saved printer MAC
  Future<String?> getSavedPrinterMac() async {
    return await _storage.read(key: _savedPrinterMacKey);
  }

  // Get paper size setting
  Future<PaperSizeWidth> getSavedPaperSize() async {
    final size = await _storage.read(key: _paperSizeKey);
    return size == '80' ? PaperSizeWidth.mm80 : PaperSizeWidth.mm58;
  }

  Future<void> savePaperSize(PaperSizeWidth size) async {
    await _storage.write(
      key: _paperSizeKey,
      value: size == PaperSizeWidth.mm80 ? '80' : '58',
    );
  }

  // Helper to send raw bytes to connected printer
  Future<bool> _sendBytes(List<int> bytes) async {
    try {
      final connected = await isConnected();
      if (!connected) {
        final savedMac = await getSavedPrinterMac();
        if (savedMac != null) {
          final reconnected = await connect(savedMac);
          if (!reconnected) return false;
        } else {
          return false;
        }
      }
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  // Generate Profile
  Future<Generator> _getGenerator() async {
    final paperSize = await getSavedPaperSize();
    final profile = await CapabilityProfile.load();
    return Generator(
      paperSize == PaperSizeWidth.mm80 ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );
  }

  /// 1. Test Print
  Future<bool> printTest() async {
    final bytes = <int>[];
    final generator = await _getGenerator();

    bytes.addAll(generator.text(
      'TANIFLOW PRINTER TEST',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    ));
    bytes.addAll(generator.text(
      'Koneksi Bluetooth ESC/POS Berhasil',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      DateFormatter.formatDateTime(DateTime.now()),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('Thermal Printer Siap Digunakan!'));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return await _sendBytes(bytes);
  }

  /// 2. Cetak Bukti Setoran Petani
  Future<bool> printSubmissionReceipt({
    required String businessName,
    String? businessPhone,
    required String transactionNumber,
    required DateTime date,
    required String farmerName,
    required List<Map<String, dynamic>> items,
    required double totalGross,
    required double totalTare,
    required double totalNet,
    String? notes,
  }) async {
    final bytes = <int>[];
    final generator = await _getGenerator();

    bytes.addAll(generator.text(
      businessName,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1),
    ));
    if (businessPhone != null) {
      bytes.addAll(generator.text('Telp: $businessPhone', styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(
      'BUKTI SETORAN HASIL PANEN',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text('No: $transactionNumber'));
    bytes.addAll(generator.text('Tgl: ${DateFormatter.formatDateTime(date)}'));
    bytes.addAll(generator.text('Petani: $farmerName', styles: const PosStyles(bold: true)));
    bytes.addAll(generator.hr());

    for (final item in items) {
      bytes.addAll(generator.text(
        item['commodity'].toString(),
        styles: const PosStyles(bold: true),
      ));
      final gross = WeightFormatter.format(item['gross'] as double, hideZeroDecimals: true);
      final tare = WeightFormatter.format(item['tare'] as double, hideZeroDecimals: true);
      final net = WeightFormatter.format(item['net'] as double);

      bytes.addAll(generator.row([
        PosColumn(text: 'Ktr: $gross', width: 4),
        PosColumn(text: 'Tr: $tare', width: 4),
        PosColumn(text: 'Brs: $net', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(text: 'TOTAL BERSIH:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: WeightFormatter.format(totalNet),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size1),
      ),
    ]));

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'Catatan Penting:',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text(
      'Harga dan pembayaran ditentukan setelah hasil panen terjual.',
    ));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return await _sendBytes(bytes);
  }

  /// 3. Cetak Nota Penjualan Pembeli
  Future<bool> printSalesInvoice({
    required String businessName,
    required String invoiceNumber,
    required DateTime date,
    required String buyerName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double paidAmount,
    required double remainingAmount,
  }) async {
    final bytes = <int>[];
    final generator = await _getGenerator();

    bytes.addAll(generator.text(
      businessName,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text('NOTA PENJUALAN', styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.text('No: $invoiceNumber'));
    bytes.addAll(generator.text('Tgl: ${DateFormatter.formatDateTime(date)}'));
    bytes.addAll(generator.text('Pembeli: $buyerName', styles: const PosStyles(bold: true)));
    bytes.addAll(generator.hr());

    for (final it in items) {
      final name = '${it['commodity']} (${it['grade']})';
      final weight = WeightFormatter.format(it['weight'] as double);
      final price = CurrencyFormatter.format(it['price'] as double);
      final subtotal = CurrencyFormatter.format(it['subtotal'] as double);

      bytes.addAll(generator.text(name, styles: const PosStyles(bold: true)));
      bytes.addAll(generator.row([
        PosColumn(text: '$weight @ $price', width: 7),
        PosColumn(text: subtotal, width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(text: 'Total Tagihan:', width: 6),
      PosColumn(text: CurrencyFormatter.format(totalAmount), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Dibayar Tunai:', width: 6),
      PosColumn(text: CurrencyFormatter.format(paidAmount), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Sisa Piutang:', width: 6),
      PosColumn(text: CurrencyFormatter.format(remainingAmount), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]));

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text('Terima Kasih Atas Kerjasamanya', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return await _sendBytes(bytes);
  }

  /// 4. Cetak Bukti Pembayaran Petani
  Future<bool> printFarmerPaymentReceipt({
    required String businessName,
    required String paymentNumber,
    required DateTime date,
    required String farmerName,
    required double amount,
    required double remainingPayable,
  }) async {
    final bytes = <int>[];
    final generator = await _getGenerator();

    bytes.addAll(generator.text(
      businessName,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text('KUITANSI PEMBAYARAN PETANI', styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.text('No: $paymentNumber'));
    bytes.addAll(generator.text('Tgl: ${DateFormatter.formatDateTime(date)}'));
    bytes.addAll(generator.text('Petani: $farmerName', styles: const PosStyles(bold: true)));
    bytes.addAll(generator.hr());

    bytes.addAll(generator.row([
      PosColumn(text: 'DIBAYARKAN:', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(
        text: CurrencyFormatter.format(amount),
        width: 7,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size1),
      ),
    ]));

    bytes.addAll(generator.row([
      PosColumn(text: 'Sisa Kewajiban:', width: 6),
      PosColumn(
        text: CurrencyFormatter.format(remainingPayable),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return await _sendBytes(bytes);
  }
}
