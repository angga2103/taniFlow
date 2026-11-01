import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/business_calculator.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../providers/providers.dart';

class FarmerPricingScreen extends ConsumerStatefulWidget {
  const FarmerPricingScreen({super.key});

  @override
  ConsumerState<FarmerPricingScreen> createState() => _FarmerPricingScreenState();
}

class _FarmerPricingScreenState extends ConsumerState<FarmerPricingScreen> {
  FarmerSubmission? _selectedSubmission;
  SubmissionItem? _selectedItem;

  String _pricingMode = 'GRADING'; // 'TUNGGAL' or 'GRADING'
  String _pricingBasis = 'BERAT_SORTIR'; // 'BERAT_BERSIH_AWAL' or 'BERAT_SORTIR'

  final TextEditingController _singlePriceController = TextEditingController();
  final TextEditingController _gradeAPriceController = TextEditingController();
  final TextEditingController _gradeBPriceController = TextEditingController();
  final TextEditingController _gradeCPriceController = TextEditingController();
  final TextEditingController _damageDeductionController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  List<SubmissionItem> _submissionItems = [];
  double _calculatedPayable = 0.0;

  @override
  void initState() {
    super.initState();
    _singlePriceController.addListener(_recalculatePayable);
    _gradeAPriceController.addListener(_recalculatePayable);
    _gradeBPriceController.addListener(_recalculatePayable);
    _gradeCPriceController.addListener(_recalculatePayable);
    _damageDeductionController.addListener(_recalculatePayable);
  }

  @override
  void dispose() {
    _singlePriceController.dispose();
    _gradeAPriceController.dispose();
    _gradeBPriceController.dispose();
    _gradeCPriceController.dispose();
    _damageDeductionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _onSubmissionSelected(FarmerSubmission? sub) async {
    setState(() {
      _selectedSubmission = sub;
      _selectedItem = null;
      _submissionItems = [];
      _calculatedPayable = 0.0;
    });

    if (sub != null) {
      final repo = ref.read(repositoryProvider);
      final items = await repo.getSubmissionItems(sub.id);
      if (mounted) {
        setState(() {
          _submissionItems = items;
        });
      }
    }
  }

  void _recalculatePayable() {
    if (_selectedItem == null) return;

    final singlePrice = CurrencyFormatter.parse(_singlePriceController.text);
    final gradeA = CurrencyFormatter.parse(_gradeAPriceController.text);
    final gradeB = CurrencyFormatter.parse(_gradeBPriceController.text);
    final gradeC = CurrencyFormatter.parse(_gradeCPriceController.text);
    final damage = CurrencyFormatter.parse(_damageDeductionController.text);

    final payable = BusinessCalculator.calculateFarmerPayableAmount(
      mode: _pricingMode,
      basis: _pricingBasis,
      initialNetWeight: _selectedItem!.netWeight,
      gradeAWeight: _selectedItem!.netWeight * 0.5, // estimate or fetch grading
      gradeBWeight: _selectedItem!.netWeight * 0.35,
      gradeCWeight: _selectedItem!.netWeight * 0.15,
      singlePrice: singlePrice,
      gradeAPrice: gradeA,
      gradeBPrice: gradeB,
      gradeCPrice: gradeC,
      damageDeduction: damage,
    );

    setState(() {
      _calculatedPayable = payable;
    });
  }

  Future<void> _savePricing() async {
    if (_selectedSubmission == null || _selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih setoran dan komoditas terlebih dahulu.')),
      );
      return;
    }

    if (_calculatedPayable <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harga petani harus lebih besar dari 0.')),
      );
      return;
    }

