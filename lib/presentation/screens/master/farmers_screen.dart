import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';

class FarmersScreen extends ConsumerStatefulWidget {
  const FarmersScreen({super.key});

  @override
  ConsumerState<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends ConsumerState<FarmersScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditFarmerDialog([Farmer? farmer]) {
    final nameController = TextEditingController(text: farmer?.name ?? '');
    final phoneController = TextEditingController(text: farmer?.phone ?? '');
    final addressController = TextEditingController(text: farmer?.address ?? '');
    final notesController = TextEditingController(text: farmer?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(farmer == null ? 'Tambah Petani Baru' : 'Edit Data Petani'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap Petani *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Nomor Telepon / WA'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Alamat / Desa / Blok'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Catatan Petani'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama petani wajib diisi.')),
                  );
                  return;
                }

                final repo = ref.read(repositoryProvider);
                if (farmer == null) {
                  await repo.addFarmer(
                    name: name,
                    phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                } else {
                  await repo.updateFarmer(
                    id: farmer.id,
                    name: name,
                    phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                }

                ref.invalidate(activeFarmersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showFarmerDetailModal(Farmer farmer) async {
    final repo = ref.read(repositoryProvider);
    final summary = await repo.getFarmerFinancialSummary(farmer.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    farmer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddEditFarmerDialog(farmer);
                    },
                  ),
                ],
              ),
              if (farmer.phone != null) ...[
                Text('Telp: ${farmer.phone}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
              if (farmer.address != null) ...[
                Text('Alamat: ${farmer.address}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
              const Divider(height: 24),
              const Text('Ringkasan Keuangan & Hasil Panen:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailTile(
                      'Total Setoran',
                      '${summary['totalSubmissions']} kali (${WeightFormatter.format(summary['totalNetWeight'] as double)})',
                    ),
                  ),
                  Expanded(
                    child: _buildDetailTile(
                      'Total Hak Pembayaran',
                      CurrencyFormatter.format(summary['totalHak'] as double),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailTile(
                      'Sudah Dibayar',
                      CurrencyFormatter.format(summary['totalPaid'] as double),
                      color: AppColors.success,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailTile(
                      'Sisa Kewajiban',
                      CurrencyFormatter.format(summary['remainingPayable'] as double),
                      color: (summary['remainingPayable'] as double) > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailTile(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final farmersAsync = ref.watch(activeFarmersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Master Petani'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Tambah Petani',
            onPressed: () => _showAddEditFarmerDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama atau telepon petani...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: farmersAsync.when(
              data: (farmers) {
                final filtered = farmers.where((f) {
                  final name = f.name.toLowerCase();
                  final phone = (f.phone ?? '').toLowerCase();
                  return name.contains(_searchQuery) || phone.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    title: 'Tidak Ada Data Petani',
                    message: 'Daftarkan nama-nama petani pemasok hasil panen ke sistem.',
                    buttonText: 'Tambah Petani',
                    onButtonPressed: () => _showAddEditFarmerDialog(),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final f = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLighter,
                          child: Text(
                            f.name.isNotEmpty ? f.name[0].toUpperCase() : 'P',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          f.address ?? (f.phone ?? 'Aktif'),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        onTap: () => _showFarmerDetailModal(f),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Gagal: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditFarmerDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}
