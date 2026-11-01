import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../providers/providers.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/quick_action_button.dart';
import '../../widgets/responsive_layout.dart';
import '../submissions/submission_form_screen.dart';
import '../grading/grading_list_screen.dart';
import '../shipments/shipment_form_screen.dart';
import '../sales/sales_form_screen.dart';
import '../settlement/farmer_payment_screen.dart';
import '../settlement/buyer_payment_screen.dart';
import '../finance/expense_form_screen.dart';
import '../finance/daily_cash_closing_screen.dart';
import '../printer/printer_settings_screen.dart';
import '../backup/backup_screen.dart';
import '../reports/transaction_recap_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessProfileAsync = ref.watch(businessProfileProvider);
    final submissionsAsync = ref.watch(submissionsProvider);
    final salesAsync = ref.watch(salesProvider);
    final shipmentsAsync = ref.watch(shipmentsProvider);
    final cashBalanceAsync = ref.watch(currentCashBalanceProvider);
    final receivablesAsync = ref.watch(receivablesProvider);

    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            businessProfileAsync.when(
              data: (profile) => Text(
                profile?.businessName ?? AppStrings.appName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              loading: () => const Text(AppStrings.appName),
              error: (e, s) => const Text(AppStrings.appName),
            ),
            Text(
              DateFormatter.formatDayDate(today),
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Pengaturan Printer Bluetooth',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Backup & Restore',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(submissionsProvider);
          ref.invalidate(salesProvider);
          ref.invalidate(currentCashBalanceProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Saldo Kas Banner
              _buildCashBanner(cashBalanceAsync),
              const SizedBox(height: 20),

              // 2. Tombol Aksi Cepat Operasional (8 Tombol Utama Sesuai Spesifikasi)
              const Text(
                'Aksi Cepat Operasional',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 24),

              // 3. Ringkasan Hari Ini
              const Text(
                'Ringkasan Aktivitas Operasional',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildMetricsGrid(
                context,
                submissionsAsync: submissionsAsync,
                salesAsync: salesAsync,
                shipmentsAsync: shipmentsAsync,
                receivablesAsync: receivablesAsync,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashBanner(AsyncValue<double> cashBalanceAsync) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saldo Kas Berjalan',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Buku Kas', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          cashBalanceAsync.when(
            data: (bal) => Text(
              CurrencyFormatter.format(bal),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            loading: () => const Text('Memuat saldo...', style: TextStyle(color: Colors.white70)),
            error: (e, s) => const Text('Rp 0', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {
        'label': 'Setoran Baru',
        'icon': Icons.add_shopping_cart,
        'color': AppColors.primary,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmissionFormScreen())),
      },
      {
        'label': 'Sortir & Grading',
        'icon': Icons.grading,
        'color': AppColors.info,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GradingListScreen())),
      },
      {
        'label': 'Pengiriman Baru',
        'icon': Icons.local_shipping,
        'color': AppColors.accent,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShipmentFormScreen())),
      },
      {
        'label': 'Penjualan Baru',
        'icon': Icons.point_of_sale,
        'color': AppColors.success,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesFormScreen())),
      },
      {
        'label': 'Bayar Petani',
        'icon': Icons.payments,
        'color': AppColors.secondary,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmerPaymentScreen())),
      },
      {
        'label': 'Piutang Pembeli',
        'icon': Icons.receipt_long,
        'color': Colors.indigo,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BuyerPaymentScreen())),
      },
      {
        'label': 'Pengeluaran',
        'icon': Icons.money_off,
        'color': AppColors.danger,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseFormScreen())),
      },
      {
        'label': 'Tutup Kas',
        'icon': Icons.lock_clock,
        'color': Colors.teal,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyCashClosingScreen())),
      },
      {
        'label': 'Rekap Transaksi',
        'icon': Icons.summarize_outlined,
        'color': Colors.deepOrange,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionRecapScreen())),
      },
    ];

    final isTablet = ResponsiveLayout.isTablet(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 4 : 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final a = actions[index];
        return QuickActionButton(
          label: a['label'] as String,
          icon: a['icon'] as IconData,
          color: a['color'] as Color,
          onTap: a['onTap'] as VoidCallback,
        );
      },
    );
  }

  Widget _buildMetricsGrid(
    BuildContext context, {
    required AsyncValue submissionsAsync,
    required AsyncValue salesAsync,
    required AsyncValue shipmentsAsync,
    required AsyncValue receivablesAsync,
  }) {
    final isTablet = ResponsiveLayout.isTablet(context);

    double totalNetWeight = 0.0;
    int submissionCount = 0;
    submissionsAsync.whenData((list) {
      submissionCount = (list as List).length;
      for (final s in list) {
        totalNetWeight += (s.totalNetWeight as num).toDouble();
      }
    });

    double totalSalesAmount = 0.0;
    int salesCount = 0;
    salesAsync.whenData((list) {
      salesCount = (list as List).length;
      for (final s in list) {
        totalSalesAmount += (s.totalAmount as num).toDouble();
      }
    });

    int shipmentCount = 0;
    shipmentsAsync.whenData((list) {
      shipmentCount = (list as List).length;
    });

    double totalPiutang = 0.0;
    receivablesAsync.whenData((list) {
      for (final r in list) {
        totalPiutang += (r.remainingAmount as num).toDouble();
      }
    });

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 4 : 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: isTablet ? 1.4 : 1.2,
      children: [
        MetricCard(
          title: 'Setoran Panen',
          value: '$submissionCount Transaksi',
          subtitle: 'Total: ${WeightFormatter.format(totalNetWeight)}',
          icon: Icons.inventory_2_outlined,
          color: AppColors.primary,
        ),
        MetricCard(
          title: 'Total Penjualan',
          value: CurrencyFormatter.format(totalSalesAmount),
          subtitle: '$salesCount Transaksi Pasar',
          icon: Icons.trending_up,
          color: AppColors.success,
        ),
        MetricCard(
          title: 'Pengiriman Pasar',
          value: '$shipmentCount Pengiriman',
          subtitle: 'Hari ini',
          icon: Icons.local_shipping_outlined,
          color: AppColors.accent,
        ),
        MetricCard(
          title: 'Piutang Pembeli',
          value: CurrencyFormatter.format(totalPiutang),
          subtitle: 'Belum terbayar',
          icon: Icons.pending_actions,
          color: AppColors.danger,
        ),
      ],
    );
  }
}
