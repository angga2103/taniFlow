import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/printer_service.dart';
import '../../providers/providers.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  bool _isBluetoothEnabled = false;
  bool _isConnected = false;
  String? _savedMac;
  PaperSizeWidth _paperSize = PaperSizeWidth.mm58;

  List<BluetoothInfo> _devices = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPrinterStatus();
  }

  Future<void> _checkPrinterStatus() async {
    setState(() => _isLoading = true);
    final printer = ref.read(printerServiceProvider);

    final isBt = await printer.isBluetoothEnabled();
    final isConn = await printer.isConnected();
    final saved = await printer.getSavedPrinterMac();
    final size = await printer.getSavedPaperSize();
    final devices = await printer.getDevices();

    if (mounted) {
      setState(() {
        _isBluetoothEnabled = isBt;
        _isConnected = isConn;
        _savedMac = saved;
        _paperSize = size;
        _devices = devices;
        _isLoading = false;
      });
    }
  }

  Future<void> _connectDevice(String mac) async {
    setState(() => _isLoading = true);
    final printer = ref.read(printerServiceProvider);
    final ok = await printer.connect(mac);

    if (mounted) {
      setState(() {
        _isConnected = ok;
        _savedMac = mac;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Berhasil terhubung ke printer!' : 'Gagal menghubungkan printer. Periksa daya printer.'),
          backgroundColor: ok ? AppColors.primary : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _testPrint() async {
    final printer = ref.read(printerServiceProvider);
    final ok = await printer.printTest();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Test print berhasil dikirim ke printer!' : 'Gagal mengirim test print.'),
          backgroundColor: ok ? AppColors.primary : AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Printer Thermal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Pindai Ulang',
            onPressed: _checkPrinterStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Bluetooth & Printer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status Bluetooth:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Icon(
                            _isBluetoothEnabled ? Icons.bluetooth : Icons.bluetooth_disabled,
                            color: _isBluetoothEnabled ? AppColors.primary : AppColors.danger,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isBluetoothEnabled ? 'Aktif' : 'Nonaktif',
                            style: TextStyle(
                              color: _isBluetoothEnabled ? AppColors.primary : AppColors.danger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Koneksi Printer:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        _isConnected ? 'Terhubung' : 'Terputus',
                        style: TextStyle(
                          color: _isConnected ? AppColors.success : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pilihan Ukuran Kertas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ukuran Lebar Kertas Struk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Thermal 58 mm (Standar Mini)')),
                          selected: _paperSize == PaperSizeWidth.mm58,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _paperSize == PaperSizeWidth.mm58 ? Colors.white : AppColors.textPrimary,
                          ),
                          onSelected: (val) async {
                            if (val) {
                              setState(() => _paperSize = PaperSizeWidth.mm58);
                              await ref.read(printerServiceProvider).savePaperSize(PaperSizeWidth.mm58);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Thermal 80 mm (Lebar)')),
                          selected: _paperSize == PaperSizeWidth.mm80,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _paperSize == PaperSizeWidth.mm80 ? Colors.white : AppColors.textPrimary,
                          ),
                          onSelected: (val) async {
                            if (val) {
                              setState(() => _paperSize = PaperSizeWidth.mm80);
                              await ref.read(printerServiceProvider).savePaperSize(PaperSizeWidth.mm80);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Daftar Perangkat Printer Bluetooth
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Perangkat Bluetooth Terpasang (Paired)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (_devices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Tidak ada perangkat printer bluetooth ditemukan.\nPastikan printer dinyalakan dan sudah dipasangkan (paired) melalui pengaturan Bluetooth HP Android Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final dev = _devices[index];
                  final isCurrent = dev.macAdress == _savedMac;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.print, color: AppColors.primary),
                      title: Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(dev.macAdress, style: const TextStyle(fontSize: 12)),
                      trailing: ElevatedButton(
                        onPressed: () => _connectDevice(dev.macAdress),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCurrent ? AppColors.success : AppColors.primary,
                          minimumSize: const Size(90, 36),
                        ),
                        child: Text(isCurrent ? 'Tersimpan' : 'Pilih'),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Tombol Test Print
            ElevatedButton.icon(
              onPressed: _testPrint,
              icon: const Icon(Icons.receipt),
              label: const Text('Cetak Halaman Uji Coba (Test Print)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
