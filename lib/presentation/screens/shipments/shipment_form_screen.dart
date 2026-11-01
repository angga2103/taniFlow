import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../providers/providers.dart';

class ShipmentFormScreen extends ConsumerStatefulWidget {
  const ShipmentFormScreen({super.key});

  @override
  ConsumerState<ShipmentFormScreen> createState() => _ShipmentFormScreenState();
}

class _ShipmentFormScreenState extends ConsumerState<ShipmentFormScreen> {
  final TextEditingController _destinationController = TextEditingController(text: 'Pasar Induk Kramat Jati');
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, dynamic>> _items = [];

  String? _selectedCommodityId;
  String _selectedGrade = 'Grade A';
  final TextEditingController _weightController = TextEditingController();

  @override
  void dispose() {
    _destinationController.dispose();
    _driverController.dispose();
    _vehicleController.dispose();
    _notesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _addItem() {
    if (_selectedCommodityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih komoditas terlebih dahulu.')),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0.0;
    if (weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berat kirim harus lebih besar dari 0 kg.')),
      );
      return;
    }

    final commodities = ref.read(commoditiesProvider).value ?? [];
    final comm = commodities.firstWhere((c) => c.id == _selectedCommodityId);

    setState(() {
      _items.add({
        'commodityId': _selectedCommodityId!,
        'commodityName': comm.name,
        'grade': _selectedGrade,
        'totalWeight': weight,
        'allocations': <Map<String, dynamic>>[], // Can auto-allocate or link to graded items
      });

      _weightController.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
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
            Text('Tambah Jenis Sayur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                final newId = await repo.addCommodity(name: name);
                ref.invalidate(commoditiesProvider);
                setState(() {
                  _selectedCommodityId = newId;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sayuran "$name" berhasil ditambahkan dan dipilih!'),
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

  Future<void> _saveShipment() async {
    if (_destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tujuan pasar wajib diisi.')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 komoditas dalam muatan pengiriman.')),
      );
      return;
    }

    try {
      final repo = ref.read(repositoryProvider);
      final shipmentNumber = await repo.createShipment(
        destinationMarket: _destinationController.text.trim(),
        driverName: _driverController.text.trim().isEmpty ? null : _driverController.text.trim(),
        vehicleNumber: _vehicleController.text.trim().isEmpty ? null : _vehicleController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        items: _items,
      );

      ref.invalidate(shipmentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pengiriman $shipmentNumber berhasil dibuat!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat pengiriman: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commoditiesAsync = ref.watch(commoditiesProvider);

    double totalMuatan = 0.0;
    for (final it in _items) {
      totalMuatan += (it['totalWeight'] as num).toDouble();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Pengiriman Pasar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Data Pengiriman / Logistik
            const Text(
              '1. Data Tujuan & Armada Pengiriman',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Pasar Tujuan / Pembeli',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _driverController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Sopir (Opsional)',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _vehicleController,
                    decoration: const InputDecoration(
                      labelText: 'Plat Nomor Truk / Pikap',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Tambah Muatan Komoditas
            Container(
              padding: const EdgeInsets.all(14),
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
                        '2. Muatan Sayur yang Dikirim',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                      ),
                      TextButton.icon(
                        onPressed: _showQuickAddCommodityDialog,
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('+ Sayuran Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  commoditiesAsync.when(
                    data: (commodities) {
                      return DropdownButtonFormField<String>(
                        value: _selectedCommodityId,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Komoditas',
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
                            _selectedCommodityId = val;
                          });
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Gagal memuat: $err'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGrade,
                          decoration: const InputDecoration(
                            labelText: 'Grade / Mutu',
                            prefixIcon: Icon(Icons.grade),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Grade A', child: Text('Grade A (Super)')),
                            DropdownMenuItem(value: 'Grade B', child: Text('Grade B (Sedang)')),
                            DropdownMenuItem(value: 'Grade C', child: Text('Grade C (Kecil)')),
                            DropdownMenuItem(value: 'Campur', child: Text('Harga Tunggal / Campur')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedGrade = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Berat Muat (kg)',
                            prefixIcon: Icon(Icons.scale),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Masukkan ke Daftar Pengiriman'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Rincian Muatan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '3. Rincian Muatan Truk',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Total: ${WeightFormatter.format(totalMuatan)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'Belum ada muatan yang dimasukkan ke pengiriman.',
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
                        '${it['commodityName']} (${it['grade']})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            WeightFormatter.format(it['totalWeight'] as double),
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
            const SizedBox(height: 14),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Pengiriman (Opsional)',
                hintText: 'Titipan pesanan pasar, instruksi khusus, dll.',
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _saveShipment,
              icon: const Icon(Icons.local_shipping),
              label: const Text('Simpan & Berangkatkan Pengiriman'),
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
