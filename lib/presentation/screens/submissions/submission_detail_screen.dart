import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../../data/services/pdf_service.dart';
import '../../../data/services/share_service.dart';
import '../../providers/providers.dart';
import '../../widgets/status_badge.dart';

class SubmissionDetailScreen extends ConsumerStatefulWidget {
  final FarmerSubmission submission;

  const SubmissionDetailScreen({super.key, required this.submission});

  @override
  ConsumerState<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends ConsumerState<SubmissionDetailScreen> {
  List<SubmissionItem> _items = [];
  String _farmerName = '-';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final repo = ref.read(repositoryProvider);
    final items = await repo.getSubmissionItems(widget.submission.id);
    final farmers = await repo.getActiveFarmers();
    final farmer = farmers.where((f) => f.id == widget.submission.farmerId).firstOrNull;

    if (mounted) {
      setState(() {
        _items = items;
        _farmerName = farmer?.name ?? 'Petani';
        _isLoading = false;
      });
    }
  }

  Future<void> _printReceipt() async {
    final printer = ref.read(printerServiceProvider);
    final profile = await ref.read(businessProfileProvider.future);
    final commodities = await ref.read(repositoryProvider).getCommodities();

    final commodityMap = {for (final c in commodities) c.id: c.name};

    final printItems = _items.map((it) {
      return {
        'commodity': commodityMap[it.commodityId] ?? 'Komoditas',
        'gross': it.grossWeight,
        'tare': it.tareWeight,
        'net': it.netWeight,
      };
    }).toList();

    final isSuccess = await printer.printSubmissionReceipt(
      businessName: profile?.businessName ?? AppStrings.appName,
      businessPhone: profile?.phone,
      transactionNumber: widget.submission.transactionNumber,
      date: widget.submission.submissionDate,
      farmerName: _farmerName,
      items: printItems,
      totalGross: widget.submission.totalGrossWeight,
      totalTare: widget.submission.totalTareWeight,
      totalNet: widget.submission.totalNetWeight,
      notes: widget.submission.notes,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSuccess
              ? 'Bukti setoran berhasil dicetak!'
              : 'Gagal mencetak. Pastikan printer bluetooth sudah terhubung.'),
          backgroundColor: isSuccess ? AppColors.primary : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _shareReceipt() async {
    final profile = await ref.read(businessProfileProvider.future);
    final commodities = await ref.read(repositoryProvider).getCommodities();
    final commodityMap = {for (final c in commodities) c.id: c.name};

    final printItems = _items.map((it) {
      return {
        'commodity': commodityMap[it.commodityId] ?? 'Komoditas',
        'gross': it.grossWeight,
        'tare': it.tareWeight,
        'net': it.netWeight,
      };
    }).toList();

    await ShareService.shareSubmissionText(
      businessName: profile?.businessName ?? AppStrings.appName,
      transactionNumber: widget.submission.transactionNumber,
      date: widget.submission.submissionDate,
      farmerName: _farmerName,
      items: printItems,
      totalNet: widget.submission.totalNetWeight,
    );
  }

  Future<void> _exportPdf() async {
    final profile = await ref.read(businessProfileProvider.future);
    final commodities = await ref.read(repositoryProvider).getCommodities();
    final commodityMap = {for (final c in commodities) c.id: c.name};

    final printItems = _items.map((it) {
      return {
        'commodity': commodityMap[it.commodityId] ?? 'Komoditas',
        'gross': it.grossWeight,
        'tare': it.tareWeight,
        'net': it.netWeight,
      };
    }).toList();

    final pdfFile = await PdfService.generateSubmissionReceipt(
      businessName: profile?.businessName ?? AppStrings.appName,
      businessAddress: profile?.address,
      businessPhone: profile?.phone,
      transactionNumber: widget.submission.transactionNumber,
      date: widget.submission.submissionDate,
      farmerName: _farmerName,
      items: printItems,
      totalGross: widget.submission.totalGrossWeight,
      totalTare: widget.submission.totalTareWeight,
      totalNet: widget.submission.totalNetWeight,
      notes: widget.submission.notes,
    );

    await ShareService.shareFile(
      file: pdfFile,
      text: 'Bukti Setoran ${widget.submission.transactionNumber}',
      subject: 'Bukti Setoran ${widget.submission.transactionNumber}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final commoditiesAsync = ref.watch(commoditiesProvider);
    final commodityMap = {
      for (final c in commoditiesAsync.value ?? []) c.id: c.name
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.submission.transactionNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Bagikan via WhatsApp',
            onPressed: _shareReceipt,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.submission.transactionNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            StatusBadge(status: widget.submission.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Petani: $_farmerName',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Waktu: ${DateFormatter.formatDateTime(widget.submission.submissionDate)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        if (widget.submission.notes != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Catatan: ${widget.submission.notes}',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rincian Komoditas
                  const Text(
                    'Rincian Komoditas Ditimbang',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final it = _items[index];
                      final commName = commodityMap[it.commodityId] ?? 'Komoditas';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    commName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kotor: ${WeightFormatter.format(it.grossWeight)} | Tara: ${WeightFormatter.format(it.tareWeight)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              Text(
                                WeightFormatter.format(it.netWeight),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Total Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLighter,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL BERAT BERSIH:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          WeightFormatter.format(widget.submission.totalNetWeight),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Disclaimer Card (Mandatory Rule)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: const Text(
                      'PENTING: Harga dan pembayaran ditentukan setelah hasil panen terjual.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareReceipt,
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _printReceipt,
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Cetak Thermal'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
