import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/providers.dart';

class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _toleranceController = TextEditingController(text: '2.0');

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _toleranceController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ref.read(businessProfileProvider.future);
    if (profile != null && mounted) {
      _businessNameController.text = profile.businessName;
      _ownerNameController.text = profile.ownerName ?? '';
      _phoneController.text = profile.phone ?? '';
      _addressController.text = profile.address ?? '';
      _toleranceController.text = profile.defaultGradingTolerancePercent.toStringAsFixed(1);
    }
  }

  Future<void> _saveProfile() async {
    final name = _businessNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama usaha wajib diisi.')),
      );
      return;
    }

    final tol = double.tryParse(_toleranceController.text.replaceAll(',', '.')) ?? 2.0;

    final repo = ref.read(repositoryProvider);
    await repo.updateBusinessProfile(
      businessName: name,
      ownerName: _ownerNameController.text.trim().isEmpty ? null : _ownerNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      defaultTolerance: tol,
    );

    ref.invalidate(businessProfileProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil usaha berhasil diperbarui!'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identitas & Profil Usaha'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identitas Usaha Pemilik',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Identitas ini akan dicetak pada seluruh bukti setoran, nota penjualan pasar, kuitansi pembayaran, dan laporan.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _businessNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Usaha Pengepul / UD *',
                hintText: 'Contoh: UD Hasil Tani Mandiri',
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _ownerNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Pemilik Usaha',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor Kontak / Telepon Usaha',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Alamat Gudang / Tempat Penimbangan',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _toleranceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Batas Default Toleransi Susut Sortir (%)',
                hintText: '2.0',
                suffixText: '%',
                prefixIcon: Icon(Icons.tune),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _saveProfile,
              icon: const Icon(Icons.save),
              label: const Text('Simpan Profil Usaha'),
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
