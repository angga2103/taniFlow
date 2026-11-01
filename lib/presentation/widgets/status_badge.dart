import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;

    switch (status.toUpperCase()) {
      case 'MENUNGGU_SORTIR':
        bg = AppColors.warningLight;
        text = AppColors.warning;
        label = 'Menunggu Sortir';
        break;
      case 'SELESAI_SORTIR':
        bg = AppColors.primaryLighter;
        text = AppColors.primary;
        label = 'Selesai Sortir';
        break;
      case 'SEBAGIAN_SORTIR':
        bg = AppColors.infoLight;
        text = AppColors.info;
        label = 'Sebagian Sortir';
        break;
      case 'SIAP_KIRIM':
        bg = AppColors.infoLight;
        text = AppColors.info;
        label = 'Siap Kirim';
        break;
      case 'TERJUAL_LENGKAP':
      case 'LUNAS':
        bg = AppColors.successLight;
        text = AppColors.success;
        label = status.toUpperCase() == 'LUNAS' ? 'Lunas' : 'Terjual Lengkap';
        break;
      case 'TERJUAL_SEBAGIAN':
      case 'SEBAGIAN':
        bg = AppColors.secondaryLight;
        text = AppColors.secondary;
        label = status.toUpperCase() == 'SEBAGIAN' ? 'Bayar Sebagian' : 'Terjual Sebagian';
        break;
      case 'BELUM_LUNAS':
      case 'BELUM_TERJUAL':
        bg = AppColors.dangerLight;
        text = AppColors.danger;
        label = status.toUpperCase() == 'BELUM_LUNAS' ? 'Belum Lunas' : 'Belum Terjual';
        break;
      default:
        bg = AppColors.divider;
        text = AppColors.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: text.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
