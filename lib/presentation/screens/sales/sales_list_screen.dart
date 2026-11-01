import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/services/share_service.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'sales_form_screen.dart';

class SalesListScreen extends ConsumerWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesProvider);
    final buyersAsync = ref.watch(activeBuyersProvider);

    final buyerMap = {for (final b in buyersAsync.value ?? []) b.id: b};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Penjualan Pasar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Penjualan Baru',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalesFormScreen()),
              );
            },
          ),
        ],
      ),
      body: salesAsync.when(
        data: (sales) {
          if (sales.isEmpty) {
            return EmptyState(
              icon: Icons.point_of_sale_outlined,
              title: 'Belum Ada Transaksi Penjualan',
              message: 'Catat hasil penjualan sayur di pasar induk kepada pembeli atau kios mitra.',
              buttonText: 'Buat Penjualan Baru',
              onButtonPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SalesFormScreen()),
                );
              },
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sales.length,
            itemBuilder: (context, index) {
              final s = sales[index];
              final buyer = buyerMap[s.buyerId];

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            s.invoiceNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          StatusBadge(status: s.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pembeli: ${buyer?.name ?? "Pembeli"}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Waktu: ${DateFormatter.formatDateTime(s.saleDate)}  |  Tipe: ${s.paymentType}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total: ${CurrencyFormatter.format(s.totalAmount)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (s.remainingAmount > 0)
                                Text(
                                  'Sisa Piutang: ${CurrencyFormatter.format(s.remainingAmount)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.danger,
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share_outlined, color: AppColors.primary, size: 20),
                                tooltip: 'Bagikan Nota WhatsApp',
                                onPressed: () async {
                                  final profile = await ref.read(businessProfileProvider.future);
                                  await ShareService.shareSalesInvoiceText(
                                    businessName: profile?.businessName ?? AppStrings.appName,
                                    invoiceNumber: s.invoiceNumber,
                                    date: s.saleDate,
                                    buyerName: buyer?.name ?? 'Pembeli',
                                    items: [], // overview
                                    totalAmount: s.totalAmount,
                                    paidAmount: s.paidAmount,
                                    remainingAmount: s.remainingAmount,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.print_outlined, color: AppColors.primary, size: 20),
                                tooltip: 'Cetak Thermal',
                                onPressed: () async {
                                  final printer = ref.read(printerServiceProvider);
                                  final profile = await ref.read(businessProfileProvider.future);

                                  final ok = await printer.printSalesInvoice(
                                    businessName: profile?.businessName ?? AppStrings.appName,
                                    invoiceNumber: s.invoiceNumber,
                                    date: s.saleDate,
                                    buyerName: buyer?.name ?? 'Pembeli',
                                    items: [],
                                    totalAmount: s.totalAmount,
                                    paidAmount: s.paidAmount,
                                    remainingAmount: s.remainingAmount,
                                  );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok ? 'Nota berhasil dicetak' : 'Gagal mencetak nota.'),
                                        backgroundColor: ok ? AppColors.primary : AppColors.danger,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal memuat penjualan: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SalesFormScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Penjualan Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
