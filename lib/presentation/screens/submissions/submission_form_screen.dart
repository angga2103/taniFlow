import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/business_calculator.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../providers/providers.dart';
import 'submission_detail_screen.dart';

class SubmissionFormScreen extends ConsumerStatefulWidget {
  const SubmissionFormScreen({super.key});

  @override
  ConsumerState<SubmissionFormScreen> createState() => _SubmissionFormScreenState();
}

class _SubmissionFormScreenState extends ConsumerState<SubmissionFormScreen> {
  String? _selectedFarmerId;
  final TextEditingController _notesController = TextEditingController();

  // Multi-item submission list
  final List<Map<String, dynamic>> _items = [];

  // Current item inputs
  String? _currentCommodityId;
  final TextEditingController _grossController = TextEditingController();
  final TextEditingController _tareController = TextEditingController();
  double _currentNet = 0.0;

  @override
  void initState() {
    super.initState();
    _grossController.addListener(_calculateCurrentNet);
    _tareController.addListener(_calculateCurrentNet);
  }

  @override
  void dispose() {
    _grossController.dispose();
    _tareController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateCurrentNet() {
    final gross = double.tryParse(_grossController.text.replaceAll(',', '.')) ?? 0.0;
    final tare = double.tryParse(_tareController.text.replaceAll(',', '.')) ?? 0.0;
    setState(() {
      _currentNet = BusinessCalculator.calculateNetWeight(gross, tare);
    });
  }

  Future<void> _showQuickAddFarmerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Tambah Petani Cepat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Petani *',
                  hintText: 'Contoh: Pak Slamet',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon (Opsional)',
                  hintText: '0812xxxx',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Alamat / Desa (Opsional)',
                  hintText: 'Contoh: Desa Cikajang',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama petani wajib diisi.')),
                );
                return;
              }
              Navigator.pop(dialogCtx);
              try {
                final repo = ref.read(repositoryProvider);
                final newId = await repo.addFarmer(
                  name: name,
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                );
                ref.invalidate(activeFarmersProvider);
                setState(() {
                  _selectedFarmerId = newId;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Petani "$name" berhasil disimpan dan dipilih!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menyimpan petani: $e')),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickAddCommodityDialog() async {
    final nameCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.eco, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Tambah Jenis Sayur Cepat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Sayuran / Komoditas *',
                hintText: 'Contoh: Buncis, Kol, Tomat',
                prefixIcon: Icon(Icons.eco_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama sayuran wajib diisi.')),
                );
                return;
              }
              Navigator.pop(dialogCtx);
              try {
                final repo = ref.read(repositoryProvider);
                final newId = await repo.addCommodity(
                  name: name,
                );
                ref.invalidate(commoditiesProvider);
                setState(() {
                  _currentCommodityId = newId;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sayuran "$name" berhasil disimpan dan dipilih!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menyimpan sayuran: $e')),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    if (_currentCommodityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih komoditas terlebih dahulu.')),
      );
      return;
    }

    final gross = double.tryParse(_grossController.text.replaceAll(',', '.')) ?? 0.0;
    final tare = double.tryParse(_tareController.text.replaceAll(',', '.')) ?? 0.0;

    if (gross <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berat kotor harus lebih besar dari 0.')),
      );
      return;
    }

    if (gross < tare) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berat kotor tidak boleh lebih kecil dari tara.')),
      );
      return;
    }

    final commodities = ref.read(commoditiesProvider).value ?? [];
    final comm = commodities.firstWhere((c) => c.id == _currentCommodityId);

    setState(() {
      _items.add({
        'commodityId': _currentCommodityId!,
        'commodityName': comm.name,
        'grossWeight': gross,
        'tareWeight': tare,
        'netWeight': _currentNet,
      });

      // Reset item inputs for next item
      _currentCommodityId = null;
      _grossController.clear();
      _tareController.clear();
      _currentNet = 0.0;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _saveSubmission() async {
    if (_selectedFarmerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih petani penyetor terlebih dahulu.')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 item hasil panen yang ditimbang.')),
      );
      return;
    }

    try {
      final repo = ref.read(repositoryProvider);
      final transactionNumber = await repo.createSubmission(
        farmerId: _selectedFarmerId!,
        items: _items,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        // Refresh streams
        ref.invalidate(submissionsProvider);
        ref.invalidate(pendingGradingItemsProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setoran $transactionNumber berhasil disimpan!'),
            backgroundColor: AppColors.primary,
          ),
        );

        // Fetch saved submission and navigate to detail / proof
        final submissions = await repo.watchSubmissions().first;
        final savedSub = submissions.firstWhere((s) => s.transactionNumber == transactionNumber);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SubmissionDetailScreen(submission: savedSub),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan setoran: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmersAsync = ref.watch(activeFarmersProvider);
    final commoditiesAsync = ref.watch(commoditiesProvider);

    double totalNet = 0.0;
    for (final it in _items) {
      totalNet += it['netWeight'] as double;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penerimaan Setoran Panen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Pilih Petani
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '1. Identitas Petani Penyetor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
                TextButton.icon(
                  onPressed: _showQuickAddFarmerDialog,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('+ Petani Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            farmersAsync.when(
              data: (farmers) {
                return DropdownButtonFormField<String>(
                  value: _selectedFarmerId,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Petani',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: farmers.map((f) {
                    return DropdownMenuItem<String>(
                      value: f.id,
                      child: Text('${f.name} ${f.address != null ? "(${f.address})" : ""}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedFarmerId = val;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Gagal memuat petani: $err'),
            ),
            const SizedBox(height: 20),

            // 2. Input Timbangan Komoditas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryLight, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '2. Form Timbangan (Input Cepat)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                      ),
                      TextButton.icon(
                        onPressed: _showQuickAddCommodityDialog,
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('+ Sayuran Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  commoditiesAsync.when(
                    data: (commodities) {
                      return DropdownButtonFormField<String>(
                        value: _currentCommodityId,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Komoditas Sayur',
                          prefixIcon: Icon(Icons.eco),
                        ),
                        items: commodities.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(c.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _currentCommodityId = val;
                          });
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Gagal memuat komoditas: $err'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _grossController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Berat Kotor (kg)',
                            hintText: '0.00',
                            prefixIcon: Icon(Icons.scale),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _tareController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Tara / Wadah (kg)',
                            hintText: '0.00',
                            prefixIcon: Icon(Icons.shopping_bag_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Display Live Computed Net Weight
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLighter,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Berat Bersih Dihitung:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          WeightFormatter.format(_currentNet),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambahkan Komoditas ke Timbangan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Daftar Komoditas yang Ditimbang
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '3. Rincian Komoditas Masuk',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
                Text(
                  '${_items.length} Item',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'Belum ada komoditas yang ditambahkan.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final it = _items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        it['commodityName'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Kotor: ${WeightFormatter.format(it['grossWeight'] as double)} | Tara: ${WeightFormatter.format(it['tareWeight'] as double)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            WeightFormatter.format(it['netWeight'] as double),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),

            // Catatan
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Setoran (Opsional)',
                hintText: 'Kondisi sayur, cuaca saat panen, dll.',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Disclaimer & Total Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL BERAT BERSIH:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        WeightFormatter.format(totalNet),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  const Text(
                    '⚠️ ${AppStrings.submissionNote}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tombol Simpan
            ElevatedButton.icon(
              onPressed: _saveSubmission,
              icon: const Icon(Icons.save),
              label: const Text('Simpan Transaksi Setoran'),
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
