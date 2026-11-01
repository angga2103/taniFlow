import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../providers/providers.dart';

class FarmerPaymentScreen extends ConsumerStatefulWidget {
  const FarmerPaymentScreen({super.key});

  @override
  ConsumerState<FarmerPaymentScreen> createState() => _FarmerPaymentScreenState();
}

class _FarmerPaymentScreenState extends ConsumerState<FarmerPaymentScreen> {
  String? _selectedFarmerId;
  FarmerPayable? _selectedPayable;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<FarmerPayable> _unpaidPayables = [];

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _onFarmerSelected(String? farmerId) async {
    setState(() {
      _selectedFarmerId = farmerId;
      _selectedPayable = null;
      _unpaidPayables = [];
      _amountController.clear();
    });

    if (farmerId != null) {
      final repo = ref.read(repositoryProvider);
      final list = await repo.getUnpaidFarmerPayables(farmerId);

      if (mounted) {
        setState(() {
          _unpaidPayables = list;
          if (list.isNotEmpty) {
            _selectedPayable = list.first;
            _amountController.text = list.first.remainingAmount.toStringAsFixed(0);
          }
        });
      }
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedFarmerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih petani penerima terlebih dahulu.')),
      );
      return;
    }

    final amount = CurrencyFormatter.parse(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pembayaran tunai harus lebih dari 0.')),
      );
      return;
    }

    try {
      final repo = ref.read(repositoryProvider);
      final paymentNumber = await repo.payFarmer(
        farmerId: _selectedFarmerId!,
        payableId: _selectedPayable?.id,
        amount: amount,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Refresh streams
      ref.invalidate(cashTransactionsProvider);
      ref.invalidate(currentCashBalanceProvider);

      final farmers = await repo.getActiveFarmers();
      final farmerName = farmers.where((f) => f.id == _selectedFarmerId).firstOrNull?.name ?? 'Petani';

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Pembayaran Berhasil!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nomor Bukti: $paymentNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Petani: $farmerName'),
                  Text('Nominal: ${CurrencyFormatter.format(amount)}'),
                  const SizedBox(height: 12),
                  const Text('Uang tunai telah dicatat sebagai Kas Keluar di Buku Kas.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final printer = ref.read(printerServiceProvider);
                    final profile = await ref.read(businessProfileProvider.future);
                    await printer.printFarmerPaymentReceipt(
                      businessName: profile?.businessName ?? AppStrings.appName,
                      paymentNumber: paymentNumber,
                      date: DateTime.now(),
                      farmerName: farmerName,
                      amount: amount,
                      remainingPayable: (_selectedPayable?.remainingAmount ?? amount) - amount,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak Kuitansi'),
                ),
              ],
            );
          },
        ).then((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses pembayaran: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmersAsync = ref.watch(activeFarmersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran Tunai Petani'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Pilih Petani Penerima Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            farmersAsync.when(
              data: (farmers) {
                return DropdownButtonFormField<String>(
                  value: _selectedFarmerId,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Petani',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: farmers.map((f) {
                    return DropdownMenuItem<String>(
                      value: f.id,
                      child: Text(f.name),
                    );
                  }).toList(),
                  onChanged: _onFarmerSelected,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Gagal: $err'),
            ),
            const SizedBox(height: 16),

            if (_selectedFarmerId != null) ...[
              if (_unpaidPayables.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Petani ini tidak memiliki sisa kewajiban pembayaran yang tertunda.',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.success),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                DropdownButtonFormField<FarmerPayable>(
                  value: _selectedPayable,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Tagihan Setoran yang Dibayar',
                    prefixIcon: Icon(Icons.receipt_long),
                  ),
                  items: _unpaidPayables.map((p) {
                    return DropdownMenuItem<FarmerPayable>(
                      value: p,
                      child: Text('Kewajiban Sisa: ${CurrencyFormatter.format(p.remainingAmount)}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedPayable = val;
                      if (val != null) {
                        _amountController.text = val.remainingAmount.toStringAsFixed(0);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Input Nominal
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
                  const Text('2. Nominal Uang Kas Keluar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Uang Dibayarkan (Rp)',
                      prefixIcon: Icon(Icons.payments),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (_selectedPayable != null)
                        ActionChip(
                          label: const Text('Bayar Lunas Penuh'),
                          backgroundColor: AppColors.primaryLighter,
                          onPressed: () {
                            setState(() {
                              _amountController.text = _selectedPayable!.remainingAmount.toStringAsFixed(0);
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Keterangan Pembayaran (Opsional)',
                hintText: 'Titipan panen, transfer/tunai langsung, dll.',
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _submitPayment,
              icon: const Icon(Icons.payments),
              label: const Text('Bayarkan Uang Tunai ke Petani'),
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
