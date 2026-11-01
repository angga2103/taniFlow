import 'package:flutter_test/flutter_test.dart';
import 'package:taniflow/core/utils/business_calculator.dart';

void main() {
  group('Scenario Tests Skenario A - H (Section 27 Specifications)', () {
    test('Skenario A & B — Setoran dan Sortir Rekonsiliasi', () {
      // Skenario A: Petani A menyetor 100 kg cabai (Kotor 105 kg, Tara 5 kg)
      final netWeight = BusinessCalculator.calculateNetWeight(105.0, 5.0);
      expect(netWeight, equals(100.0));

      // Skenario B: Sortir
      // Grade A: 50 kg, Grade B: 35 kg, Grade C: 10 kg, rusak: 3 kg, selisih: 2 kg
      final recon = BusinessCalculator.reconcileGrading(
        incomingNetWeight: netWeight,
        gradeAWeight: 50.0,
        gradeBWeight: 35.0,
        gradeCWeight: 10.0,
        damagedWeight: 3.0,
        tolerancePercent: 1.5, // 1.5% toleransi
      );

      // Verifikasi rekonsiliasi
      expect(recon.incomingNetWeight, equals(100.0));
      expect(recon.explainedWeight, equals(98.0));
      expect(recon.unexplainedDiffWeight, equals(2.0));
      expect(recon.diffPercentage, equals(2.0));
      // Melebihi toleransi 1.5%, sistem meminta alasan
      expect(recon.isExceedingTolerance, isTrue);
    });

    test('Skenario C & D — Pengiriman Gabungan dan Penjualan Bertahap', () {
      // Skenario C: Petani A (50 kg Grade A) dan Petani B (50 kg Grade A) digabung dalam 1 pengiriman = 100 kg Grade A.
      const totalShipmentWeight = 100.0;
      const farmerAWeight = 50.0;
      const farmerBWeight = 50.0;

      // Skenario D: Penjualan bertahap
      // Tahap 1: Dijual ke Pembeli 1 sebanyak 60 kg @ Rp 30.000 = Rp 1.800.000
      const sale1Weight = 60.0;
      const sale1Price = 30000.0;
      final sale1Revenue = sale1Weight * sale1Price;
      expect(sale1Revenue, equals(1800000.0));

      // Alokasi Tahap 1 ke Petani A & B:
      final allocA1 = BusinessCalculator.allocateProportionalWeight(
        farmerSourceWeight: farmerAWeight,
        totalSourceWeight: totalShipmentWeight,
        totalSoldWeight: sale1Weight,
      );
      final allocB1 = BusinessCalculator.allocateProportionalWeight(
        farmerSourceWeight: farmerBWeight,
        totalSourceWeight: totalShipmentWeight,
        totalSoldWeight: sale1Weight,
      );
      expect(allocA1, equals(30.0));
      expect(allocB1, equals(30.0));

      // Tahap 2: Sisa 40 kg dijual ke Pembeli 2 @ Rp 25.000 = Rp 1.000.000
      const sale2Weight = 40.0;
      const sale2Price = 25000.0;
      final sale2Revenue = sale2Weight * sale2Price;
      expect(sale2Revenue, equals(1000000.0));

      // Alokasi Tahap 2 ke Petani A & B:
      final allocA2 = BusinessCalculator.allocateProportionalWeight(
        farmerSourceWeight: farmerAWeight,
        totalSourceWeight: totalShipmentWeight,
        totalSoldWeight: sale2Weight,
      );
      final allocB2 = BusinessCalculator.allocateProportionalWeight(
        farmerSourceWeight: farmerBWeight,
        totalSourceWeight: totalShipmentWeight,
        totalSoldWeight: sale2Weight,
      );
      expect(allocA2, equals(20.0));
      expect(allocB2, equals(20.0));

      // Verifikasi Total Terjual: 30 + 20 = 50 kg untuk Petani A, 30 + 20 = 50 kg untuk Petani B
      expect(allocA1 + allocA2, equals(farmerAWeight));
      expect(allocB1 + allocB2, equals(farmerBWeight));

      // Harga rata-rata tertimbang penjualan:
      // Total Revenue = 1.800.000 + 1.000.000 = 2.800.000 / 100 kg = Rp 28.000 / kg
      final totalRevenue = sale1Revenue + sale2Revenue;
      final avgSellingPrice = BusinessCalculator.calculateWeightedAveragePrice(totalRevenue, totalShipmentWeight);
      expect(avgSellingPrice, equals(28000.0));
    });

    test('Skenario E — Pembayaran Pembeli & Piutang', () {
      // Pembeli 1 beli Rp 1.800.000, bayar tunai Rp 1.000.000, tempo Rp 800.000
      final piutang1 = BusinessCalculator.calculateRemainingBalance(1800000.0, 1000000.0);
      expect(piutang1, equals(800000.0));

      // Pembayaran cicilan kedua Rp 500.000
      final piutang2 = BusinessCalculator.calculateRemainingBalance(piutang1, 500000.0);
      expect(piutang2, equals(300000.0));

      // Pelunasan akhir Rp 300.000
      final piutangFinal = BusinessCalculator.calculateRemainingBalance(piutang2, 300000.0);
      expect(piutangFinal, equals(0.0));
    });

    test('Skenario F & G — Penentuan Harga Petani dan Pembayaran Bertahap', () {
      // Skenario F: Pemilik menentukan harga petani Grade A = Rp 22.000 / kg untuk 50 kg
      final hakPetani = BusinessCalculator.calculateFarmerPayableAmount(
        mode: 'GRADING',
        basis: 'BERAT_SORTIR',
        initialNetWeight: 50.0,
        gradeAWeight: 50.0,
        gradeBWeight: 0.0,
        gradeCWeight: 0.0,
        gradeAPrice: 22000.0,
        damageDeduction: 0.0,
      );
      expect(hakPetani, equals(1100000.0)); // 50 * 22.000 = Rp 1.100.000

      // Skenario G: Petani menerima pembayaran bertahap
      // Bayar pertama Rp 600.000
      final sisaKewajiban1 = BusinessCalculator.calculateRemainingBalance(hakPetani, 600000.0);
      expect(sisaKewajiban1, equals(500000.0));

      // Pelunasan kedua Rp 500.000
      final sisaKewajibanFinal = BusinessCalculator.calculateRemainingBalance(sisaKewajiban1, 500000.0);
      expect(sisaKewajibanFinal, equals(0.0));
    });

    test('Skenario H — Rekonsiliasi Menyeluruh (Keuangan & Laba)', () {
      // Omzet Total = Rp 2.800.000
      // Hak Petani A (50 kg @ 22.000) = Rp 1.100.000
      // Hak Petani B (50 kg @ 22.000) = Rp 1.100.000
      // Total Hak Petani = Rp 2.200.000
      // Beban Kerusakan Pemilik = Rp 0
      // Biaya Operasional (BBM) = Rp 150.000
      // Biaya Kemasan (Karung) = Rp 50.000
      final report = BusinessCalculator.calculateFinancials(
        totalOmzet: 2800000.0,
        totalHakPetani: 2200000.0,
        ownerDamageLoss: 0.0,
        operationalExpenses: 150000.0,
        packagingExpenses: 50000.0,
      );

      // Margin Kotor = 2.800.000 - 2.200.000 = Rp 600.000
      expect(report.marginKotor, equals(600000.0));
      // Laba Bersih = 600.000 - 150.000 - 50.000 = Rp 400.000
      expect(report.labaBersih, equals(400000.0));
      expect(report.marginBersihPercent, closeTo(14.29, 0.01));
    });
  });
}