    try {
      final repo = ref.read(repositoryProvider);
      await repo.determineFarmerPrice(
        submissionId: _selectedSubmission!.id,
        submissionItemId: _selectedItem!.id,
        farmerId: _selectedSubmission!.farmerId,
        commodityId: _selectedItem!.commodityId,
        pricingMode: _pricingMode,
        pricingBasis: _pricingBasis,
        singlePrice: CurrencyFormatter.parse(_singlePriceController.text),
        gradeAPrice: CurrencyFormatter.parse(_gradeAPriceController.text),
        gradeBPrice: CurrencyFormatter.parse(_gradeBPriceController.text),
        gradeCPrice: CurrencyFormatter.parse(_gradeCPriceController.text),
        damageDeduction: CurrencyFormatter.parse(_damageDeductionController.text),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Penentuan harga petani berhasil disimpan! Kewajiban bayar terbentuk.'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan harga petani: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final submissionsAsync = ref.watch(submissionsProvider);
    final farmersAsync = ref.watch(activeFarmersProvider);
    final commoditiesAsync = ref.watch(commoditiesProvider);

    final farmerMap = {for (final f in farmersAsync.value ?? []) f.id: f.name};
    final commMap = {for (final c in commoditiesAsync.value ?? []) c.id: c.name};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penentuan Harga Petani'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Pilih Setoran
            const Text(
              '1. Pilih Setoran Panen yang Terjual',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            submissionsAsync.when(
              data: (submissions) {
                return DropdownButtonFormField<FarmerSubmission>(
                  value: _selectedSubmission,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Transaksi Setoran',
                    prefixIcon: Icon(Icons.receipt_outlined),
                  ),
                  items: submissions.map((s) {
                    final farmerName = farmerMap[s.farmerId] ?? 'Petani';
                    return DropdownMenuItem<FarmerSubmission>(
                      value: s,
                      child: Text('${s.transactionNumber} - $farmerName (${WeightFormatter.format(s.totalNetWeight)})'),
                    );
                  }).toList(),
                  onChanged: _onSubmissionSelected,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Gagal: $err'),
            ),
            const SizedBox(height: 10),

            if (_selectedSubmission != null) ...[
              DropdownButtonFormField<SubmissionItem>(
                value: _selectedItem,
                decoration: const InputDecoration(
                  labelText: 'Pilih Komoditas yang Ditetapkan Harganya',
                  prefixIcon: Icon(Icons.eco),
                ),
                items: _submissionItems.map((item) {
                  final name = commMap[item.commodityId] ?? 'Komoditas';
                  return DropdownMenuItem<SubmissionItem>(
                    value: item,
                    child: Text('$name - Bersih: ${WeightFormatter.format(item.netWeight)}'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedItem = val;
                  });
                  _recalculatePayable();
                },
              ),
              const SizedBox(height: 16),
            ],

            // 2. Mode & Basis Penentuan Harga
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. Mode & Basis Perhitungan Hak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Mode Grading (A, B, C)')),
                          selected: _pricingMode == 'GRADING',
                          selectedColor: AppColors.primaryLight,
                          labelStyle: TextStyle(color: _pricingMode == 'GRADING' ? Colors.white : AppColors.textPrimary),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _pricingMode = 'GRADING');
                              _recalculatePayable();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Harga Tunggal')),
                          selected: _pricingMode == 'TUNGGAL',
                          selectedColor: AppColors.primaryLight,
                          labelStyle: TextStyle(color: _pricingMode == 'TUNGGAL' ? Colors.white : AppColors.textPrimary),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _pricingMode = 'TUNGGAL');
                              _recalculatePayable();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Basis: Berat Sortir')),
                          selected: _pricingBasis == 'BERAT_SORTIR',
                          selectedColor: AppColors.primaryLight,
                          labelStyle: TextStyle(color: _pricingBasis == 'BERAT_SORTIR' ? Colors.white : AppColors.textPrimary),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _pricingBasis = 'BERAT_SORTIR');
                              _recalculatePayable();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Basis: Berat Awal')),
                          selected: _pricingBasis == 'BERAT_BERSIH_AWAL',
                          selectedColor: AppColors.primaryLight,
                          labelStyle: TextStyle(color: _pricingBasis == 'BERAT_BERSIH_AWAL' ? Colors.white : AppColors.textPrimary),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _pricingBasis = 'BERAT_BERSIH_AWAL');
                              _recalculatePayable();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Input Nominal Harga Kesepakatan
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('3. Masukkan Harga Petani (Rp/kg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  if (_pricingMode == 'TUNGGAL')
                    TextField(
                      controller: _singlePriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga Tunggal per kg (Rp)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    )
                  else ...[
                    TextField(
                      controller: _gradeAPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga Grade A per kg (Rp)',
                        prefixIcon: Icon(Icons.star, color: AppColors.gradeA),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _gradeBPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga Grade B per kg (Rp)',
                        prefixIcon: Icon(Icons.star_half, color: AppColors.gradeB),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _gradeCPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga Grade C per kg (Rp)',
                        prefixIcon: Icon(Icons.star_outline, color: AppColors.gradeC),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _damageDeductionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Potongan Kerugian Sayur Rusak (Rp)',
                      prefixIcon: Icon(Icons.remove_circle_outline, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Hak Petani Bersih Display Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL HAK PETANI:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    CurrencyFormatter.format(_calculatedPayable),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Penentuan Harga (Opsional)',
                hintText: 'Kesepakatan kualitas, potongan pasar, dll.',
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _savePricing,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Tetapkan & Simpan Hak Petani'),
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
