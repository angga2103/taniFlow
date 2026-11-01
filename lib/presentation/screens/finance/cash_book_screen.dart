import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';
import 'daily_cash_closing_screen.dart';
import 'expense_form_screen.dart';

class CashBookScreen extends ConsumerStatefulWidget {
  const CashBookScreen({super.key});

  @override
  ConsumerState<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends ConsumerState<CashBookScreen> {
  String _filter = 'ALL'; // 'ALL', 'IN', 'OUT'

  @override
  Widget build(BuildContext context) {
    final cashBalanceAsync = ref.watch(currentCashBalanceProvider);
    final transactionsAsync = ref.watch(cashTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Kas Harian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_clock),
            tooltip: 'Tutup Kas Harian',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DailyCashClosingScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Saldo Kas
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo Kas Fisik Berjalan',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                cashBalanceAsync.when(
                  data: (bal) => Text(
                    CurrencyFormatter.format(bal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  loading: () => const Text('Memuat saldo...', style: TextStyle(color: Colors.white)),
                  error: (e, s) => const Text('Rp 0', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),

          // Filter Segment
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Semua Mutasi')),
                    selected: _filter == 'ALL',
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(color: _filter == 'ALL' ? Colors.white : AppColors.textPrimary),
                    onSelected: (val) {
                      if (val) setState(() => _filter = 'ALL');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Kas Masuk')),
                    selected: _filter == 'IN',
                    selectedColor: AppColors.success,
                    labelStyle: TextStyle(color: _filter == 'IN' ? Colors.white : AppColors.textPrimary),
                    onSelected: (val) {
                      if (val) setState(() => _filter = 'IN');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Kas Keluar')),
                    selected: _filter == 'OUT',
                    selectedColor: AppColors.danger,
                    labelStyle: TextStyle(color: _filter == 'OUT' ? Colors.white : AppColors.textPrimary),
                    onSelected: (val) {
                      if (val) setState(() => _filter = 'OUT');
                    },
                  ),
                ),
              ],
            ),
          ),

          // Daftar Mutasi Kas
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                final filtered = transactions.where((t) {
                  if (_filter == 'IN') return t.type == 'KAS_MASUK';
                  if (_filter == 'OUT') return t.type == 'KAS_KELUAR';
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Belum Ada Transaksi Kas',
                    message: 'Mutasi penerimaan penjualan atau pengeluaran operasional akan tercatat di sini.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    final isIncome = tx.type == 'KAS_MASUK';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isIncome ? AppColors.successLight : AppColors.dangerLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIncome ? AppColors.success : AppColors.danger,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tx.category.replaceAll('_', ' '),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${isIncome ? "+" : "-"} ${CurrencyFormatter.format(tx.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isIncome ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              tx.notes ?? '-',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateFormatter.formatDateTime(tx.transactionDate)}  |  Saldo: ${CurrencyFormatter.format(tx.balanceAfter)}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Gagal memuat kas: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
          );
        },
        backgroundColor: AppColors.danger,
        icon: const Icon(Icons.money_off, color: Colors.white),
        label: const Text('Catat Pengeluaran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
