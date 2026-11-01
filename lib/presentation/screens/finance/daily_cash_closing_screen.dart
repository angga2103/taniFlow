import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../providers/providers.dart';

class DailyCashClosingScreen extends ConsumerStatefulWidget {
  const DailyCashClosingScreen({super.key});

  @override
  ConsumerState<DailyCashClosingScreen> createState() => _DailyCashClosingScreenState();
}

class _DailyCashClosingScreenState extends ConsumerState<DailyCashClosingScreen> {
  final TextEditingController _physicalCashController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  double _systemBalance = 0.0;
  double _difference = 0.0;
  bool _isCalculated = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _physicalCashController.addListener(_calculateDiff);
  }

  @override
  void dispose() {
    _physicalCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final repo = ref.read(repositoryProvider);
    final bal = await repo.getCurrentCashBalance();
    if (mounted) {
      setState(() {
        _systemBalance = bal;
      });
    }
  }

  void _calculateDiff() {
    final physical = CurrencyFormatter.parse(_physicalCashController.text);
    setState(() {
      _difference = physical - _systemBalance;
      _isCalculated = true;
    });
  }

  Future<void> _saveClosing() async {
    final physical = CurrencyFormatter.parse(_physicalCashController.text);

    try {
      final repo = ref.read(repositoryProvider);
      final closingNum = await repo.recordDailyCashClosing(
        physicalCash: physical,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tutup kas $closingNum berhasil disimpan!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan tutup kas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final physical = CurrencyFormatter.parse(_physicalCashController.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutup Kas Harian'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saldo Sistem
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo Kas Menurut Aplikasi', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(_systemBalance),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.primary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Perhitungan transaksi kas masuk dan keluar hari ini (${DateFormatter.formatDate(DateTime.now())}).',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Input Kas Fisik
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryLight, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hitung Uang Tunai Fisik di Brankas / Laci',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _physicalCashController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'Total Uang Fisik Aktual (Rp)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Hasil Rekonsiliasi Kas Fisik vs Sistem
            if (_isCalculated) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _difference == 0
                      ? AppColors.successLight
                      : (_difference > 0 ? AppColors.infoLight : AppColors.dangerLight),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _difference == 0
                        ? AppColors.success
                        : (_difference > 0 ? AppColors.info : AppColors.danger),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo Menurut Sistem:', style: TextStyle(fontSize: 13)),
                        Text(CurrencyFormatter.format(_systemBalance), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kas Fisik Nyata:', style: TextStyle(fontSize: 13)),
                        Text(CurrencyFormatter.format(physical), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _difference == 0
                              ? 'Status: KAS COCOK / TEPAT'
                              : (_difference > 0 ? 'Selisih LEBIH (Surplus):' : 'Selisih KURANG (Defisit):'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _difference == 0
                                ? AppColors.success
                                : (_difference > 0 ? AppColors.info : AppColors.danger),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(_difference.abs()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _difference == 0
                                ? AppColors.success
                                : (_difference > 0 ? AppColors.info : AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Tutup Kas (Opsional)',
                hintText: 'Alasan jika ada selisih uang, catatan shift, dll.',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Penjelasan Finansial Penting
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '📌 Catatan Akuntansi: Laporan Arus Kas berbeda dari Laporan Laba Bersih. Pembayaran kewajiban petani dicatat sebagai Kas Keluar, bukan biaya ganda pengurang laba.',
                style: TextStyle(fontSize: 11, color: AppColors.warning),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _saveClosing,
              icon: const Icon(Icons.lock_clock),
              label: const Text('Simpan Rekonsiliasi Tutup Kas'),
              style: ElevatedButton.styleFrom(
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
