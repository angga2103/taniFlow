class BusinessCalculator {
  BusinessCalculator._();

  /// 1. Perhitungan Berat Bersih
  /// Rumus: Berat Bersih = Berat Kotor - Berat Tara
  static double calculateNetWeight(double grossWeight, double tareWeight) {
    final net = grossWeight - tareWeight;
    return double.parse((net < 0 ? 0.0 : net).toStringAsFixed(2));
  }

  /// 2. Rekonsiliasi Sortir & Grading
  /// Berat masuk = Berat Grade A + Berat Grade B + Berat Grade C + Berat rusak + Berat belum terjelaskan
  static GradingReconciliationResult reconcileGrading({
    required double incomingNetWeight,
    required double gradeAWeight,
    required double gradeBWeight,
    required double gradeCWeight,
    required double damagedWeight,
    required double tolerancePercent,
  }) {
    final explainedWeight = gradeAWeight + gradeBWeight + gradeCWeight + damagedWeight;
    final unexplainedDiff = double.parse((incomingNetWeight - explainedWeight).toStringAsFixed(2));

    final diffPercentage = incomingNetWeight > 0
        ? (unexplainedDiff.abs() / incomingNetWeight) * 100
        : 0.0;

    final isExceedingTolerance = diffPercentage > tolerancePercent;

    return GradingReconciliationResult(
      incomingNetWeight: incomingNetWeight,
      explainedWeight: double.parse(explainedWeight.toStringAsFixed(2)),
      unexplainedDiffWeight: unexplainedDiff,
      diffPercentage: double.parse(diffPercentage.toStringAsFixed(2)),
      isExceedingTolerance: isExceedingTolerance,
    );
  }

  /// 3. Konversi Satuan ke Kg
  static double convertToKg(double quantity, double toKgMultiplier) {
    return double.parse((quantity * toKgMultiplier).toStringAsFixed(2));
  }

  /// 4. Alokasi Penjualan Proporsional ke Petani
  /// Alokasi = (Berat Sumber Petani / Total Berat Sumber) * Total Berat Terjual
  static double allocateProportionalWeight({
    required double farmerSourceWeight,
    required double totalSourceWeight,
    required double totalSoldWeight,
  }) {
    if (totalSourceWeight <= 0 || totalSoldWeight <= 0) return 0.0;
    final allocated = (farmerSourceWeight / totalSourceWeight) * totalSoldWeight;
    // Berat dialokasikan tidak boleh melebihi kontribusi sumber
    final capped = allocated > farmerSourceWeight ? farmerSourceWeight : allocated;
    return double.parse(capped.toStringAsFixed(2));
  }

  /// 5. Harga Jual Rata-Rata Tertimbang
  /// Rumus: Harga Rata-Rata = Total Nilai Penjualan yang Dialokasikan / Total Berat Terjual yang Dialokasikan
  static double calculateWeightedAveragePrice(double totalRevenue, double totalSoldWeight) {
    if (totalSoldWeight <= 0) return 0.0;
    return double.parse((totalRevenue / totalSoldWeight).toStringAsFixed(2));
  }

  /// 6. Penentuan Hak Petani
  /// Mode Tunggal: Berat * Harga Tunggal - Pembebanan Kerugian
  /// Mode Grading: (Berat A * Harga A) + (Berat B * Harga B) + (Berat C * Harga C) - Pembebanan Kerugian
  static double calculateFarmerPayableAmount({
    required String mode, // 'TUNGGAL' or 'GRADING'
    required String basis, // 'BERAT_BERSIH_AWAL' or 'BERAT_SORTIR'
    required double initialNetWeight,
    required double gradeAWeight,
    required double gradeBWeight,
    required double gradeCWeight,
    double singlePrice = 0.0,
    double gradeAPrice = 0.0,
    double gradeBPrice = 0.0,
    double gradeCPrice = 0.0,
    double damageDeduction = 0.0,
  }) {
    double grossAmount = 0.0;

    if (mode == 'TUNGGAL') {
      final effectiveWeight = (basis == 'BERAT_BERSIH_AWAL')
          ? initialNetWeight
          : (gradeAWeight + gradeBWeight + gradeCWeight);
      grossAmount = effectiveWeight * singlePrice;
    } else {
      grossAmount = (gradeAWeight * gradeAPrice) +
          (gradeBWeight * gradeBPrice) +
          (gradeCWeight * gradeCPrice);
    }

    final netPayable = grossAmount - damageDeduction;
    return double.parse((netPayable < 0 ? 0.0 : netPayable).toStringAsFixed(0));
  }

  /// 7. Perhitungan Pembagian Kerugian Rusak / Afkir
  static DamageDistributionResult calculateDamageDistribution({
    required double damageWeight,
    required double estimatedPricePerKg,
    required String responsibleParty, // 'PEMILIK', 'PETANI', 'BERSAMA', 'NOMINAL_MANUAL', 'PERSENTASE_MANUAL'
    double customOwnerPercent = 50.0,
    double manualOwnerNominal = 0.0,
    double manualFarmerNominal = 0.0,
  }) {
    final totalLoss = damageWeight * estimatedPricePerKg;
    double ownerShare = 0.0;
    double farmerShare = 0.0;

    switch (responsibleParty) {
      case 'PEMILIK':
        ownerShare = totalLoss;
        farmerShare = 0.0;
        break;
      case 'PETANI':
        ownerShare = 0.0;
        farmerShare = totalLoss;
        break;
      case 'BERSAMA':
        ownerShare = totalLoss * 0.5;
        farmerShare = totalLoss * 0.5;
        break;
      case 'PERSENTASE_MANUAL':
        ownerShare = totalLoss * (customOwnerPercent / 100);
        farmerShare = totalLoss - ownerShare;
        break;
      case 'NOMINAL_MANUAL':
        ownerShare = manualOwnerNominal;
        farmerShare = manualFarmerNominal;
        break;
      default:
        ownerShare = totalLoss;
        farmerShare = 0.0;
    }

    return DamageDistributionResult(
      totalLossValue: double.parse(totalLoss.toStringAsFixed(0)),
      ownerShare: double.parse(ownerShare.toStringAsFixed(0)),
      farmerShare: double.parse(farmerShare.toStringAsFixed(0)),
    );
  }

  /// 8. Laporan Laba Bersih & Margin
  /// Omzet = Total Penjualan Aktual
  /// Hak Petani = Total Kewajiban Petani yang disepakati
  /// Margin Kotor = Omzet - Hak Petani - Kerugian Ditanggung Pemilik
  /// Laba Bersih = Margin Kotor - Pengeluaran Operasional - Biaya Kemasan
  static FinancialResult calculateFinancials({
    required double totalOmzet,
    required double totalHakPetani,
    required double ownerDamageLoss,
    required double operationalExpenses,
    required double packagingExpenses,
  }) {
    final marginKotor = totalOmzet - totalHakPetani - ownerDamageLoss;
    final labaBersih = marginKotor - operationalExpenses - packagingExpenses;

    final marginKotorPercent = totalOmzet > 0 ? (marginKotor / totalOmzet) * 100 : 0.0;
    final marginBersihPercent = totalOmzet > 0 ? (labaBersih / totalOmzet) * 100 : 0.0;

    return FinancialResult(
      omzet: double.parse(totalOmzet.toStringAsFixed(0)),
      hakPetani: double.parse(totalHakPetani.toStringAsFixed(0)),
      ownerDamageLoss: double.parse(ownerDamageLoss.toStringAsFixed(0)),
      marginKotor: double.parse(marginKotor.toStringAsFixed(0)),
      marginKotorPercent: double.parse(marginKotorPercent.toStringAsFixed(2)),
      operationalExpenses: double.parse(operationalExpenses.toStringAsFixed(0)),
      packagingExpenses: double.parse(packagingExpenses.toStringAsFixed(0)),
      labaBersih: double.parse(labaBersih.toStringAsFixed(0)),
      marginBersihPercent: double.parse(marginBersihPercent.toStringAsFixed(2)),
    );
  }

  /// 9. Perhitungan Piutang Pembeli / Sisa Tagihan
  static double calculateRemainingBalance(double totalAmount, double paidAmount) {
    final remaining = totalAmount - paidAmount;
    return double.parse((remaining < 0 ? 0.0 : remaining).toStringAsFixed(0));
  }
}

class GradingReconciliationResult {
  final double incomingNetWeight;
  final double explainedWeight;
  final double unexplainedDiffWeight;
  final double diffPercentage;
  final bool isExceedingTolerance;

  GradingReconciliationResult({
    required this.incomingNetWeight,
    required this.explainedWeight,
    required this.unexplainedDiffWeight,
    required this.diffPercentage,
    required this.isExceedingTolerance,
  });
}

class DamageDistributionResult {
  final double totalLossValue;
  final double ownerShare;
  final double farmerShare;

  DamageDistributionResult({
    required this.totalLossValue,
    required this.ownerShare,
    required this.farmerShare,
  });
}

class FinancialResult {
  final double omzet;
  final double hakPetani;
  final double ownerDamageLoss;
  final double marginKotor;
  final double marginKotorPercent;
  final double operationalExpenses;
  final double packagingExpenses;
  final double labaBersih;
  final double marginBersihPercent;

  FinancialResult({
    required this.omzet,
    required this.hakPetani,
    required this.ownerDamageLoss,
    required this.marginKotor,
    required this.marginKotorPercent,
    required this.operationalExpenses,
    required this.packagingExpenses,
    required this.labaBersih,
    required this.marginBersihPercent,
  });
}
