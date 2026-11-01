import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/database/app_database.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';

class CommoditiesScreen extends ConsumerStatefulWidget {
  const CommoditiesScreen({super.key});

  @override
  ConsumerState<CommoditiesScreen> createState() => _CommoditiesScreenState();
}

class _CommoditiesScreenState extends ConsumerState<CommoditiesScreen> {
  void _showAddEditCommodityDialog([Commodity? commodity]) {
    final nameController = TextEditingController(text: commodity?.name ?? '');
    final tolController = TextEditingController(
      text: (commodity?.defaultLossTolerancePercent ?? 2.0).toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(commodity == null ? 'Tambah Komoditas Sayur' : 'Edit Komoditas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Komoditas Sayur *',
                  hintText: 'Contoh: Cabai Rawit, Tomat Buah',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tolController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Toleransi Susut Sortir (%) *',
                  hintText: '2.0',
                  suffixText: '%',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final tol = double.tryParse(tolController.text.replaceAll(',', '.')) ?? 2.0;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama komoditas wajib diisi.')),
                  );
                  return;
                }

                final repo = ref.read(repositoryProvider);
                await repo.addCommodity(name: name, defaultLossTolerancePercent: tol);

                ref.invalidate(commoditiesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final commoditiesAsync = ref.watch(commoditiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog Komoditas Sayur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Komoditas',
            onPressed: () => _showAddEditCommodityDialog(),
          ),
        ],
      ),
      body: commoditiesAsync.when(
        data: (commodities) {
          if (commodities.isEmpty) {
            return EmptyState(
              icon: Icons.eco_outlined,
              title: 'Belum Ada Komoditas',
              message: 'Tambahkan jenis sayuran yang diperdagangkan ke dalam sistem.',
              buttonText: 'Tambah Komoditas',
              onButtonPressed: () => _showAddEditCommodityDialog(),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: commodities.length,
            itemBuilder: (context, index) {
              final c = commodities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLighter,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.eco, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    c.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Toleransi Susut: ${c.defaultLossTolerancePercent.toStringAsFixed(1)}%  |  Satuan Dasar: kg',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Aktif',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditCommodityDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
