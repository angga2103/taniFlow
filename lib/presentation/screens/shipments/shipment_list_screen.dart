import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../providers/providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'shipment_form_screen.dart';

class ShipmentListScreen extends ConsumerWidget {
  const ShipmentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipmentsAsync = ref.watch(shipmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Pengiriman Pasar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Pengiriman Baru',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShipmentFormScreen()),
              );
            },
          ),
        ],
      ),
      body: shipmentsAsync.when(
        data: (shipments) {
          if (shipments.isEmpty) {
            return EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Belum Ada Pengiriman Pasar',
              message: 'Buat pengiriman untuk mengirim komoditas sayuran yang sudah disortir ke pasar induk.',
              buttonText: 'Buat Pengiriman Baru',
              onButtonPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShipmentFormScreen()),
                );
              },
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: shipments.length,
            itemBuilder: (context, index) {
              final shp = shipments[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        shp.shipmentNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      StatusBadge(status: shp.status),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        'Tujuan: ${shp.destinationMarket ?? "Pasar Induk"}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Waktu: ${DateFormatter.formatDateTime(shp.shipmentDate)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      if (shp.driverName != null) ...[
                        const SizedBox(height: 2),
                        Text('Sopir: ${shp.driverName} (${shp.vehicleNumber ?? "-"})',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                  trailing: Text(
                    WeightFormatter.format(shp.totalWeight),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal memuat pengiriman: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShipmentFormScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Kirim ke Pasar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
