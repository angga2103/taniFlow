import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentang Aplikasi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLighter,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.eco, size: 56, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              AppStrings.appName,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 4),
            const Text(
              AppStrings.appDescription,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Versi ${AppStrings.appVersion}',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '"${AppStrings.appTagline}"',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 32),
            _buildInfoCard(),
            const SizedBox(height: 24),
            const Text(
              'Dikembangkan oleh ${AppStrings.developerName}\nSolusi Digital Agrobisnis & Rantai Pasok Pertanian Indonesia',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: const [
          _InfoRow(label: 'Pengembang', value: AppStrings.developerName),
          Divider(height: 20),
          _InfoRow(label: 'Platform', value: 'Android (Flutter)'),
          Divider(height: 20),
          _InfoRow(label: 'Mata Uang', value: 'Rupiah (Rp)'),
          Divider(height: 20),
          _InfoRow(label: 'Format Tanggal', value: 'DD-MM-YYYY (WIB)'),
          Divider(height: 20),
          _InfoRow(label: 'Satuan Standar', value: 'Kilogram (kg, 2 desimal)'),
          Divider(height: 20),
          _InfoRow(label: 'Penyimpanan Utama', value: 'Lokal SQLite (Drift Offline)'),
          Divider(height: 20),
          _InfoRow(label: 'Pencadangan', value: 'Google Drive Terenkripsi'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
