import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../providers/providers.dart';

class FarmerPaymentScreen extends ConsumerStatefulWidget {
  final String? initialFarmerId;

  const FarmerPaymentScreen({super.key, this.initialFarmerId});

  @override
  ConsumerState<FarmerPaymentScreen> createState() => _FarmerPaymentScreenState();
}

class _FarmerPaymentScreenState extends ConsumerState<FarmerPaymentScreen> {
  String? _selectedFarmerId;

  // Submissions with details & market insights
  List<Map<String, dynamic>> _submissionsWithDetails = [];
  bool _isLoadingSubmissions = false;

  // Payment controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Price determination controllers map by submissionItemId
  final Map<String, TextEditingController> _priceControllers = {};

  double _totalHakAll = 0.0;
  double _totalPaidAll = 0.0;
  double _remainingKewajiban = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedFarmerId = widget.initialFarmerId;
    if (_selectedFarmerId != null) {
      _loadFarmerData(_selectedFarmerId!);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFarmerData(String farmerId) async {
    setState(() => _isLoadingSubmissions = true);
    final repo = ref.read(repositoryProvider);

    try {
      final details = await repo.getFarmerSubmissionsWithDetails(farmerId);
      final financialSummary = await repo.getFarmerFinancialSummary(farmerId);

      // Check unlinked payments
      final unlinkedPayments = await repo.getUnlinkedFarmerPayments(farmerId);
      double unlinkedPaid = 0.0;
      for (final p in unlinkedPayments) {
        unlinkedPaid += p.amount;
      }

      double totalHak = financialSummary['totalHak'] as double;
      double totalPaid = (financialSummary['totalPaid'] as double) + unlinkedPaid;
      double remaining = totalHak - totalPaid;

      // Initialize price controllers for items that are not yet determined
      for (final sub in details) {
        final items = sub['items'] as List<Map<String, dynamic>>;
        for (final it in items) {
          final itemId = (it['item'] as SubmissionItem).id;
          if (!_priceControllers.containsKey(itemId)) {
            final isDet = it['isDetermined'] as bool;
            final detPrice = it['singlePrice'] as double;
            final marketSummary = it['marketSummary'] as Map<String, dynamic>;
            final avgMarketPrice = marketSummary['weightedAveragePrice'] as double;

            // Default suggestion: existing determined price, or market average price
            double initialPrice = isDet ? detPrice : avgMarketPrice;
            _priceControllers[itemId] = TextEditingController(
              text: initialPrice > 0 ? initialPrice.toStringAsFixed(0) : '',
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _submissionsWithDetails = details;
          _totalHakAll = totalHak;
          _totalPaidAll = totalPaid;
          _remainingKewajiban = remaining;
          _amountController.text = remaining > 0 ? remaining.toStringAsFixed(0) : '';
          _isLoadingSubmissions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSubmissions = false);
    }
  }

  Future<void> _onFarmerSelected(String? farmerId) async {
    setState(() {
      _selectedFarmerId = farmerId;
      _submissionsWithDetails = [];
      _amountController.clear();
    });

    if (farmerId != null) {
      await _loadFarmerData(farmerId);
    }
  }

  // Tentukan Harga / Hak Petani untuk Item Tertentu
  Future<void> _saveFarmerPriceForItem({
    required String submissionId,
    required String submissionItemId,
    required String commodityId,
    required double netWeight,
  }) async {
    final priceCtrl = _priceControllers[submissionItemId];
    final pricePerKg = CurrencyFormatter.parse(priceCtrl?.text ?? '0');

    if (pricePerKg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan harga ke petani per kg yang valid (lebih dari 0).')),
      );
      return;
    }

    try {
      final repo = ref.read(repositoryProvider);
      await repo.determineFarmerPrice(
        submissionId: submissionId,
        submissionItemId: submissionItemId,
        farmerId: _selectedFarmerId!,
        commodityId: commodityId,
        pricingMode: 'TUNGGAL',
        pricingBasis: 'BERAT_BERSIH_AWAL',
        singlePrice: pricePerKg,
        notes: 'Penentuan harga via modul pembayaran',
      );

      // Invalidate relevant providers
      ref.invalidate(submissionsProvider);
      ref.invalidate(currentCashBalanceProvider);

      if (mounted) {
        final totalHakItem = netWeight * pricePerKg;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hak Petani sebesar ${CurrencyFormatter.format(totalHakItem)} berhasil disimpan!'),
            backgroundColor: AppColors.primary,
          ),
        );
        await _loadFarmerData(_selectedFarmerId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan harga: $e')),
        );
      }
    }
  }

  // Submit Pembayaran Kas Keluar
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
      final unpaids = await repo.getUnpaidFarmerPayables(_selectedFarmerId!);
      final payableId = unpaids.isNotEmpty ? unpaids.first.id : null;

      final paymentNumber = await repo.payFarmer(
        farmerId: _selectedFarmerId!,
        payableId: payableId,
        amount: amount,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      ref.invalidate(cashTransactionsProvider);
      ref.invalidate(currentCashBalanceProvider);

      final farmers = await repo.getActiveFarmers();
      final farmerName = farmers.where((f) => f.id == _selectedFarmerId).firstOrNull?.name ?? 'Petani';

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Pembayaran Kas Berhasil!'),
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
                      remainingPayable: (_remainingKewajiban - amount) > 0 ? (_remainingKewajiban - amount) : 0.0,
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
          if (mounted) _loadFarmerData(_selectedFarmerId!);
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
        title: const Text('Penyelesaian & Bayar Petani'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Pilih Petani
            const Text(
              '1. Pilih Petani Penerima Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            farmersAsync.when(
              data: (farmers) {
                return DropdownButtonFormField<String>(
                  value: _selectedFarmerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Petani',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: farmers.map((f) {
                    return DropdownMenuItem<String>(
                      value: f.id,
                      child: Text(
                        '${f.name} ${f.address != null ? "(${f.address})" : ""}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: _onFarmerSelected,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Gagal: $err'),
            ),
            const SizedBox(height: 18),

            if (_selectedFarmerId != null) ...[
              // 2. Daftar Setoran Panen & Referensi Penjualan Pasar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '2. Setoran Panen & Harga Pasar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${_submissionsWithDetails.length} Nota Setoran',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isLoadingSubmissions)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (_submissionsWithDetails.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text('Petani ini belum memiliki riwayat setoran panen.'),
                )
              else
                ..._submissionsWithDetails.map((subData) => _buildSubmissionDetailCard(subData)),

              const SizedBox(height: 20),

              // 3. Ringkasan Finansial & Kas Keluar
              _buildPaymentSummaryCard(),
            ],
          ],
        ),
      ),
    );
  }

