import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'submission_detail_screen.dart';
import 'submission_form_screen.dart';

class SubmissionListScreen extends ConsumerStatefulWidget {
  const SubmissionListScreen({super.key});

  @override
  ConsumerState<SubmissionListScreen> createState() => _SubmissionListScreenState();
}

class _SubmissionListScreenState extends ConsumerState<SubmissionListScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submissionsAsync = ref.watch(submissionsProvider);
    final farmersAsync = ref.watch(activeFarmersProvider);

    final farmerMap = {
      for (final f in farmersAsync.value ?? []) f.id: f.name
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Setoran Petani'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Setoran Baru',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubmissionFormScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nomor transaksi atau petani...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),

          // List of Submissions
          Expanded(
            child: submissionsAsync.when(
              data: (submissions) {
                final filtered = submissions.where((s) {
                  final farmerName = (farmerMap[s.farmerId] ?? '').toLowerCase();
                  final txNum = s.transactionNumber.toLowerCase();
                  return txNum.contains(_searchQuery) || farmerName.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Belum Ada Transaksi Setoran',
                    message: 'Catat penerimaan setoran panen sayur dari petani sekarang.',
                    buttonText: 'Buat Setoran Baru',
                    onButtonPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubmissionFormScreen()),
                      );
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final sub = filtered[index];
                    final farmerName = farmerMap[sub.farmerId] ?? 'Petani';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sub.transactionNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            StatusBadge(status: sub.status),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Petani: $farmerName',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormatter.formatDateTime(sub.submissionDate),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                        trailing: Text(
                          WeightFormatter.format(sub.totalNetWeight),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.primary,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubmissionDetailScreen(submission: sub),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Gagal memuat setoran: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubmissionFormScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Setoran Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
