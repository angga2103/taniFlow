import 'package:flutter_test/flutter_test.dart';
import 'package:taniflow/core/utils/business_calculator.dart';
import 'package:taniflow/core/utils/currency_formatter.dart';
import 'package:taniflow/core/utils/weight_formatter.dart';

void main() {
  group('Unit Tests - Business Calculator & Formatter', () {
    test('1. Perhitungan Berat Bersih: Net = Gross - Tare', () {
      expect(BusinessCalculator.calculateNetWeight(105.50, 5.50), equals(100.00));
      expect(BusinessCalculator.calculateNetWeight(20.0, 1.25), equals(18.75));
      // Negative net safety
      expect(BusinessCalculator.calculateNetWeight(5.0, 10.0), equals(0.0));
    });

    test('2. Rekonsiliasi Sortir & Grading (Skenario B)', () {
      // Petani setor 100 kg.
      // Hasil sortir: A 50 kg, B 35 kg, C 10 kg, rusak 3 kg, selisih 2 kg.
      final result = BusinessCalculator.reconcileGrading(
        incomingNetWeight: 100.0,
        gradeAWeight: 50.0,
        gradeBWeight: 35.0,
        gradeCWeight: 10.0,
        damagedWeight: 3.0,
        tolerancePercent: 1.5, // tolerance 1.5% -> 2kg diff (2.0%) should exceed!
      );

      expect(result.explainedWeight, equals(98.0));
      expect(result.unexplainedDiffWeight, equals(2.0));
      expect(result.diffPercentage, equals(2.0));
      expect(result.isExceedingTolerance, isTrue);

      // Within tolerance test
      final resultOk = BusinessCalculator.reconcileGrading(
        incomingNetWeight: 100.0,
        gradeAWeight: 50.0,
        gradeBWeight: 35.0,
        gradeCWeight: 10.0,
        damagedWeight: 4.0,
        tolerancePercent: 2.0, // 1kg diff (1.0%) <= 2.0%
      );
      expect(resultOk.unexplainedDiffWeight, equals(1.0));
      expect(resultOk.isExceedingTolerance, isFalse);
    });

    test('3. Konversi Satuan ke Kg', () {
      // 1 Keranjang Tomat = 20 kg
      expect(BusinessCalculator.convertToKg(5.0, 20.0), equals(100.0));
      // 1 Keranjang Cabai = 15 kg
      expect(BusinessCalculator.convertToKg(4.0, 15.0), equals(60.0));
    });

    test('4. Alokasi Penjualan Proporsional ke Petani', () {
      // Total muatan 100 kg gabungan. Petani A setor 60 kg, Petani B setor 40 kg.
      // Terjual bertahap 50 kg.
      final allocA = BusinessCalculator.allocateProportionalWeight(
        farmerSourceWeight: 60.0,
        totalSourceWeight: 100.0,
        totalSoldWeight: 50.0,
      );
      final allocB = BusinessCalculator.allocateProportionalWeight(
        farmerSourceWeight: 40.0,
        totalSourceWeight: 100.0,
        totalSoldWeight: 50.0,
      );

      expect(allocA, equals(30.0)); // 60/100 * 50 = 30 kg
      expect(allocB, equals(20.0)); // 40/100 * 50 = 20 kg
      expect(allocA + allocB, equals(50.0));
    });

    test('5. Harga Jual Rata-Rata Tertimbang', () {
      // 100 kg terjual dalam 2 transaksi:
      // Transaksi 1: 40 kg @ Rp 30.000 = Rp 1.200.000
      // Transaksi 2: 60 kg @ Rp 25.000 = Rp 1.500.000
      // Total Revenue = Rp 2.700.000, Total Weight = 100 kg
      // Avg Price = 2.700.000 / 100 = Rp 27.000 / kg
      final avgPrice = BusinessCalculator.calculateWeightedAveragePrice(2700000.0, 100.0);
      expect(avgPrice, equals(27000.0));
    });

    test('6. Penentuan Hak Petani (Mode Tunggal vs Mode Grading)', () {
      // Mode Tunggal: 100 kg @ Rp 20.000 - potongan Rp 50.000
      final payableSingle = BusinessCalculator.calculateFarmerPayableAmount(
        mode: 'TUNGGAL',
        basis: 'BERAT_BERSIH_AWAL',
        initialNetWeight: 100.0,
        gradeAWeight: 50.0,
        gradeBWeight: 35.0,
        gradeCWeight: 15.0,
        singlePrice: 20000.0,
        damageDeduction: 50000.0,
      );
      expect(payableSingle, equals(1950000.0)); // (100 * 20.000) - 50.000

      // Mode Grading:
      // Grade A: 50 kg @ Rp 25.000 = Rp 1.250.000
      // Grade B: 35 kg @ Rp 20.000 = Rp 700.000
      // Grade C: 10 kg @ Rp 15.000 = Rp 150.000
      // Total = Rp 2.100.000
      final payableGrading = BusinessCalculator.calculateFarmerPayableAmount(
        mode: 'GRADING',
        basis: 'BERAT_SORTIR',
        initialNetWeight: 100.0,
        gradeAWeight: 50.0,
        gradeBWeight: 35.0,
        gradeCWeight: 10.0,
        gradeAPrice: 25000.0,
        gradeBPrice: 20000.0,
        gradeCPrice: 15000.0,
        damageDeduction: 0.0,
      );
      expect(payableGrading, equals(2100000.0));
    });

    test('7. Perhitungan Sisa Piutang Pembeli', () {
      // Total nota Rp 2.500.000, dibayar tunai Rp 1.000.000 -> sisa piutang Rp 1.500.000
      expect(BusinessCalculator.calculateRemainingBalance(2500000.0, 1000000.0), equals(1500000.0));
      // Pelunasan penuh
      expect(BusinessCalculator.calculateRemainingBalance(2500000.0, 2500000.0), equals(0.0));
    });

    test('8. Laporan Laba Bersih & Margin', () {
      // Omzet = Rp 10.000.000
      // Hak Petani = Rp 7.500.000
      // Kerugian Ditanggung Pemilik = Rp 200.000
      // Margin Kotor = 10.000.000 - 7.500.000 - 200.000 = Rp 2.300.000 (23%)
      // Biaya Operasional = Rp 500.000
      // Biaya Kemasan = Rp 300.000
      // Laba Bersih = 2.300.000 - 500.000 - 300.000 = Rp 1.500.000 (15%)
      final financials = BusinessCalculator.calculateFinancials(
        totalOmzet: 10000000.0,
        totalHakPetani: 7500000.0,
        ownerDamageLoss: 200000.0,
        operationalExpenses: 500000.0,
        packagingExpenses: 300000.0,
      );

      expect(financials.marginKotor, equals(2300000.0));
      expect(financials.marginKotorPercent, equals(23.0));
      expect(financials.labaBersih, equals(1500000.0));
      expect(financials.marginBersihPercent, equals(15.0));
    });

    test('9. Pembebanan Kerugian Sayur Rusak', () {
      // 10 kg rusak @ Rp 10.000 = Rp 100.000 total kerugian
      final distPemilik = BusinessCalculator.calculateDamageDistribution(
        damageWeight: 10.0,
        estimatedPricePerKg: 10000.0,
        responsibleParty: 'PEMILIK',
      );
      expect(distPemilik.ownerShare, equals(100000.0));
      expect(distPemilik.farmerShare, equals(0.0));

      final distPetani = BusinessCalculator.calculateDamageDistribution(
        damageWeight: 10.0,
        estimatedPricePerKg: 10000.0,
        responsibleParty: 'PETANI',
      );
      expect(distPetani.ownerShare, equals(0.0));
      expect(distPetani.farmerShare, equals(100000.0));

      final distBersama = BusinessCalculator.calculateDamageDistribution(
        damageWeight: 10.0,
        estimatedPricePerKg: 10000.0,
        responsibleParty: 'BERSAMA',
      );
      expect(distBersama.ownerShare, equals(50000.0));
      expect(distBersama.farmerShare, equals(50000.0));
    });

    test('10. Format Mata Uang dan Berat', () {
      expect(CurrencyFormatter.format(1500000), equals('Rp 1.500.000'));
      expect(WeightFormatter.format(100.5), equals('100,50 kg'));
      expect(WeightFormatter.format(50.0, hideZeroDecimals: true), equals('50 kg'));
    });
  });
}