  // Widget Card Setoran + Rincian Komoditas + Referensi Pasar
  Widget _buildSubmissionDetailCard(Map<String, dynamic> subData) {
    final sub = subData['submission'] as FarmerSubmission;
    final items = subData['items'] as List<Map<String, dynamic>>;
    final totalHakSub = subData['totalHak'] as double;
    final isFullyDetermined = subData['isFullyDetermined'] as bool;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isFullyDetermined ? AppColors.success.withValues(alpha: 0.5) : AppColors.warning,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Nota
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      sub.transactionNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  DateFormatter.formatDate(sub.submissionDate),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Berat: ${WeightFormatter.format(sub.totalNetWeight)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFullyDetermined ? AppColors.successLight : AppColors.warningLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isFullyDetermined ? 'Hak: ${CurrencyFormatter.format(totalHakSub)}' : 'Belum Ditentukan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isFullyDetermined ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Rincian per Komoditas Sayuran
            ...items.map((itData) => _buildItemPricingSection(sub.id, itData)),
          ],
        ),
      ),
    );
  }

  // Widget Bagian Komoditas & Live Market Insight
  Widget _buildItemPricingSection(String submissionId, Map<String, dynamic> itData) {
    final it = itData['item'] as SubmissionItem;
    final commodityName = itData['commodityName'] as String;
    final netWeight = itData['netWeight'] as double;
    final isDetermined = itData['isDetermined'] as bool;
    final detAmount = itData['netFarmerAmount'] as double;
    final detPrice = itData['singlePrice'] as double;
    final marketSummary = itData['marketSummary'] as Map<String, dynamic>;

    final hasSales = marketSummary['hasSales'] as bool;
    final avgMarketPrice = marketSummary['weightedAveragePrice'] as double;
    final totalSoldWeight = marketSummary['totalSoldWeight'] as double;
    final totalRevenue = marketSummary['totalRevenue'] as double;
    final isMultiplePrices = marketSummary['isMultiplePrices'] as bool? ?? false;
    final salesCount = marketSummary['salesCount'] as int? ?? 0;
    final minPrice = marketSummary['minPrice'] as double? ?? 0.0;
    final maxPrice = marketSummary['maxPrice'] as double? ?? 0.0;
    final salesBreakdown = marketSummary['salesBreakdown'] as List<Map<String, dynamic>>? ?? [];

    final priceCtrl = _priceControllers[it.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '• $commodityName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
              Text(
                WeightFormatter.format(netWeight),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Wawasan Penjualan Pasar Aktual (Live Market Insight)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasSales ? AppColors.primaryLighter : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hasSales ? AppColors.primaryLight : Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasSales ? Icons.insights : Icons.store_outlined,
                      size: 16,
                      color: hasSales ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasSales ? 'Data Penjualan Pasar Terkait:' : 'Belum Ada Penjualan Pasar:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: hasSales ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (hasSales) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Terjual: ${WeightFormatter.format(totalSoldWeight)} | Omzet: ${CurrencyFormatter.format(totalRevenue)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Harga Jual Rata-Rata Pasar:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${CurrencyFormatter.format(avgMarketPrice)} / kg',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                  if (isMultiplePrices) ...[
                    const SizedBox(height: 2),
                    Text(
                      '★ Dihitung otomatis dari $salesCount nota pasar (rentang: ${CurrencyFormatter.format(minPrice)} - ${CurrencyFormatter.format(maxPrice)}/kg)',
                      style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                    ),
                  ],
                  if (salesBreakdown.isNotEmpty)
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Lihat rincian transaksi pembeli pasar',
                          style: TextStyle(fontSize: 11, color: AppColors.primary, decoration: TextDecoration.underline),
                        ),
                        children: salesBreakdown.map((sb) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${sb['invoiceNumber']} (${sb['buyerName']})', style: const TextStyle(fontSize: 10.5)),
                                Text(
                                  '${WeightFormatter.format(sb['weight'] as double)} @ ${CurrencyFormatter.format(sb['pricePerKg'] as double)}',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ] else ...[
                  const Text(
                    'Belum ada nota penjualan pasar untuk komoditas ini. Silakan tentukan harga beli kesepakatan manual.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Status & Form Input Harga ke Petani
          if (isDetermined) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Harga Beli Kesepakatan:', style: TextStyle(fontSize: 11)),
                Text(
                  '${CurrencyFormatter.format(detPrice)} / kg',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Hak Petani Tersimpan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text(
                  CurrencyFormatter.format(detAmount),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                ),
              ],
            ),
          ] else ...[
            // Tombol Cepat Menetapkan Harga
            if (hasSales && avgMarketPrice > 0) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: Text('Sama Pasar (${CurrencyFormatter.format(avgMarketPrice)})', style: const TextStyle(fontSize: 10.5)),
                    onPressed: () {
                      priceCtrl?.text = avgMarketPrice.toStringAsFixed(0);
                      setState(() {});
                    },
                  ),
                  if (avgMarketPrice > 500)
                    ActionChip(
                      label: Text('Pasar - Rp 500 (${CurrencyFormatter.format(avgMarketPrice - 500)})', style: const TextStyle(fontSize: 10.5)),
                      onPressed: () {
                        priceCtrl?.text = (avgMarketPrice - 500).toStringAsFixed(0);
                        setState(() {});
                      },
                    ),
                  if (avgMarketPrice > 1000)
                    ActionChip(
                      label: Text('Pasar - Rp 1.000 (${CurrencyFormatter.format(avgMarketPrice - 1000)})', style: const TextStyle(fontSize: 10.5)),
                      onPressed: () {
                        priceCtrl?.text = (avgMarketPrice - 1000).toStringAsFixed(0);
                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Harga ke Petani (Rp/kg)',
                      hintText: 'Misal: 5000',
                      isDense: true,
                      prefixText: 'Rp ',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _saveFarmerPriceForItem(
                      submissionId: submissionId,
                      submissionItemId: it.id,
                      commodityId: it.commodityId,
                      netWeight: netWeight,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                    child: const Text('Simpan Hak', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Kalkulasi Hak Real-Time
            Builder(builder: (_) {
              final typedPrice = CurrencyFormatter.parse(priceCtrl?.text ?? '0');
              final totalHakPreview = netWeight * typedPrice;
              final estMargin = hasSales ? ((avgMarketPrice - typedPrice) * netWeight) : 0.0;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Hak: ${CurrencyFormatter.format(totalHakPreview)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  if (hasSales && typedPrice > 0)
                    Text(
                      'Estimasi Margin Usaha: ${CurrencyFormatter.format(estMargin)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: estMargin >= 0 ? AppColors.success : AppColors.danger,
                      ),
                    ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  // Card Ringkasan Finansial Petani & Pembayaran Kas Keluar
  Widget _buildPaymentSummaryCard() {
    final isLunas = _remainingKewajiban <= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3. Ringkasan Finansial & Kas Keluar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Hak Petani (Kewajiban):', style: TextStyle(fontSize: 12.5)),
              Text(CurrencyFormatter.format(_totalHakAll), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Pembayaran Tercatat:', style: TextStyle(fontSize: 12.5)),
              Text(
                CurrencyFormatter.format(_totalPaidAll),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primary),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SISA KEWAJIBAN USAHA:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                CurrencyFormatter.format(_remainingKewajiban),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: isLunas ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isLunas)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seluruh kewajiban hak petani ini telah lunas tercatat.',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah Uang Dibayarkan (Rp)',
                prefixText: 'Rp ',
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Keterangan Pembayaran (Opsional)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submitPayment,
                icon: const Icon(Icons.payments),
                label: const Text('Bayarkan Uang Tunai ke Petani', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
