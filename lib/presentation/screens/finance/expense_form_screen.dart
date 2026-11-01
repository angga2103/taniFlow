import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../providers/providers.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _category = 'Operasional';
  bool _isPackaging = false;

  final List<String> _categories = [
    'Operasional',
    'Kemasan (Karung/Keranjang/Peti)',
    'Transportasi & BBM',
    'Tenaga Kerja / Kuli Bongkar',
    'Makan / Konsumsi',
    'Retribusi & Kebersihan Pasar',
    'Lainnya',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    final amount = CurrencyFormatter.parse(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pengeluaran harus lebih dari 0.')),
      );
      return;
    }

    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keterangan pengeluaran wajib diisi.')),
      );
      return;
    }

    try {
      final repo = ref.read(repositoryProvider);
      final expenseNum = await repo.recordExpense(
        amount: amount,
        category: _category,
        notes: _notesController.text.trim(),
        isPackaging: _isPackaging || _category.contains('Kemasan'),
      );

      ref.invalidate(cashTransactionsProvider);
      ref.invalidate(currentCashBalanceProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pengeluaran $expenseNum berhasil dicatat ke Kas Keluar!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan pengeluaran: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catat Pengeluaran Kas'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Input Pengeluaran Cepat (Kas Keluar)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Nominal Biaya (Rp)',
                prefixIcon: Icon(Icons.money_off, color: AppColors.danger),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Kategori Pengeluaran',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _categories.map((c) {
                return DropdownMenuItem<String>(
                  value: c,
                  child: Text(c),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _category = val;
                    if (val.contains('Kemasan')) {
                      _isPackaging = true;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              title: const Text('Pengeluaran ini adalah Biaya Kemasan'),
              subtitle: const Text('Akan direkap secara terpisah pada laporan laba rugi.'),
              value: _isPackaging,
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  _isPackaging = val ?? false;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Keterangan Pengeluaran',
                hintText: 'Beli 10 karung cabai, BBM pikap, upah kuli, dll.',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveExpense,
              icon: const Icon(Icons.save),
              label: const Text('Simpan Pengeluaran Kas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
