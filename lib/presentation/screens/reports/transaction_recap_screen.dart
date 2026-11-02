import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../../data/services/pdf_service.dart';
import '../../../data/services/share_service.dart';
import '../../providers/providers.dart';
import '../printer/printer_settings_screen.dart';

class TransactionRecapScreen extends ConsumerStatefulWidget {
  final String? initialFarmerId;
  final String? initialBuyerId;
  final int initialTabIndex;

  const TransactionRecapScreen({
    super.key,
    this.initialFarmerId,
    this.initialBuyerId,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<TransactionRecapScreen> createState() => _TransactionRecapScreenState();
}

class _TransactionRecapScreenState extends ConsumerState<TransactionRecapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Farmer recap state
  String? _selectedFarmerId;
  String _farmerPeriod = 'SEMUA'; // SEMUA, HARI_INI, 7_HARI, BULAN_INI
  List<FarmerSubmission> _farmerSubmissions = [];
  Map<String, List<SubmissionItem>> _submissionItemsMap = {};
  Map<String, double> _submissionHakMap = {};
  final Set<String> _selectedSubmissionIds = {};
  double _totalFarmerPaid = 0.0;
  bool _isLoadingFarmer = false;

  // Buyer recap state
  String? _selectedBuyerId;
  String _buyerPeriod = 'SEMUA';
  List<Sale> _buyerSales = [];
  Map<String, List<SaleItem>> _saleItemsMap = {};
  final Set<String> _selectedSaleIds = {};
  double _totalBuyerPaid = 0.0;
  bool _isLoadingBuyer = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _selectedFarmerId = widget.initialFarmerId;
    _selectedBuyerId = widget.initialBuyerId;

    if (_selectedFarmerId != null) {
      _loadFarmerData(_selectedFarmerId!);
    }
    if (_selectedBuyerId != null) {
      _loadBuyerData(_selectedBuyerId!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Filter dates
  bool _filterDate(DateTime date, String period) {
    final now = DateTime.now();
    switch (period) {
      case 'HARI_INI':
        return date.year == now.year && date.month == now.month && date.day == now.day;
      case '7_HARI':
        return date.isAfter(now.subtract(const Duration(days: 7)));
      case 'BULAN_INI':
        return date.year == now.year && date.month == now.month;
      case 'SEMUA':
      default:
        return true;
    }
  }

  // Load Farmer transactions
  Future<void> _loadFarmerData(String farmerId) async {
    setState(() => _isLoadingFarmer = true);
    final repo = ref.read(repositoryProvider);

    try {
      final allSubs = await repo.getFarmerSubmissions(farmerId);
      final filteredSubs = allSubs.where((s) => _filterDate(s.submissionDate, _farmerPeriod)).toList();

      final itemsMap = <String, List<SubmissionItem>>{};
      final hakMap = <String, double>{};

      for (final s in filteredSubs) {
        final items = await repo.getSubmissionItems(s.id);
        itemsMap[s.id] = items;
      }

      final determinations = await repo.getFarmerPriceDeterminations(farmerId);
      for (final d in determinations) {
        hakMap[d.submissionId] = (hakMap[d.submissionId] ?? 0.0) + d.netFarmerAmount;
      }

      final payments = await repo.getFarmerPayments(farmerId);
      double paid = 0.0;
      for (final p in payments) {
        if (_filterDate(p.paymentDate, _farmerPeriod)) {
          paid += p.amount;
        }
      }

      setState(() {
        _farmerSubmissions = filteredSubs;
        _submissionItemsMap = itemsMap;
        _submissionHakMap = hakMap;
        _totalFarmerPaid = paid;
        _selectedSubmissionIds.clear();
        _selectedSubmissionIds.addAll(filteredSubs.map((s) => s.id));
        _isLoadingFarmer = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingFarmer = false);
    }
  }

  // Load Buyer transactions
  Future<void> _loadBuyerData(String buyerId) async {
    setState(() => _isLoadingBuyer = true);
    final repo = ref.read(repositoryProvider);

    try {
      final allSales = await repo.getBuyerSales(buyerId);
      final filteredSales = allSales.where((s) => _filterDate(s.saleDate, _buyerPeriod)).toList();

      final itemsMap = <String, List<SaleItem>>{};
      for (final s in filteredSales) {
        final items = await repo.getSaleItems(s.id);
        itemsMap[s.id] = items;
      }

      final payments = await repo.getBuyerPayments(buyerId);
      double paid = 0.0;
      for (final p in payments) {
        if (_filterDate(p.paymentDate, _buyerPeriod)) {
          paid += p.amount;
        }
      }

      setState(() {
        _buyerSales = filteredSales;
        _saleItemsMap = itemsMap;
        _totalBuyerPaid = paid;
        _selectedSaleIds.clear();
        _selectedSaleIds.addAll(filteredSales.map((s) => s.id));
        _isLoadingBuyer = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingBuyer = false);
    }
  }

  String _getPeriodLabel(String period) {
    switch (period) {
      case 'HARI_INI':
        return 'Hari Ini';
      case '7_HARI':
        return '7 Hari Terakhir';
      case 'BULAN_INI':
        return 'Bulan Ini';
      default:
        return 'Semua Periode';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekapitulasi Transaksi'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.72),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
          tabs: const [
            Tab(icon: Icon(Icons.agriculture_rounded, size: 20), text: 'Rekap Petani'),
            Tab(icon: Icon(Icons.storefront_rounded, size: 20), text: 'Rekap Pembeli'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFarmerRecapTab(),
          _buildBuyerRecapTab(),
        ],
      ),
    );
  }

  Widget _buildGradeBadge(String grade) {
    Color bg;
    Color fg;
    if (grade.contains('A') || grade.toLowerCase().contains('super')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (grade.contains('B') || grade.toLowerCase().contains('standar')) {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1E40AF);
    } else if (grade.contains('C')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else if (grade.toLowerCase().contains('reject')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF334155);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        grade,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // ==========================================
  // 1. TAB REKAP PETANI
  // ==========================================
  Widget _buildFarmerRecapTab() {
    final farmersAsync = ref.watch(activeFarmersProvider);
    final commodities = ref.watch(commoditiesProvider).value ?? [];
    final commMap = {for (final c in commodities) c.id: c.name};

    // Calculate selected totals
    double selectedWeight = 0.0;
    double selectedHak = 0.0;

    for (final sub in _farmerSubmissions) {
      if (_selectedSubmissionIds.contains(sub.id)) {
        selectedWeight += sub.totalNetWeight;
        selectedHak += (_submissionHakMap[sub.id] ?? 0.0);
      }
    }

    final remainingKewajiban = selectedHak - _totalFarmerPaid;

    return Column(
      children: [
        // Filter Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              farmersAsync.when(
                data: (farmers) {
                  return DropdownButtonFormField<String>(
                    value: _selectedFarmerId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Pilih Petani Penyetor',
                      prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    items: farmers.map((f) {
                      return DropdownMenuItem<String>(
                        value: f.id,
                        child: Text(
                          '${f.name} ${f.address != null ? "(${f.address})" : ""}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedFarmerId = val);
                      if (val != null) _loadFarmerData(val);
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Periode:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    const SizedBox(width: 8),
                    _buildPeriodChip('SEMUA', 'Semua', _farmerPeriod, (p) {
                      setState(() => _farmerPeriod = p);
                      if (_selectedFarmerId != null) _loadFarmerData(_selectedFarmerId!);
                    }),
                    _buildPeriodChip('HARI_INI', 'Hari Ini', _farmerPeriod, (p) {
                      setState(() => _farmerPeriod = p);
                      if (_selectedFarmerId != null) _loadFarmerData(_selectedFarmerId!);
                    }),
                    _buildPeriodChip('7_HARI', '7 Hari', _farmerPeriod, (p) {
                      setState(() => _farmerPeriod = p);
                      if (_selectedFarmerId != null) _loadFarmerData(_selectedFarmerId!);
                    }),
                    _buildPeriodChip('BULAN_INI', 'Bulan Ini', _farmerPeriod, (p) {
                      setState(() => _farmerPeriod = p);
                      if (_selectedFarmerId != null) _loadFarmerData(_selectedFarmerId!);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Select All row
        if (_farmerSubmissions.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedSubmissionIds.length == _farmerSubmissions.length) {
                        _selectedSubmissionIds.clear();
                      } else {
                        _selectedSubmissionIds.addAll(_farmerSubmissions.map((s) => s.id));
                      }
                    });
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _selectedSubmissionIds.length == _farmerSubmissions.length &&
                              _farmerSubmissions.isNotEmpty,
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSubmissionIds.addAll(_farmerSubmissions.map((s) => s.id));
                              } else {
                                _selectedSubmissionIds.clear();
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pilih Semua (${_selectedSubmissionIds.length}/${_farmerSubmissions.length})',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_farmerSubmissions.length} Transaksi',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

        // List Transaksi
        Expanded(
          child: _selectedFarmerId == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_outlined, size: 52, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'Silakan pilih petani di atas untuk melihat rekapitulasi.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : _isLoadingFarmer
                  ? const Center(child: CircularProgressIndicator())
                  : _farmerSubmissions.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada riwayat setoran pada periode ini.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          itemCount: _farmerSubmissions.length,
                          itemBuilder: (ctx, i) {
                            final sub = _farmerSubmissions[i];
                            final isChecked = _selectedSubmissionIds.contains(sub.id);
                            final items = _submissionItemsMap[sub.id] ?? [];
                            final hak = _submissionHakMap[sub.id] ?? 0.0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isChecked ? AppColors.primary : const Color(0xFFE2E8F0),
                                  width: isChecked ? 1.5 : 1.0,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isChecked) {
                                      _selectedSubmissionIds.remove(sub.id);
                                    } else {
                                      _selectedSubmissionIds.add(sub.id);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Header
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: Checkbox(
                                              value: isChecked,
                                              activeColor: AppColors.primary,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedSubmissionIds.add(sub.id);
                                                  } else {
                                                    _selectedSubmissionIds.remove(sub.id);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sub.transactionNumber,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                                ),
                                                Text(
                                                  DateFormatter.formatDateTime(sub.submissionDate),
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: hak > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: hak > 0 ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  hak > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                                  size: 12,
                                                  color: hak > 0 ? const Color(0xFF166534) : const Color(0xFF92400E),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  hak > 0 ? 'Hak: ${CurrencyFormatter.format(hak)}' : 'Belum Ditentukan',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: hak > 0 ? const Color(0xFF166534) : const Color(0xFF92400E),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Item Rincian Box
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Column(
                                          children: items.map((it) {
                                            final name = commMap[it.commodityId] ?? 'Sayur';
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2.5),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                                  ),
                                                  Text(
                                                    WeightFormatter.format(it.netWeight),
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Total Bar
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Netto Total: ${WeightFormatter.format(sub.totalNetWeight)}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                          if (hak > 0)
                                            Text(
                                              'Total Hak: ${CurrencyFormatter.format(hak)}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),

        // Summary Bar & Action Buttons
        if (_selectedFarmerId != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Berat (${_selectedSubmissionIds.length} nota):', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(WeightFormatter.format(selectedWeight), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Hak Petani:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(CurrencyFormatter.format(selectedHak), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pembayaran Tercatat:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(CurrencyFormatter.format(_totalFarmerPaid), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                // Highlight Container for Sisa Kewajiban
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: remainingKewajiban == 0
                        ? const Color(0xFFDCFCE7)
                        : (remainingKewajiban > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: remainingKewajiban == 0
                          ? const Color(0xFF86EFAC)
                          : (remainingKewajiban > 0 ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        remainingKewajiban == 0
                            ? 'STATUS KEWAJIBAN:'
                            : (remainingKewajiban > 0 ? 'SISA KEWAJIBAN USAHA:' : 'PEMBAYARAN BERLEBIH:'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: remainingKewajiban == 0
                              ? const Color(0xFF166534)
                              : (remainingKewajiban > 0 ? const Color(0xFF991B1B) : const Color(0xFF1E40AF)),
                        ),
                      ),
                      Text(
                        remainingKewajiban == 0 ? 'LUNAS (Rp 0)' : CurrencyFormatter.format(remainingKewajiban.abs()),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: remainingKewajiban == 0
                              ? const Color(0xFF166534)
                              : (remainingKewajiban > 0 ? const Color(0xFF991B1B) : const Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectedSubmissionIds.isEmpty
                            ? null
                            : () => _printFarmerRecap(selectedWeight, selectedHak, remainingKewajiban),
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Cetak Struk', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedSubmissionIds.isEmpty
                            ? null
                            : () => _exportFarmerRecapPdf(selectedWeight, selectedHak, remainingKewajiban),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        label: const Text('Export PDF', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 1.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.share_outlined, color: AppColors.primary, size: 20),
                        tooltip: 'Bagikan',
                        onPressed: _selectedSubmissionIds.isEmpty
                            ? null
                            : () => _shareFarmerRecap(selectedWeight, selectedHak, remainingKewajiban),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ==========================================
  // 2. TAB REKAP PEMBELI
  // ==========================================
  Widget _buildBuyerRecapTab() {
    final buyersAsync = ref.watch(activeBuyersProvider);
    final commodities = ref.watch(commoditiesProvider).value ?? [];
    final commMap = {for (final c in commodities) c.id: c.name};

    // Calculate selected totals
    double selectedWeight = 0.0;
    double selectedSalesAmount = 0.0;
    double selectedRemainingReceivable = 0.0;

    for (final sale in _buyerSales) {
      if (_selectedSaleIds.contains(sale.id)) {
        selectedSalesAmount += sale.totalAmount;
        selectedRemainingReceivable += sale.remainingAmount;

        final items = _saleItemsMap[sale.id] ?? [];
        for (final it in items) {
          selectedWeight += it.weight;
        }
      }
    }

    final totalDiterima = _totalBuyerPaid > 0
        ? _totalBuyerPaid
        : (selectedSalesAmount - selectedRemainingReceivable);

    return Column(
      children: [
        // Filter Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buyersAsync.when(
                data: (buyers) {
                  return DropdownButtonFormField<String>(
                    value: _selectedBuyerId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Pilih Pembeli / Pelanggan',
                      prefixIcon: const Icon(Icons.storefront, color: AppColors.primary),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    items: buyers.map((b) {
                      return DropdownMenuItem<String>(
                        value: b.id,
                        child: Text(
                          '${b.name}${b.address != null ? " (${b.address})" : ""}${b.phone != null ? " • ${b.phone}" : ""}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedBuyerId = val);
                      if (val != null) _loadBuyerData(val);
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Periode:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    const SizedBox(width: 8),
                    _buildPeriodChip('SEMUA', 'Semua', _buyerPeriod, (p) {
                      setState(() => _buyerPeriod = p);
                      if (_selectedBuyerId != null) _loadBuyerData(_selectedBuyerId!);
                    }),
                    _buildPeriodChip('HARI_INI', 'Hari Ini', _buyerPeriod, (p) {
                      setState(() => _buyerPeriod = p);
                      if (_selectedBuyerId != null) _loadBuyerData(_selectedBuyerId!);
                    }),
                    _buildPeriodChip('7_HARI', '7 Hari', _buyerPeriod, (p) {
                      setState(() => _buyerPeriod = p);
                      if (_selectedBuyerId != null) _loadBuyerData(_selectedBuyerId!);
                    }),
                    _buildPeriodChip('BULAN_INI', 'Bulan Ini', _buyerPeriod, (p) {
                      setState(() => _buyerPeriod = p);
                      if (_selectedBuyerId != null) _loadBuyerData(_selectedBuyerId!);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Select All row
        if (_buyerSales.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedSaleIds.length == _buyerSales.length) {
                        _selectedSaleIds.clear();
                      } else {
                        _selectedSaleIds.addAll(_buyerSales.map((s) => s.id));
                      }
                    });
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _selectedSaleIds.length == _buyerSales.length && _buyerSales.isNotEmpty,
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSaleIds.addAll(_buyerSales.map((s) => s.id));
                              } else {
                                _selectedSaleIds.clear();
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pilih Semua (${_selectedSaleIds.length}/${_buyerSales.length})',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_buyerSales.length} Nota Penjualan',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

        // List Transaksi
        Expanded(
          child: _selectedBuyerId == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_outlined, size: 52, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'Silakan pilih pembeli di atas untuk melihat rekapitulasi.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : _isLoadingBuyer
                  ? const Center(child: CircularProgressIndicator())
                  : _buyerSales.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada riwayat penjualan pada periode ini.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          itemCount: _buyerSales.length,
                          itemBuilder: (ctx, i) {
                            final sale = _buyerSales[i];
                            final isChecked = _selectedSaleIds.contains(sale.id);
                            final items = _saleItemsMap[sale.id] ?? [];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isChecked ? AppColors.primary : const Color(0xFFE2E8F0),
                                  width: isChecked ? 1.5 : 1.0,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isChecked) {
                                      _selectedSaleIds.remove(sale.id);
                                    } else {
                                      _selectedSaleIds.add(sale.id);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Header
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: Checkbox(
                                              value: isChecked,
                                              activeColor: AppColors.primary,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedSaleIds.add(sale.id);
                                                  } else {
                                                    _selectedSaleIds.remove(sale.id);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sale.invoiceNumber,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                                ),
                                                Text(
                                                  DateFormatter.formatDateTime(sale.saleDate),
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _buildStatusBadge(sale.status, sale.remainingAmount),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Item Rincian Box
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Column(
                                          children: items.map((it) {
                                            final name = commMap[it.commodityId] ?? 'Sayur';
                                            final subtotal = it.weight * it.pricePerKg;
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2.5),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 5,
                                                    child: Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            name,
                                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        _buildGradeBadge(it.grade),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 6,
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                          '${WeightFormatter.format(it.weight)} @ ${CurrencyFormatter.format(it.pricePerKg)}',
                                                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          CurrencyFormatter.format(subtotal),
                                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Total Footer
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Total Muatan: ${WeightFormatter.format(items.fold<double>(0.0, (double sum, i) => sum + i.weight))}',
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                          ),
                                          Text(
                                            'Total: ${CurrencyFormatter.format(sale.totalAmount)}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),

        // Summary Bar & Action Buttons
        if (_selectedBuyerId != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Berat Terjual (${_selectedSaleIds.length} nota):', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(WeightFormatter.format(selectedWeight), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Nilai Penjualan:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(CurrencyFormatter.format(selectedSalesAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Sudah Diterima:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(CurrencyFormatter.format(totalDiterima), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                // Highlight Container for Sisa Piutang
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selectedRemainingReceivable == 0
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedRemainingReceivable == 0
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedRemainingReceivable == 0 ? 'STATUS PIUTANG:' : 'SISA PIUTANG PEMBELI:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: selectedRemainingReceivable == 0 ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        ),
                      ),
                      Text(
                        selectedRemainingReceivable == 0 ? 'LUNAS (Rp 0)' : CurrencyFormatter.format(selectedRemainingReceivable),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: selectedRemainingReceivable == 0 ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectedSaleIds.isEmpty
                            ? null
                            : () => _printBuyerRecap(selectedWeight, selectedSalesAmount, totalDiterima, selectedRemainingReceivable),
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Cetak Struk', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedSaleIds.isEmpty
                            ? null
                            : () => _exportBuyerRecapPdf(selectedWeight, selectedSalesAmount, totalDiterima, selectedRemainingReceivable),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        label: const Text('Export PDF', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 1.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.share_outlined, color: AppColors.primary, size: 20),
                        tooltip: 'Bagikan',
                        onPressed: _selectedSaleIds.isEmpty
                            ? null
                            : () => _shareBuyerRecap(selectedWeight, selectedSalesAmount, totalDiterima, selectedRemainingReceivable),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, [double remaining = 0.0]) {
    if (status == 'LUNAS' || remaining == 0.0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF166534)),
            SizedBox(width: 4),
            Text('LUNAS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF991B1B)),
            const SizedBox(width: 4),
            Text(
              'SISA: ${CurrencyFormatter.format(remaining)}',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPeriodChip(String id, String label, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
        selected: isSelected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: const Color(0xFFF1F5F9),
        side: BorderSide(
          color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (val) {
          if (val) onSelect(id);
        },
      ),
    );
  }

  // ==========================================
  // ACTION HANDLERS
  // ==========================================
  Future<void> _printFarmerRecap(double weight, double hak, double sisa) async {
    final printer = ref.read(printerServiceProvider);
    final profile = await ref.read(repositoryProvider).getBusinessProfile();
    final farmers = ref.read(activeFarmersProvider).value ?? [];
    final farmer = farmers.firstWhere((f) => f.id == _selectedFarmerId);

    final success = await printer.printFarmerRecapReceipt(
      businessName: profile?.businessName ?? AppStrings.appName,
      farmerName: farmer.name,
      periodTitle: _getPeriodLabel(_farmerPeriod),
      totalTransactions: _selectedSubmissionIds.length,
      totalWeight: weight,
      totalHak: hak,
      totalPaid: _totalFarmerPaid,
      remainingBalance: sisa,
    );

    if (mounted) {
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Printer belum terhubung. Buka pengaturan printer?'),
            action: SnackBarAction(
              label: 'Pengaturan',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen())),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk rekapitulasi petani berhasil dicetak!'), backgroundColor: AppColors.primary),
        );
      }
    }
  }

  Future<void> _exportFarmerRecapPdf(double weight, double hak, double sisa) async {
    final profile = await ref.read(repositoryProvider).getBusinessProfile();
    final farmers = ref.read(activeFarmersProvider).value ?? [];
    final farmer = farmers.firstWhere((f) => f.id == _selectedFarmerId);
    final commodities = ref.read(commoditiesProvider).value ?? [];
    final commMap = {for (final c in commodities) c.id: c.name};

    final selectedSubs = _farmerSubmissions.where((s) => _selectedSubmissionIds.contains(s.id)).toList();
    final txList = selectedSubs.map((s) {
      final items = _submissionItemsMap[s.id] ?? [];
      final commNames = items.map((it) => commMap[it.commodityId] ?? 'Sayur').toSet().join(', ');
      final subHak = _submissionHakMap[s.id] ?? 0.0;
      return {
        'number': s.transactionNumber,
        'date': DateFormatter.formatDate(s.submissionDate),
        'commodity': commNames,
        'weight': WeightFormatter.format(s.totalNetWeight),
        'amount': subHak > 0 ? CurrencyFormatter.format(subHak) : '-',
        'status': s.status,
      };
    }).toList();

    final file = await PdfService.generateFarmerRecapPdf(
      businessName: profile?.businessName ?? AppStrings.appName,
      businessAddress: profile?.address,
      businessPhone: profile?.phone,
      farmerName: farmer.name,
      farmerPhone: farmer.phone,
      periodTitle: _getPeriodLabel(_farmerPeriod),
      transactions: txList,
      totalWeight: weight,
      totalHak: hak,
      totalPaid: _totalFarmerPaid,
      remainingBalance: sisa,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => await file.readAsBytes(),
      name: 'Rekap_Petani_${farmer.name}.pdf',
    );
  }

  void _shareFarmerRecap(double weight, double hak, double sisa) {
    final farmers = ref.read(activeFarmersProvider).value ?? [];
    final farmer = farmers.firstWhere((f) => f.id == _selectedFarmerId);

    final text = '''
*REKAPITULASI TRANSAKSI PETANI*
Nama: ${farmer.name}
Periode: ${_getPeriodLabel(_farmerPeriod)}
Jumlah Setoran Dipilih: ${_selectedSubmissionIds.length} nota
Total Berat Bersih: ${WeightFormatter.format(weight)}
Total Hak Petani: ${CurrencyFormatter.format(hak)}
Total Sudah Dibayar: ${CurrencyFormatter.format(_totalFarmerPaid)}
----------------------------------
*SISA KEWAJIBAN USAHA: ${CurrencyFormatter.format(sisa)}*

Dikelola via TaniFlow
''';

    ShareService.shareText(text, subject: 'Rekap Petani - ${farmer.name}');
  }

  Future<void> _printBuyerRecap(double weight, double salesAmount, double paid, double sisa) async {
    final printer = ref.read(printerServiceProvider);
    final profile = await ref.read(repositoryProvider).getBusinessProfile();
    final buyers = ref.read(activeBuyersProvider).value ?? [];
    final buyer = buyers.firstWhere((b) => b.id == _selectedBuyerId);

    final success = await printer.printBuyerRecapReceipt(
      businessName: profile?.businessName ?? AppStrings.appName,
      buyerName: buyer.name,
      periodTitle: _getPeriodLabel(_buyerPeriod),
      totalTransactions: _selectedSaleIds.length,
      totalWeight: weight,
      totalSalesAmount: salesAmount,
      totalPaid: paid,
      remainingReceivable: sisa,
    );

    if (mounted) {
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Printer belum terhubung. Buka pengaturan printer?'),
            action: SnackBarAction(
              label: 'Pengaturan',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen())),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk rekapitulasi pembeli berhasil dicetak!'), backgroundColor: AppColors.primary),
        );
      }
    }
  }

  Future<void> _exportBuyerRecapPdf(double weight, double salesAmount, double paid, double sisa) async {
    final profile = await ref.read(repositoryProvider).getBusinessProfile();
    final buyers = ref.read(activeBuyersProvider).value ?? [];
    final buyer = buyers.firstWhere((b) => b.id == _selectedBuyerId);
    final commodities = ref.read(commoditiesProvider).value ?? [];
    final commMap = {for (final c in commodities) c.id: c.name};

    final selectedSales = _buyerSales.where((s) => _selectedSaleIds.contains(s.id)).toList();
    final txList = selectedSales.map((s) {
      final items = _saleItemsMap[s.id] ?? [];
      final commNames = items.map((it) => commMap[it.commodityId] ?? 'Sayur').toSet().join(', ');
      double itemWeight = 0.0;
      for (final it in items) {
        itemWeight += it.weight;
      }
      return {
        'number': s.invoiceNumber,
        'date': DateFormatter.formatDate(s.saleDate),
        'commodity': commNames,
        'weight': WeightFormatter.format(itemWeight),
        'amount': CurrencyFormatter.format(s.totalAmount),
        'remaining': CurrencyFormatter.format(s.remainingAmount),
      };
    }).toList();

    final file = await PdfService.generateBuyerRecapPdf(
      businessName: profile?.businessName ?? AppStrings.appName,
      businessAddress: profile?.address,
      businessPhone: profile?.phone,
      buyerName: buyer.name,
      buyerPhone: buyer.phone,
      periodTitle: _getPeriodLabel(_buyerPeriod),
      transactions: txList,
      totalWeight: weight,
      totalSalesAmount: salesAmount,
      totalPaid: paid,
      remainingReceivable: sisa,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => await file.readAsBytes(),
      name: 'Rekap_Pembeli_${buyer.name}.pdf',
    );
  }

  void _shareBuyerRecap(double weight, double salesAmount, double paid, double sisa) {
    final buyers = ref.read(activeBuyersProvider).value ?? [];
    final buyer = buyers.firstWhere((b) => b.id == _selectedBuyerId);

    final text = '''
*REKAPITULASI TRANSAKSI & PIUTANG PEMBELI*
Nama: ${buyer.name}
Periode: ${_getPeriodLabel(_buyerPeriod)}
Jumlah Nota Dipilih: ${_selectedSaleIds.length} nota
Total Berat Terjual: ${WeightFormatter.format(weight)}
Total Nilai Penjualan: ${CurrencyFormatter.format(salesAmount)}
Total Sudah Diterima: ${CurrencyFormatter.format(paid)}
----------------------------------
*SISA PIUTANG BELUM LUNAS: ${CurrencyFormatter.format(sisa)}*

Dikelola via TaniFlow
''';

    ShareService.shareText(text, subject: 'Rekap Pembeli - ${buyer.name}');
  }
}
