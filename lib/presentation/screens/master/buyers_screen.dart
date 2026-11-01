import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';

class BuyersScreen extends ConsumerStatefulWidget {
  const BuyersScreen({super.key});

  @override
  ConsumerState<BuyersScreen> createState() => _BuyersScreenState();
}

class _BuyersScreenState extends ConsumerState<BuyersScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditBuyerDialog([Buyer? buyer]) {
    final nameController = TextEditingController(text: buyer?.name ?? '');
    final phoneController = TextEditingController(text: buyer?.phone ?? '');
    final addressController = TextEditingController(text: buyer?.address ?? '');
    final notesController = TextEditingController(text: buyer?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(buyer == null ? 'Tambah Pembeli / Kios Baru' : 'Edit Data Pembeli'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Pembeli / Nama Kios *'),
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
                  decoration: const InputDecoration(labelText: 'Lokasi Pasar / Los / Blok'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Catatan'),
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
                    const SnackBar(content: Text('Nama pembeli wajib diisi.')),
                  );
                  return;
                }

                final repo = ref.read(repositoryProvider);
                if (buyer == null) {
                  await repo.addBuyer(
                    name: name,
                    phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                } else {
                  await repo.updateBuyer(
                    id: buyer.id,
                    name: name,
                    phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                }

                ref.invalidate(activeBuyersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showBuyerDetailModal(Buyer buyer) async {
    final repo = ref.read(repositoryProvider);
    final summary = await repo.getBuyerFinancialSummary(buyer.id);

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
                    buyer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddEditBuyerDialog(buyer);
                    },
                  ),
                ],
              ),
              if (buyer.phone != null) ...[
                Text('Telp: ${buyer.phone}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
              if (buyer.address != null) ...[
                Text('Lokasi: ${buyer.address}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
              const Divider(height: 24),
              const Text('Ringkasan Transaksi & Piutang:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailTile(
                      'Total Pembelian',
                      CurrencyFormatter.format(summary['totalPurchases'] as double),
                    ),
                  ),
                  Expanded(
                    child: _buildDetailTile(
                      'Pembayaran Diterima',
                      CurrencyFormatter.format(summary['totalPaid'] as double),
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildDetailTile(
                'Sisa Piutang Berjalan',
                CurrencyFormatter.format(summary['remainingReceivable'] as double),
                color: (summary['remainingReceivable'] as double) > 0 ? AppColors.danger : AppColors.success,
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
      width: double.infinity,
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
    final buyersAsync = ref.watch(activeBuyersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Master Pembeli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Tambah Pembeli',
            onPressed: () => _showAddEditBuyerDialog(),
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
                hintText: 'Cari nama atau telepon pembeli...',
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
            child: buyersAsync.when(
              data: (buyers) {
                final filtered = buyers.where((b) {
                  final name = b.name.toLowerCase();
                  final phone = (b.phone ?? '').toLowerCase();
                  return name.contains(_searchQuery) || phone.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Tidak Ada Data Pembeli',
                    message: 'Daftarkan nama-nama pembeli atau pedagang di pasar ke sistem.',
                    buttonText: 'Tambah Pembeli',
                    onButtonPressed: () => _showAddEditBuyerDialog(),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final b = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.infoLight,
                          child: Text(
                            b.name.isNotEmpty ? b.name[0].toUpperCase() : 'B',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.info),
                          ),
                        ),
                        title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          b.address ?? (b.phone ?? 'Aktif'),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        onTap: () => _showBuyerDetailModal(b),
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
        onPressed: () => _showAddEditBuyerDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}
