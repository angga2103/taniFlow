import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import 'about_screen.dart';
import 'business_profile_screen.dart';
import 'setup_pin_screen.dart';
import '../printer/printer_settings_screen.dart';
import '../backup/backup_screen.dart';
import '../master/commodities_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Sistem'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsGroup(
            title: 'Usaha & Operasional',
            items: [
              _SettingsTile(
                icon: Icons.store_outlined,
                title: 'Identitas & Profil Usaha',
                subtitle: 'Nama pengepul, alamat, dan batas toleransi susut',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.eco_outlined,
                title: 'Katalog Komoditas Sayur',
                subtitle: 'Kelola jenis sayuran dan toleransi susut per komoditas',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommoditiesScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.print_outlined,
                title: 'Printer Thermal Bluetooth',
                subtitle: 'Koneksi printer ESC/POS ukuran 58mm / 80mm',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSettingsGroup(
            title: 'Keamanan & Database',
            items: [
              _SettingsTile(
                icon: Icons.security_outlined,
                title: 'Kunci PIN & Biometrik',
                subtitle: 'Atur 6-digit PIN, sidik jari, dan kode recovery',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SetupPinScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.cloud_sync_outlined,
                title: 'Cadangan & Pemulihan (Backup)',
                subtitle: 'Google Drive dan ekspor arsip offline',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BackupScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSettingsGroup(
            title: 'Informasi',
            items: [
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Tentang ${AppStrings.appName}',
                subtitle: '${AppStrings.developerName} • Versi ${AppStrings.appVersion}',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryLighter,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
