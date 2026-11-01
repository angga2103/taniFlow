import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';
import 'grading_form_screen.dart';

class GradingListScreen extends ConsumerWidget {
  const GradingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingItemsAsync = ref.watch(pendingGradingItemsProvider);
    final commoditiesAsync = ref.watch(commoditiesProvider);
    final submissionsAsync = ref.watch(submissionsProvider);
    final farmersAsync = ref.watch(activeFarmersProvider);

    final commodityMap = {for (final c in commoditiesAsync.value ?? []) c.id: c};
    final submissionMap = {for (final s in submissionsAsync.value ?? []) s.id: s};
    final farmerMap = {for (final f in farmersAsync.value ?? []) f.id: f.name};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrean Sortir & Grading'),
      ),
      body: pendingItemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Semua Setoran Telah Disortir',
              message: 'Tidak ada komoditas dalam antrean sortir saat ini. Setoran baru akan muncul di sini.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final it = items[index];
              final comm = commodityMap[it.commodityId];
              final sub = submissionMap[it.submissionId];
              final farmerName = sub != null ? (farmerMap[sub.farmerId] ?? 'Petani') : 'Petani';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        comm?.name ?? 'Komoditas',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        WeightFormatter.format(it.netWeight),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        'Petani: $farmerName  |  Setoran: ${sub?.transactionNumber ?? "-"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Waktu Timbang: ${DateFormatter.formatDateTime(it.createdAt)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GradingFormScreen(
                                  item: it,
                                  farmerName: farmerName,
                                  commodityName: comm?.name ?? 'Komoditas',
                                  defaultTolerancePercent: comm?.defaultLossTolerancePercent ?? 2.0,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.grading, size: 16),
                          label: const Text('Lakukan Sortir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(130, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal memuat antrean sortir: $err')),
      ),
    );
  }
}
