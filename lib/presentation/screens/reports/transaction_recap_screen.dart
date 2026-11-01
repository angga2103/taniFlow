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
          tabs: const [
            Tab(icon: Icon(Icons.agriculture), text: 'Rekap Petani'),
            Tab(icon: Icon(Icons.storefront), text: 'Rekap Pembeli'),
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
            children: [
              farmersAsync.when(
                data: (farmers) {
                  return DropdownButtonFormField<String>(
                    value: _selectedFarmerId,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Petani Penyetor',
                      prefixIcon: Icon(Icons.person, color: AppColors.primary),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: farmers.map((f) {
                      return DropdownMenuItem<String>(
                        value: f.id,
                        child: Text('${f.name} ${f.address != null ? "(${f.address})" : ""}'),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Periode: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
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
            ],
          ),
        ),

        // Select All row
        if (_farmerSubmissions.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _selectedSubmissionIds.length == _farmerSubmissions.length &&
                          _farmerSubmissions.isNotEmpty,
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
                    Text(
                      'Pilih Semua (${_selectedSubmissionIds.length}/${_farmerSubmissions.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${_farmerSubmissions.length} Transaksi',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                      Icon(Icons.person_search_outlined, size: 48, color: AppColors.textSecondary),
                      SizedBox(height: 8),
                      Text('Silakan pilih petani di atas untuk melihat rekapitulasi.', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : _isLoadingFarmer
                  ? const Center(child: CircularProgressIndicator())
                  : _farmerSubmissions.isEmpty
                      ? const Center(child: Text('Tidak ada riwayat setoran pada periode ini.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          itemCount: _farmerSubmissions.length,
                          itemBuilder: (ctx, i) {
                            final sub = _farmerSubmissions[i];
                            final isChecked = _selectedSubmissionIds.contains(sub.id);
                            final items = _submissionItemsMap[sub.id] ?? [];
                            final hak = _submissionHakMap[sub.id] ?? 0.0;

                            final commSummary = items.map((it) {
                              final name = commMap[it.commodityId] ?? 'Sayur';
                              return '$name (${WeightFormatter.format(it.netWeight)})';
                            }).join(', ');

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isChecked ? AppColors.primary : Colors.grey.shade300,
                                  width: isChecked ? 1.4 : 0.8,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: isChecked,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedSubmissionIds.add(sub.id);
                                    } else {
                                      _selectedSubmissionIds.remove(sub.id);
                                    }
                                  });
                                },
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(sub.transactionNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(DateFormatter.formatDateTime(sub.submissionDate), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      commSummary.isNotEmpty ? commSummary : 'Belum ada rincian',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Netto: ${WeightFormatter.format(sub.totalNetWeight)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                        Text(
                                          hak > 0 ? 'Hak: ${CurrencyFormatter.format(hak)}' : 'Belum Ditentukan',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: hak > 0 ? AppColors.success : AppColors.warning,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                    Text('Total Berat (${_selectedSubmissionIds.length} nota):', style: const TextStyle(fontSize: 12)),
                    Text(WeightFormatter.format(selectedWeight), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Hak Petani:', style: TextStyle(fontSize: 12)),
                    Text(CurrencyFormatter.format(selectedHak), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pembayaran Tercatat:', style: TextStyle(fontSize: 12)),
                    Text(CurrencyFormatter.format(_totalFarmerPaid), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SISA KEWAJIBAN USAHA:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      CurrencyFormatter.format(remainingKewajiban),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: remainingKewajiban > 0 ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectedSubmissionIds.isEmpty
                            ? null
                            : () => _printFarmerRecap(selectedWeight, selectedHak, remainingKewajiban),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Cetak Struk', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedSubmissionIds.isEmpty
                            ? null
                            : () => _exportFarmerRecapPdf(selectedWeight, selectedHak, remainingKewajiban),
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('Export PDF', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.share, color: AppColors.primary),
                      onPressed: _selectedSubmissionIds.isEmpty
                          ? null
                          : () => _shareFarmerRecap(selectedWeight, selectedHak, remainingKewajiban),
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
            children: [
              buyersAsync.when(
                data: (buyers) {
                  return DropdownButtonFormField<String>(
                    value: _selectedBuyerId,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Pembeli / Pelanggan',
                      prefixIcon: Icon(Icons.storefront, color: AppColors.primary),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: buyers.map((b) {
                      return DropdownMenuItem<String>(
                        value: b.id,
                        child: Text('${b.name} ${b.phone != null ? "(${b.phone})" : ""}'),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Periode: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
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
            ],
          ),
        ),

        // Select All row
        if (_buyerSales.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _selectedSaleIds.length == _buyerSales.length && _buyerSales.isNotEmpty,
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
                    Text(
                      'Pilih Semua (${_selectedSaleIds.length}/${_buyerSales.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${_buyerSales.length} Nota Penjualan',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                      Icon(Icons.person_search_outlined, size: 48, color: AppColors.textSecondary),
                      SizedBox(height: 8),
                      Text('Silakan pilih pembeli di atas untuk melihat rekapitulasi.', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : _isLoadingBuyer
                  ? const Center(child: CircularProgressIndicator())
                  : _buyerSales.isEmpty
                      ? const Center(child: Text('Tidak ada riwayat penjualan pada periode ini.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          itemCount: _buyerSales.length,
                          itemBuilder: (ctx, i) {
                            final sale = _buyerSales[i];
                            final isChecked = _selectedSaleIds.contains(sale.id);
                            final items = _saleItemsMap[sale.id] ?? [];

                            final commSummary = items.map((it) {
                              final name = commMap[it.commodityId] ?? 'Sayur';
                              return '$name ${it.grade} (${WeightFormatter.format(it.weight)} @ ${CurrencyFormatter.format(it.pricePerKg)})';
                            }).join(', ');

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isChecked ? AppColors.primary : Colors.grey.shade300,
                                  width: isChecked ? 1.4 : 0.8,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: isChecked,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedSaleIds.add(sale.id);
                                    } else {
                                      _selectedSaleIds.remove(sale.id);
                                    }
                                  });
                                },
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(sale.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(DateFormatter.formatDateTime(sale.saleDate), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      commSummary.isNotEmpty ? commSummary : 'Muatan Terjual',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Total: ${CurrencyFormatter.format(sale.totalAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
                                        Text(
                                          sale.remainingAmount <= 0
                                              ? 'LUNAS'
                                              : 'Sisa: ${CurrencyFormatter.format(sale.remainingAmount)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: sale.remainingAmount <= 0 ? AppColors.success : AppColors.danger,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                    Text('Total Berat Terjual (${_selectedSaleIds.length} nota):', style: const TextStyle(fontSize: 12)),
                    Text(WeightFormatter.format(selectedWeight), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Nilai Penjualan:', style: TextStyle(fontSize: 12)),
                    Text(CurrencyFormatter.format(selectedSalesAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Sudah Diterima:', style: TextStyle(fontSize: 12)),
                    Text(CurrencyFormatter.format(totalDiterima), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SISA PIUTANG PEMBELI:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      CurrencyFormatter.format(selectedRemainingReceivable),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: selectedRemainingReceivable > 0 ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectedSaleIds.isEmpty
                            ? null
                            : () => _printBuyerRecap(selectedWeight, selectedSalesAmount, totalDiterima, selectedRemainingReceivable),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Cetak Struk', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedSaleIds.isEmpty
                            ? null
                            : () => _exportBuyerRecapPdf(selectedWeight, selectedSalesAmount, totalDiterima, selectedRemainingReceivable),
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('Export PDF', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.share, color: AppColors.primary),
                      onPressed: _selectedSaleIds.isEmpty
                          ? null
                          : () => _shareBuyerRecap(selectedWeight, selectedSalesAmount, totalDiterima, selectedRemainingReceivable),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPeriodChip(String id, String label, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == id;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.textPrimary)),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.grey.shade200,
        padding: const EdgeInsets.symmetric(horizontal: 6),
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
