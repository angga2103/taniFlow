import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/business_calculator.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../providers/providers.dart';

class GradingFormScreen extends ConsumerStatefulWidget {
  final SubmissionItem item;
  final String farmerName;
  final String commodityName;
  final double defaultTolerancePercent;

  const GradingFormScreen({
    super.key,
    required this.item,
    required this.farmerName,
    required this.commodityName,
    required this.defaultTolerancePercent,
  });

  @override
  ConsumerState<GradingFormScreen> createState() => _GradingFormScreenState();
}

class _GradingFormScreenState extends ConsumerState<GradingFormScreen> {
  String _pricingMode = 'GRADING'; // 'TUNGGAL' or 'GRADING'

  final TextEditingController _gradeAController = TextEditingController(text: '0');
  final TextEditingController _gradeBController = TextEditingController(text: '0');
  final TextEditingController _gradeCController = TextEditingController(text: '0');
  final TextEditingController _damagedController = TextEditingController(text: '0');
  final TextEditingController _toleranceController = TextEditingController();
  final TextEditingController _diffReasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  GradingReconciliationResult? _recon;

  @override
  void initState() {
    super.initState();
    _toleranceController.text = widget.defaultTolerancePercent.toStringAsFixed(1);
    _gradeAController.addListener(_recalculate);
    _gradeBController.addListener(_recalculate);
    _gradeCController.addListener(_recalculate);
    _damagedController.addListener(_recalculate);
    _toleranceController.addListener(_recalculate);
    _recalculate();
  }

  @override
  void dispose() {
    _gradeAController.dispose();
    _gradeBController.dispose();
    _gradeCController.dispose();
    _damagedController.dispose();
    _toleranceController.dispose();
    _diffReasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final gradeA = double.tryParse(_gradeAController.text.replaceAll(',', '.')) ?? 0.0;
    final gradeB = double.tryParse(_gradeBController.text.replaceAll(',', '.')) ?? 0.0;
    final gradeC = double.tryParse(_gradeCController.text.replaceAll(',', '.')) ?? 0.0;
    final damaged = double.tryParse(_damagedController.text.replaceAll(',', '.')) ?? 0.0;
    final tol = double.tryParse(_toleranceController.text.replaceAll(',', '.')) ?? widget.defaultTolerancePercent;

    setState(() {
      _recon = BusinessCalculator.reconcileGrading(
        incomingNetWeight: widget.item.netWeight,
        gradeAWeight: gradeA,
        gradeBWeight: gradeB,
        gradeCWeight: gradeC,
        damagedWeight: damaged,
        tolerancePercent: tol,
      );
    });
  }

  Future<void> _submitGrading() async {
    if (_recon == null) return;

    if (_recon!.isExceedingTolerance && _diffReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selisih berat melebihi batas toleransi! Anda wajib mengisi alasan penjelasan selisih.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final gradeA = double.tryParse(_gradeAController.text.replaceAll(',', '.')) ?? 0.0;
    final gradeB = double.tryParse(_gradeBController.text.replaceAll(',', '.')) ?? 0.0;
    final gradeC = double.tryParse(_gradeCController.text.replaceAll(',', '.')) ?? 0.0;
    final damaged = double.tryParse(_damagedController.text.replaceAll(',', '.')) ?? 0.0;
    final tol = double.tryParse(_toleranceController.text.replaceAll(',', '.')) ?? widget.defaultTolerancePercent;

    try {
      final repo = ref.read(repositoryProvider);
      await repo.submitGrading(
        submissionItemId: widget.item.id,
        pricingMode: _pricingMode,
        gradeAWeight: gradeA,
        gradeBWeight: gradeB,
        gradeCWeight: gradeC,
        damagedWeight: damaged,
        tolerancePercent: tol,
        diffReason: _diffReasonController.text.trim().isEmpty ? null : _diffReasonController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      ref.invalidate(pendingGradingItemsProvider);
      ref.invalidate(submissionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sortir dan grading berhasil disimpan!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan hasil sortir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recon = _recon;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sortir & Grading Panen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Setoran Masuk
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.commodityName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text('Petani: ${widget.farmerName}', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Berat Bersih Masuk:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        WeightFormatter.format(widget.item.netWeight),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pilihan Mode Penentuan Harga
            const Text(
              'Mode Penentuan Kualitas & Harga',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Mode Grading (A, B, C)')),
                    selected: _pricingMode == 'GRADING',
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(color: _pricingMode == 'GRADING' ? Colors.white : AppColors.textPrimary),
                    onSelected: (selected) {
                      if (selected) setState(() => _pricingMode = 'GRADING');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Mode Harga Tunggal')),
                    selected: _pricingMode == 'TUNGGAL',
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(color: _pricingMode == 'TUNGGAL' ? Colors.white : AppColors.textPrimary),
                    onSelected: (selected) {
                      if (selected) setState(() => _pricingMode = 'TUNGGAL');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Form Input Berat per Grade
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
                  const Text(
                    'Input Bobot Hasil Sortir (kg)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _gradeAController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Grade A (Super/Bagus)',
                            prefixIcon: Icon(Icons.star, color: AppColors.gradeA),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _gradeBController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Grade B (Sedang)',
                            prefixIcon: Icon(Icons.star_half, color: AppColors.gradeB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _gradeCController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Grade C (Kecil/Campur)',
                            prefixIcon: Icon(Icons.star_outline, color: AppColors.gradeC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _damagedController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Rusak / Afkir / Buang',
                            prefixIcon: Icon(Icons.delete_outline, color: AppColors.danger),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _toleranceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Batas Toleransi Selisih (%)',
                      prefixIcon: Icon(Icons.tune),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // REKONSILIASI BERAT
            if (recon != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: recon.isExceedingTolerance ? AppColors.dangerLight : AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: recon.isExceedingTolerance ? AppColors.danger : AppColors.primary,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Rekonsiliasi Berat Sortir:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          '${recon.diffPercentage.toStringAsFixed(1)}% Selisih',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: recon.isExceedingTolerance ? AppColors.danger : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Berat Masuk: ${WeightFormatter.format(recon.incomingNetWeight)} = Hasil Sortir: ${WeightFormatter.format(recon.explainedWeight)} + Selisih: ${WeightFormatter.format(recon.unexplainedDiffWeight)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (recon.isExceedingTolerance) ...[
                      const Divider(height: 16),
                      Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Peringatan: Selisih berat melebihi batas toleransi! Wajib masukkan alasan penjelasan di bawah ini.',
                              style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _diffReasonController,
                        decoration: const InputDecoration(
                          labelText: 'Alasan Selisih Bobot (Wajib Diisi)',
                          hintText: 'Penyusutan kadar air tinggi, kotoran tanah rontok, dll.',
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Sortir (Opsional)',
                hintText: 'Kualitas komoditas, kemasan yang digunakan, dll.',
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _submitGrading,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Simpan Hasil Sortir & Grading'),
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
