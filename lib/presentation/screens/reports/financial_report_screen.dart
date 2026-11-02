import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/business_calculator.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/services/excel_service.dart';
import '../../../data/services/share_service.dart';
import '../../providers/providers.dart';
import 'transaction_recap_screen.dart';

enum ReportPeriod { daily, weekly, monthly, yearly, custom }

class FinancialReportScreen extends ConsumerStatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  ConsumerState<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends ConsumerState<FinancialReportScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.monthly;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  FinancialResult? _result;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _applyPeriod(ReportPeriod.monthly);
  }

  void _applyPeriod(ReportPeriod period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (period) {
      case ReportPeriod.daily:
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
      case ReportPeriod.weekly:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
        break;
      case ReportPeriod.monthly:
        start = DateTime(now.year, now.month, 1);
        break;
      case ReportPeriod.yearly:
        start = DateTime(now.year, 1, 1);
        break;
      case ReportPeriod.custom:
        start = _startDate;
        end = _endDate;
        break;
    }

    setState(() {
      _selectedPeriod = period;
      _startDate = start;
      _endDate = end;
    });

    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final repo = ref.read(repositoryProvider);
    final res = await repo.getFinancialReport(startDate: _startDate, endDate: _endDate);

    if (mounted) {
      setState(() {
        _result = res;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToExcel() async {
    final profile = await ref.read(businessProfileProvider.future);
    final repo = ref.read(repositoryProvider);
    final sales = await repo.getSalesInDateRange(_startDate, _endDate);
    final buyers = await repo.getActiveBuyers();
    final buyerMap = {for (final b in buyers) b.id: b.name};

    final salesRows = sales.map((s) {
      return {
        'date': s.saleDate,
        'invoice': s.invoiceNumber,
        'buyer': buyerMap[s.buyerId] ?? 'Pembeli',
        'total': s.totalAmount,
        'paid': s.paidAmount,
        'remaining': s.remainingAmount,
      };
    }).toList();

    final expenses = await repo.getExpensesInDateRange(_startDate, _endDate);

    final expenseRows = expenses.map((e) {
      return {
        'date': e.expenseDate,
        'number': e.expenseNumber,
        'category': e.category,
        'notes': e.notes,
        'amount': e.amount,
      };
    }).toList();

    final excelFile = await ExcelService.exportFinancialReport(
      businessName: profile?.businessName ?? AppStrings.appName,
      startDate: _startDate,
      endDate: _endDate,
      totalOmzet: _result?.omzet ?? 0.0,
      totalHakPetani: _result?.hakPetani ?? 0.0,
      marginKotor: _result?.marginKotor ?? 0.0,
      totalPengeluaran: (_result?.operationalExpenses ?? 0.0) + (_result?.packagingExpenses ?? 0.0),
      labaBersih: _result?.labaBersih ?? 0.0,
      salesRows: salesRows,
      expenseRows: expenseRows,
    );

    await ShareService.shareFile(
      file: excelFile,
      text: 'Laporan Keuangan TaniFlow Excel',
      subject: 'Laporan Keuangan',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Keuangan & Laba'),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: 'Rekap Transaksi Petani & Pembeli',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransactionRecapScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: 'Export Excel (XLSX)',
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Periode Tab Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip('Hari Ini', ReportPeriod.daily),
                  const SizedBox(width: 8),
                  _buildPeriodChip('7 Hari', ReportPeriod.weekly),
                  const SizedBox(width: 8),
                  _buildPeriodChip('Bulan Ini', ReportPeriod.monthly),
                  const SizedBox(width: 8),
                  _buildPeriodChip('Tahun Ini', ReportPeriod.yearly),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      '${DateFormatter.formatDate(_startDate)} - ${DateFormatter.formatDate(_endDate)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked.start;
                          _endDate = picked.end;
                          _selectedPeriod = ReportPeriod.custom;
                        });
                        _loadReport();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Laporan Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadReport,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Banner Rekapitulasi Transaksi Petani & Pembeli
                          Card(
                            elevation: 0,
                            color: AppColors.primaryLighter,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.primaryLight),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Icon(Icons.summarize_outlined, color: Colors.white, size: 20),
                              ),
                              title: const Text('Rekapitulasi Transaksi Petani & Pembeli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: const Text('Pilih riwayat transaksi, hitung sisa hutang/piutang, cetak struk & PDF', style: TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TransactionRecapScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 1. Highlight Card Laba Bersih
                          _buildNetProfitHighlightCard(_result!),
                          const SizedBox(height: 16),

                          // 2. Rincian Laba Rugi Berjenjang
                          const Text(
                            'Struktur Perhitungan Laba Rugi Usaha',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 10),
                          _buildFinancialBreakdownCard(_result!),
                          const SizedBox(height: 20),

                          // 3. Catatan Standar Akuntansi
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLighter,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Standar Perhitungan Akuntansi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                SizedBox(height: 4),
                                Text(
                                  '• Omzet dihitung dari seluruh nilai transaksi penjualan aktual (termasuk tunai & piutang tempo).\n'
                                  '• Hak Petani diakui berdasarkan kesepakatan harga per kg hasil sortir panen.\n'
                                  '• Pembayaran kas kepada petani bukan pengurang laba kedua kalinya (hanya mutasi kas keluar).',
                                  style: TextStyle(fontSize: 11, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, ReportPeriod period) {
    final isSelected = _selectedPeriod == period;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) => _applyPeriod(period),
    );
  }

  Widget _buildNetProfitHighlightCard(FinancialResult res) {
    final isProfitable = res.labaBersih >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfitable
              ? [AppColors.primaryDark, AppColors.primary]
              : [const Color(0xFFB71C1C), AppColors.danger],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
                'Laba Bersih Usaha',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${res.marginBersihPercent.toStringAsFixed(1)}% Margin Bersih',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(res.labaBersih),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Omzet: ${CurrencyFormatter.format(res.omzet)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                'Margin Kotor: ${CurrencyFormatter.format(res.marginKotor)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialBreakdownCard(FinancialResult res) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildRow('Total Omzet Penjualan', res.omzet, isBold: true),
          const SizedBox(height: 8),
          _buildRow('(-) Hak Petani (Kewajiban Pembelian)', -res.hakPetani, color: AppColors.textSecondary),
          if (res.ownerDamageLoss > 0) ...[
            const SizedBox(height: 8),
            _buildRow('(-) Beban Kerugian Sayur Rusak', -res.ownerDamageLoss, color: AppColors.danger),
          ],
          const Divider(height: 20),
          _buildRow('(=) Margin Kotor Usaha', res.marginKotor,
              isBold: true, color: AppColors.primary, subtitle: '${res.marginKotorPercent.toStringAsFixed(1)}% dari Omzet'),
          const Divider(height: 20),
          _buildRow('(-) Biaya Kemasan (Karung/Keranjang/Peti)', -res.packagingExpenses, color: AppColors.secondary),
          const SizedBox(height: 8),
          _buildRow('(-) Pengeluaran Operasional & Logistik', -res.operationalExpenses, color: AppColors.secondary),
          const Divider(height: 20, thickness: 1.5),
          _buildRow('(=) Laba Bersih Akhir', res.labaBersih,
              isBold: true, color: res.labaBersih >= 0 ? AppColors.primary : AppColors.danger, isLarge: true),
        ],
      ),
    );
  }

  Widget _buildRow(String label, double amount,
      {bool isBold = false, Color? color, String? subtitle, bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isLarge ? 15 : 13,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
          ],
        ),
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isLarge ? 17 : 13,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
