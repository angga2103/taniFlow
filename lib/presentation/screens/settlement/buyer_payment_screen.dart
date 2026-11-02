import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../providers/providers.dart';

class BuyerPaymentScreen extends ConsumerStatefulWidget {
  const BuyerPaymentScreen({super.key});

  @override
  ConsumerState<BuyerPaymentScreen> createState() => _BuyerPaymentScreenState();
}

class _BuyerPaymentScreenState extends ConsumerState<BuyerPaymentScreen> {
  String? _selectedBuyerId;
  BuyerReceivable? _selectedReceivable;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<BuyerReceivable> _unpaidReceivables = [];

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _onBuyerSelected(String? buyerId) async {
    setState(() {
      _selectedBuyerId = buyerId;
      _selectedReceivable = null;
      _unpaidReceivables = [];
      _amountController.clear();
    });

    if (buyerId != null) {
      final repo = ref.read(repositoryProvider);
      final list = await repo.getUnpaidBuyerReceivables(buyerId);

      if (mounted) {
        setState(() {
          _unpaidReceivables = list;
          if (list.isNotEmpty) {
            _selectedReceivable = list.first;
            _amountController.text = list.first.remainingAmount.toStringAsFixed(0);
          }
        });
      }
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedBuyerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pembeli terlebih dahulu.')),
      );
      return;
    }

    final amount = CurrencyFormatter.parse(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal uang diterima harus lebih dari 0.')),
      );
      return;
    }

    try {
      final repo = ref.read(repositoryProvider);
      final receiptNumber = await repo.receiveBuyerPayment(
        buyerId: _selectedBuyerId!,
        receivableId: _selectedReceivable?.id,
        amount: amount,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      ref.invalidate(cashTransactionsProvider);
      ref.invalidate(currentCashBalanceProvider);
      ref.invalidate(receivablesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Penerimaan piutang $receiptNumber berhasil dicatat sebagai Kas Masuk!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan penerimaan kas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final buyersAsync = ref.watch(activeBuyersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penerimaan Piutang Pembeli'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Pilih Pembeli yang Membayar Tagihan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            buyersAsync.when(
              data: (buyers) {
                return DropdownButtonFormField<String>(
                  value: _selectedBuyerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Pembeli / Pelanggan',
                    prefixIcon: Icon(Icons.storefront),
                  ),
                  items: buyers.map((b) {
                    return DropdownMenuItem<String>(
                      value: b.id,
                      child: Text(
                        '${b.name}${b.address != null ? " (${b.address})" : ""}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: _onBuyerSelected,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Gagal: $err'),
            ),
            const SizedBox(height: 16),

            if (_selectedBuyerId != null) ...[
              if (_unpaidReceivables.isEmpty)
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
                          'Pembeli ini tidak memiliki sisa piutang / tagihan yang belum lunas.',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.success),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                DropdownButtonFormField<BuyerReceivable>(
                  value: _selectedReceivable,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Tagihan Piutang',
                    prefixIcon: Icon(Icons.receipt),
                  ),
                  items: _unpaidReceivables.map((r) {
                    return DropdownMenuItem<BuyerReceivable>(
                      value: r,
                      child: Text(
                        'Piutang Sisa: ${CurrencyFormatter.format(r.remainingAmount)}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedReceivable = val;
                      if (val != null) {
                        _amountController.text = val.remainingAmount.toStringAsFixed(0);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
            ],

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
                  const Text('2. Uang Diterima (Kas Masuk)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal Uang Diterima (Rp)',
                      prefixIcon: Icon(Icons.payments),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_selectedReceivable != null)
                    ActionChip(
                      label: const Text('Pelunasan Penuh'),
                      backgroundColor: AppColors.primaryLighter,
                      onPressed: () {
                        setState(() {
                          _amountController.text = _selectedReceivable!.remainingAmount.toStringAsFixed(0);
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Keterangan Penerimaan (Opsional)',
                hintText: 'Cicilan 1, transfer bank, tunai di kios, dll.',
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _submitPayment,
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Simpan Uang Masuk ke Buku Kas'),
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
