import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/business_calculator.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../providers/providers.dart';

class SalesFormScreen extends ConsumerStatefulWidget {
  const SalesFormScreen({super.key});

  @override
  ConsumerState<SalesFormScreen> createState() => _SalesFormScreenState();
}

class _SalesFormScreenState extends ConsumerState<SalesFormScreen> {
  String? _selectedShipmentId;
  String? _selectedBuyerId;
  String _paymentType = 'TUNAI'; // 'TUNAI' or 'TEMPO'

  List<ShipmentItem> _availableShipmentItems = [];

  // Multi-item sales list
  final List<Map<String, dynamic>> _items = [];

  // Item input
  ShipmentItem? _selectedShipmentItem;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  double _totalSalesAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _paidController.addListener(_recalculatePayment);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _priceController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recalculatePayment() {
    setState(() {});
  }

  Future<void> _onShipmentSelected(String? shipmentId) async {
    setState(() {
      _selectedShipmentId = shipmentId;
      _availableShipmentItems = [];
      _selectedShipmentItem = null;
      _items.clear();
      _totalSalesAmount = 0.0;
    });

    if (shipmentId != null) {
      final repo = ref.read(repositoryProvider);
      final items = await repo.getAvailableShipmentItems(shipmentId);

      if (mounted) {
        setState(() {
          _availableShipmentItems = items;
        });
      }
    }
  }

  void _addItem() {
    if (_selectedShipmentItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih komoditas dari muatan pengiriman.')),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0.0;
    final price = CurrencyFormatter.parse(_priceController.text);

    if (weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berat terjual harus lebih dari 0.')),
      );
      return;
    }

    if (weight > _selectedShipmentItem!.remainingWeight) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Berat melebihi sisa muatan (${WeightFormatter.format(_selectedShipmentItem!.remainingWeight)} tersisa).',
          ),
        ),
      );
      return;
    }

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harga jual per kg harus lebih dari 0.')),
      );
      return;
    }

    final commodities = ref.read(commoditiesProvider).value ?? [];
    final comm = commodities.firstWhere((c) => c.id == _selectedShipmentItem!.commodityId);
    final subtotal = weight * price;

    setState(() {
      _items.add({
        'shipmentItemId': _selectedShipmentItem!.id,
        'commodityId': _selectedShipmentItem!.commodityId,
        'commodityName': comm.name,
        'grade': _selectedShipmentItem!.grade,
        'weight': weight,
        'pricePerKg': price,
        'subtotal': subtotal,
      });

      _totalSalesAmount += subtotal;
      if (_paymentType == 'TUNAI') {
        _paidController.text = _totalSalesAmount.toStringAsFixed(0);
      }

      // Reset item inputs
      _selectedShipmentItem = null;
      _weightController.clear();
      _priceController.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      _totalSalesAmount -= (removed['subtotal'] as num).toDouble();
      if (_paymentType == 'TUNAI') {
        _paidController.text = _totalSalesAmount.toStringAsFixed(0);
      }
    });
  }

  Future<void> _saveSale() async {
    if (_selectedShipmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pengiriman asal terlebih dahulu.')),
      );
      return;
    }

    if (_selectedBuyerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pembeli terlebih dahulu.')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 item penjualan.')),
      );
      return;
    }

    final paid = CurrencyFormatter.parse(_paidController.text);

    try {
      final repo = ref.read(repositoryProvider);
      final invoiceNumber = await repo.recordSale(
        shipmentId: _selectedShipmentId!,
        buyerId: _selectedBuyerId!,
        paymentType: _paymentType,
        paidAmount: paid,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        items: _items,
      );

      // Refresh streams
      ref.invalidate(salesProvider);
      ref.invalidate(shipmentsProvider);
      ref.invalidate(cashTransactionsProvider);
      ref.invalidate(currentCashBalanceProvider);
      ref.invalidate(receivablesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Penjualan nota $invoiceNumber berhasil disimpan!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan penjualan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shipmentsAsync = ref.watch(shipmentsProvider);
    final buyersAsync = ref.watch(activeBuyersProvider);
    final commoditiesAsync = ref.watch(commoditiesProvider);

    final commMap = {for (final c in commoditiesAsync.value ?? []) c.id: c.name};

    final paid = CurrencyFormatter.parse(_paidController.text);
    final remaining = BusinessCalculator.calculateRemainingBalance(_totalSalesAmount, paid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penjualan Pasar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Pilih Pengiriman & Pembeli
            const Text(
              '1. Pilih Pengiriman Asal & Pembeli',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            shipmentsAsync.when(
              data: (shipments) {
                return DropdownButtonFormField<String>(
                  value: _selectedShipmentId,
                  decoration: const InputDecoration(
                    labelText: 'Pengiriman Pasar Asal',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                  items: shipments.map((s) {
                    return DropdownMenuItem<String>(
                      value: s.id,
                      child: Text('${s.shipmentNumber} - ${s.destinationMarket ?? "Pasar"} (${WeightFormatter.format(s.totalWeight)})'),
                    );
                  }).toList(),
                  onChanged: _onShipmentSelected,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Gagal: $err'),
            ),
            const SizedBox(height: 10),
            buyersAsync.when(
              data: (buyers) {
                return DropdownButtonFormField<String>(
                  value: _selectedBuyerId,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Pembeli / Pelanggan',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  items: buyers.map((b) {
                    return DropdownMenuItem<String>(
                      value: b.id,
                      child: Text('${b.name} ${b.phone != null ? "(${b.phone})" : ""}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedBuyerId = val;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Gagal: $err'),
            ),
            const SizedBox(height: 16),

            // 2. Tambah Komoditas Terjual
            if (_selectedShipmentId != null) ...[
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
                    const Text(
                      '2. Tambah Sayur Terjual',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ShipmentItem>(
                      value: _selectedShipmentItem,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Muatan Sayur Pengiriman',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      items: _availableShipmentItems.map((item) {
                        final name = commMap[item.commodityId] ?? 'Komoditas';
                        return DropdownMenuItem<ShipmentItem>(
                          value: item,
                          child: Text('$name (${item.grade}) - Sisa: ${WeightFormatter.format(item.remainingWeight)}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedShipmentItem = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Berat Terjual (kg)',
                              prefixIcon: Icon(Icons.scale),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Harga Jual/kg (Rp)',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Masukkan ke Nota'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Daftar Sayur yang Dijual
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('3. Rincian Penjualan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'Belum ada item sayur yang ditambahkan ke nota.',
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
                      subtitle: Text(
                        '${WeightFormatter.format(it['weight'] as double)} × ${CurrencyFormatter.format(it['pricePerKg'] as double)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            CurrencyFormatter.format(it['subtotal'] as double),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
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

            // 4. Pembayaran (Tunai vs Tempo / Piutang)
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
                  const Text('4. Cara Pembayaran & Kas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Tunai (Kas Masuk)')),
                          selected: _paymentType == 'TUNAI',
                          selectedColor: AppColors.primaryLight,
                          labelStyle: TextStyle(color: _paymentType == 'TUNAI' ? Colors.white : AppColors.textPrimary),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _paymentType = 'TUNAI';
                                _paidController.text = _totalSalesAmount.toStringAsFixed(0);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Tempo / Kredit (Piutang)')),
                          selected: _paymentType == 'TEMPO',
                          selectedColor: AppColors.primaryLight,
                          labelStyle: TextStyle(color: _paymentType == 'TEMPO' ? Colors.white : AppColors.textPrimary),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _paymentType = 'TEMPO';
                                _paidController.text = '0';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _paidController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Uang Diterima Tunai (Rp)',
                      prefixIcon: Icon(Icons.payments),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: remaining > 0 ? AppColors.dangerLight : AppColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          remaining > 0 ? 'Sisa Piutang Pembeli:' : 'Status Pembayaran:',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          remaining > 0 ? CurrencyFormatter.format(remaining) : 'LUNAS (Tunai Penuh)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: remaining > 0 ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Penjualan (Opsional)',
                hintText: 'Ketentuan tempo, potongan harga, dll.',
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _saveSale,
              icon: const Icon(Icons.check_circle),
              label: Text('Simpan Nota Penjualan (${CurrencyFormatter.format(_totalSalesAmount)})'),
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
