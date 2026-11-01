import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/business_calculator.dart';
import '../../core/utils/id_generator.dart';
import '../database/app_database.dart';

class TaniRepository {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  TaniRepository(this.db);

  // ---------------------------------------------------------
  // 1. DATA MASTER: PETANI
  // ---------------------------------------------------------
  Stream<List<Farmer>> watchActiveFarmers() {
    return (db.select(db.farmers)
          ..where((f) => f.isActive.equals(true))
          ..orderBy([(f) => OrderingTerm(expression: f.name)]))
        .watch();
  }

  Future<List<Farmer>> getActiveFarmers() {
    return (db.select(db.farmers)
          ..where((f) => f.isActive.equals(true))
          ..orderBy([(f) => OrderingTerm(expression: f.name)]))
        .get();
  }

  Future<String> addFarmer({
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.into(db.farmers).insert(
      FarmersCompanion.insert(
        id: id,
        name: name,
        phone: Value(phone),
        address: Value(address),
        notes: Value(notes),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  Future<void> updateFarmer({
    required String id,
    required String name,
    String? phone,
    String? address,
    String? notes,
    bool? isActive,
  }) async {
    final now = DateTime.now();
    await (db.update(db.farmers)..where((f) => f.id.equals(id))).write(
      FarmersCompanion(
        name: Value(name),
        phone: Value(phone),
        address: Value(address),
        notes: Value(notes),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  // Ringkasan Finansial & Operasional Petani
  Future<Map<String, dynamic>> getFarmerFinancialSummary(String farmerId) async {
    final submissions = await (db.select(db.farmerSubmissions)
          ..where((s) => s.farmerId.equals(farmerId)))
        .get();

    double totalNetWeight = 0.0;
    for (final s in submissions) {
      totalNetWeight += s.totalNetWeight;
    }

    final payables = await (db.select(db.farmerPayables)
          ..where((p) => p.farmerId.equals(farmerId)))
        .get();

    double totalHak = 0.0;
    double totalPaid = 0.0;
    double remainingPayable = 0.0;

    for (final p in payables) {
      totalHak += p.totalAmount;
      totalPaid += p.paidAmount;
      remainingPayable += p.remainingAmount;
    }

    return {
      'totalSubmissions': submissions.length,
      'totalNetWeight': totalNetWeight,
      'totalHak': totalHak,
      'totalPaid': totalPaid,
      'remainingPayable': remainingPayable,
    };
  }

  // ---------------------------------------------------------
  // 2. DATA MASTER: PEMBELI
  // ---------------------------------------------------------
  Stream<List<Buyer>> watchActiveBuyers() {
    return (db.select(db.buyers)
          ..where((b) => b.isActive.equals(true))
          ..orderBy([(b) => OrderingTerm(expression: b.name)]))
        .watch();
  }

  Future<List<Buyer>> getActiveBuyers() {
    return (db.select(db.buyers)
          ..where((b) => b.isActive.equals(true))
          ..orderBy([(b) => OrderingTerm(expression: b.name)]))
        .get();
  }

  Future<String> addBuyer({
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.into(db.buyers).insert(
      BuyersCompanion.insert(
        id: id,
        name: name,
        phone: Value(phone),
        address: Value(address),
        notes: Value(notes),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  Future<void> updateBuyer({
    required String id,
    required String name,
    String? phone,
    String? address,
    String? notes,
    bool? isActive,
  }) async {
    final now = DateTime.now();
    await (db.update(db.buyers)..where((b) => b.id.equals(id))).write(
      BuyersCompanion(
        name: Value(name),
        phone: Value(phone),
        address: Value(address),
        notes: Value(notes),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  // Ringkasan Piutang Pembeli
  Future<Map<String, dynamic>> getBuyerFinancialSummary(String buyerId) async {
    final receivables = await (db.select(db.buyerReceivables)
          ..where((r) => r.buyerId.equals(buyerId)))
        .get();

    double totalPurchases = 0.0;
    double totalPaid = 0.0;
    double remainingReceivable = 0.0;

    for (final r in receivables) {
      totalPurchases += r.totalAmount;
      totalPaid += r.paidAmount;
      remainingReceivable += r.remainingAmount;
    }

    return {
      'totalPurchases': totalPurchases,
      'totalPaid': totalPaid,
      'remainingReceivable': remainingReceivable,
    };
  }

  // ---------------------------------------------------------
  // 3. DATA MASTER: KOMODITAS & SATUAN
  // ---------------------------------------------------------
  Stream<List<Commodity>> watchCommodities() {
    return (db.select(db.commodities)
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .watch();
  }

  Future<List<Commodity>> getCommodities() {
    return (db.select(db.commodities)
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .get();
  }

  Future<String> addCommodity({
    required String name,
    double defaultLossTolerancePercent = 2.0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.into(db.commodities).insert(
      CommoditiesCompanion.insert(
        id: id,
        name: name,
        defaultLossTolerancePercent: Value(defaultLossTolerancePercent),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  Stream<List<CommodityUnit>> watchUnits() {
    return db.select(db.commodityUnits).watch();
  }

  Future<List<CommodityUnit>> getUnits() {
    return db.select(db.commodityUnits).get();
  }

  // ---------------------------------------------------------
  // 4. PENERIMAAN SETORAN PETANI
  // ---------------------------------------------------------
  Stream<List<FarmerSubmission>> watchSubmissions() {
    return (db.select(db.farmerSubmissions)
          ..orderBy([(s) => OrderingTerm(expression: s.submissionDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<SubmissionItem>> getSubmissionItems(String submissionId) {
    return (db.select(db.submissionItems)..where((i) => i.submissionId.equals(submissionId))).get();
  }

  Future<String> createSubmission({
    required String farmerId,
    required List<Map<String, dynamic>> items, // commodityId, grossWeight, tareWeight
    String? notes,
  }) async {
    return await db.transaction(() async {
      final submissionId = _uuid.v4();
      final transactionNumber = IdGenerator.submissionId();
      final now = DateTime.now();

      double totalGross = 0.0;
      double totalTare = 0.0;
      double totalNet = 0.0;

      for (final it in items) {
        final gross = (it['grossWeight'] as num).toDouble();
        final tare = (it['tareWeight'] as num).toDouble();
        final net = BusinessCalculator.calculateNetWeight(gross, tare);

        totalGross += gross;
        totalTare += tare;
        totalNet += net;
      }

      // 1. Catat Induk FarmerSubmissions terlebih dahulu untuk integritas referensi ForeignKey
      await db.into(db.farmerSubmissions).insert(
        FarmerSubmissionsCompanion.insert(
          id: submissionId,
          transactionNumber: transactionNumber,
          farmerId: farmerId,
          submissionDate: Value(now),
          notes: Value(notes),
          status: const Value('MENUNGGU_SORTIR'),
          totalGrossWeight: Value(totalGross),
          totalTareWeight: Value(totalTare),
          totalNetWeight: Value(totalNet),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 2. Catat Rincian Anak SubmissionItems
      for (final it in items) {
        final gross = (it['grossWeight'] as num).toDouble();
        final tare = (it['tareWeight'] as num).toDouble();
        final net = BusinessCalculator.calculateNetWeight(gross, tare);

        await db.into(db.submissionItems).insert(
          SubmissionItemsCompanion.insert(
            id: _uuid.v4(),
            submissionId: submissionId,
            commodityId: it['commodityId'] as String,
            grossWeight: gross,
            tareWeight: tare,
            netWeight: net,
            status: const Value('MENUNGGU_SORTIR'),
            createdAt: Value(now),
          ),
        );
      }

      // Audit Log
      await db.into(db.auditLogs).insert(
        AuditLogsCompanion.insert(
          id: _uuid.v4(),
          entityType: 'SUBMISSION',
          entityId: submissionId,
          action: 'CREATE',
          afterValue: Value('No: $transactionNumber, Net: $totalNet kg'),
          reason: const Value('Pencatatan setoran panen masuk'),
          timestamp: Value(now),
        ),
      );

      return transactionNumber;
    });
  }

  // ---------------------------------------------------------
  // 5. SORTIR & GRADING REKONSILIASI
  // ---------------------------------------------------------
  Stream<List<SubmissionItem>> watchPendingGradingItems() {
    return (db.select(db.submissionItems)
          ..where((i) => i.status.equals('MENUNGGU_SORTIR'))
          ..orderBy([(i) => OrderingTerm(expression: i.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<void> submitGrading({
    required String submissionItemId,
    required String pricingMode, // 'TUNGGAL' or 'GRADING'
    required double gradeAWeight,
    required double gradeBWeight,
    required double gradeCWeight,
    required double damagedWeight,
    required double tolerancePercent,
    String? diffReason,
    String? notes,
  }) async {
    await db.transaction(() async {
      final now = DateTime.now();
      final item = await (db.select(db.submissionItems)..where((i) => i.id.equals(submissionItemId))).getSingle();
      final submission = await (db.select(db.farmerSubmissions)..where((s) => s.id.equals(item.submissionId))).getSingle();

      final recon = BusinessCalculator.reconcileGrading(
        incomingNetWeight: item.netWeight,
        gradeAWeight: gradeAWeight,
        gradeBWeight: gradeBWeight,
        gradeCWeight: gradeCWeight,
        damagedWeight: damagedWeight,
        tolerancePercent: tolerancePercent,
      );

      final gradingId = _uuid.v4();
      await db.into(db.gradingRecords).insert(
        GradingRecordsCompanion.insert(
          id: gradingId,
          submissionId: item.submissionId,
          submissionItemId: item.id,
          farmerId: submission.farmerId,
          commodityId: item.commodityId,
          gradingDate: Value(now),
          incomingNetWeight: item.netWeight,
          pricingMode: Value(pricingMode),
          tolerancePercent: Value(tolerancePercent),
          gradeAWeight: Value(gradeAWeight),
          gradeBWeight: Value(gradeBWeight),
          gradeCWeight: Value(gradeCWeight),
          damagedWeight: Value(damagedWeight),
          unexplainedDiffWeight: Value(recon.unexplainedDiffWeight),
          diffReason: Value(diffReason),
          notes: Value(notes),
          createdAt: Value(now),
        ),
      );

      // Update status submission item
      await (db.update(db.submissionItems)..where((i) => i.id.equals(submissionItemId))).write(
        const SubmissionItemsCompanion(status: Value('SELESAI_SORTIR')),
      );

      // Check if all items in submission are graded
      final remainingPending = await (db.select(db.submissionItems)
            ..where((i) => i.submissionId.equals(item.submissionId) & i.status.equals('MENUNGGU_SORTIR')))
          .get();

      final submissionStatus = remainingPending.isEmpty ? 'SELESAI_SORTIR' : 'SEBAGIAN_SORTIR';
      await (db.update(db.farmerSubmissions)..where((s) => s.id.equals(item.submissionId))).write(
        FarmerSubmissionsCompanion(status: Value(submissionStatus), updatedAt: Value(now)),
      );

      // Audit Log
      await db.into(db.auditLogs).insert(
        AuditLogsCompanion.insert(
          id: _uuid.v4(),
          entityType: 'GRADING',
          entityId: gradingId,
          action: 'CREATE',
          afterValue: Value('A: $gradeAWeight, B: $gradeBWeight, C: $gradeCWeight, Selisih: ${recon.unexplainedDiffWeight} kg'),
          reason: Value(diffReason ?? 'Sortir dan grading selesai'),
          timestamp: Value(now),
        ),
      );
    });
  }

  // ---------------------------------------------------------
  // 6. PENGIRIMAN PASAR (SHIPMENT) & ALOKASI SUMBER
  // ---------------------------------------------------------
  Stream<List<Shipment>> watchShipments() {
    return (db.select(db.shipments)
          ..orderBy([(s) => OrderingTerm(expression: s.shipmentDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<ShipmentItem>> getAvailableShipmentItems(String shipmentId) {
    return (db.select(db.shipmentItems)
          ..where((i) => i.shipmentId.equals(shipmentId) & i.remainingWeight.isBiggerThanValue(0.0)))
        .get();
  }

  Future<List<BuyerReceivable>> getUnpaidBuyerReceivables(String buyerId) {
    return (db.select(db.buyerReceivables)
          ..where((r) => r.buyerId.equals(buyerId) & r.remainingAmount.isBiggerThanValue(0.0)))
        .get();
  }

  Future<List<FarmerPayable>> getUnpaidFarmerPayables(String farmerId) {
    return (db.select(db.farmerPayables)
          ..where((p) => p.farmerId.equals(farmerId) & p.remainingAmount.isBiggerThanValue(0.0)))
        .get();
  }

  Future<List<FarmerPayment>> getUnlinkedFarmerPayments(String farmerId) {
    return (db.select(db.farmerPayments)
          ..where((p) => p.farmerId.equals(farmerId) & p.payableId.isNull()))
        .get();
  }

  Future<List<Sale>> getSalesInDateRange(DateTime start, DateTime end) {
    return (db.select(db.sales)
          ..where((s) => s.saleDate.isBiggerOrEqualValue(start) & s.saleDate.isSmallerOrEqualValue(end)))
        .get();
  }

  Future<List<Expense>> getExpensesInDateRange(DateTime start, DateTime end) {
    return (db.select(db.expenses)
          ..where((e) => e.expenseDate.isBiggerOrEqualValue(start) & e.expenseDate.isSmallerOrEqualValue(end)))
        .get();
  }

  Future<String> createShipment({
    required String destinationMarket,
    String? driverName,
    String? vehicleNumber,
    String? notes,
    required List<Map<String, dynamic>> items, 
    // each item: commodityId, grade, totalWeight, allocations: [ {submissionItemId, farmerId, weight} ]
  }) async {
    return await db.transaction(() async {
      final shipmentId = _uuid.v4();
      final shipmentNumber = IdGenerator.shipmentId();
      final now = DateTime.now();

      double totalShipmentWeight = 0.0;
      for (final it in items) {
        final weight = (it['totalWeight'] as num).toDouble();
        totalShipmentWeight += weight;
      }

      // 1. Catat Induk Shipments terlebih dahulu agar integritas ForeignKey shipmentItems terpenuhi
      await db.into(db.shipments).insert(
        ShipmentsCompanion.insert(
          id: shipmentId,
          shipmentNumber: shipmentNumber,
          shipmentDate: Value(now),
          destinationMarket: Value(destinationMarket),
          driverName: Value(driverName),
          vehicleNumber: Value(vehicleNumber),
          notes: Value(notes),
          status: const Value('SIAP_KIRIM'),
          totalWeight: Value(totalShipmentWeight),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 2. Catat Rincian Anak ShipmentItems dan Alokasi
      for (final it in items) {
        final weight = (it['totalWeight'] as num).toDouble();
        final shipmentItemId = _uuid.v4();
        await db.into(db.shipmentItems).insert(
          ShipmentItemsCompanion.insert(
            id: shipmentItemId,
            shipmentId: shipmentId,
            commodityId: it['commodityId'] as String,
            grade: it['grade'] as String,
            initialWeight: weight,
            soldWeight: const Value(0.0),
            remainingWeight: weight,
            status: const Value('BELUM_TERJUAL'),
            createdAt: Value(now),
          ),
        );

        // Record Many-to-Many Allocations from Farmers
        final allocations = it['allocations'] as List<Map<String, dynamic>>? ?? [];
        for (final alloc in allocations) {
          await db.into(db.shipmentAllocations).insert(
            ShipmentAllocationsCompanion.insert(
              id: _uuid.v4(),
              shipmentItemId: shipmentItemId,
              submissionItemId: alloc['submissionItemId'] as String,
              farmerId: alloc['farmerId'] as String,
              allocatedWeight: (alloc['weight'] as num).toDouble(),
              createdAt: Value(now),
            ),
          );
        }
      }

      return shipmentNumber;
    });
  }

  // ---------------------------------------------------------
  // 7. PENJUALAN PASAR & ALOKASI OTOMATIS KE PETANI
  // ---------------------------------------------------------
  Stream<List<Sale>> watchSales() {
    return (db.select(db.sales)
          ..orderBy([(s) => OrderingTerm(expression: s.saleDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<SaleItem>> getSaleItems(String saleId) {
    return (db.select(db.saleItems)..where((i) => i.saleId.equals(saleId))).get();
  }

  Future<List<FarmerSubmission>> getFarmerSubmissions(String farmerId) {
    return (db.select(db.farmerSubmissions)
          ..where((s) => s.farmerId.equals(farmerId))
          ..orderBy([(s) => OrderingTerm(expression: s.submissionDate, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<FarmerPayment>> getFarmerPayments(String farmerId) {
    return (db.select(db.farmerPayments)
          ..where((p) => p.farmerId.equals(farmerId))
          ..orderBy([(p) => OrderingTerm(expression: p.paymentDate, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<FarmerPriceDetermination>> getFarmerPriceDeterminations(String farmerId) {
    return (db.select(db.farmerPriceDeterminations)
          ..where((p) => p.farmerId.equals(farmerId))
          ..orderBy([(p) => OrderingTerm(expression: p.determinedAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<Sale>> getBuyerSales(String buyerId) {
    return (db.select(db.sales)
          ..where((s) => s.buyerId.equals(buyerId))
          ..orderBy([(s) => OrderingTerm(expression: s.saleDate, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<BuyerPayment>> getBuyerPayments(String buyerId) {
    return (db.select(db.buyerPayments)
          ..where((p) => p.buyerId.equals(buyerId))
          ..orderBy([(p) => OrderingTerm(expression: p.paymentDate, mode: OrderingMode.desc)]))
        .get();
  }

  Future<String> recordSale({
    required String shipmentId,
    required String buyerId,
    required String paymentType, // 'TUNAI' or 'TEMPO'
    required double paidAmount,
    String? notes,
    required List<Map<String, dynamic>> items, 
    // each item: shipmentItemId, commodityId, grade, weight, pricePerKg
  }) async {
    return await db.transaction(() async {
      final saleId = _uuid.v4();
      final invoiceNumber = IdGenerator.saleId();
      final now = DateTime.now();

      double totalAmount = 0.0;
      for (final it in items) {
        final weight = (it['weight'] as num).toDouble();
        final price = (it['pricePerKg'] as num).toDouble();
        totalAmount += (weight * price);
      }

      final remainingReceivable = BusinessCalculator.calculateRemainingBalance(totalAmount, paidAmount);
      final saleStatus = remainingReceivable <= 0 ? 'LUNAS' : 'BELUM_LUNAS';

      // 1. Catat Induk Sales terlebih dahulu untuk integritas referensi ForeignKey saleItems
      await db.into(db.sales).insert(
        SalesCompanion.insert(
          id: saleId,
          invoiceNumber: invoiceNumber,
          shipmentId: shipmentId,
          buyerId: buyerId,
          saleDate: Value(now),
          totalAmount: totalAmount,
          paidAmount: Value(paidAmount),
          remainingAmount: remainingReceivable,
          paymentType: Value(paymentType),
          status: Value(saleStatus),
          notes: Value(notes),
          createdAt: Value(now),
        ),
      );

      // 2. Catat Rincian Anak SaleItems & Alokasi
      for (final it in items) {
        final weight = (it['weight'] as num).toDouble();
        final price = (it['pricePerKg'] as num).toDouble();
        final subtotal = weight * price;

        final saleItemId = _uuid.v4();
        await db.into(db.saleItems).insert(
          SaleItemsCompanion.insert(
            id: saleItemId,
            saleId: saleId,
            shipmentItemId: it['shipmentItemId'] as String,
            commodityId: it['commodityId'] as String,
            grade: it['grade'] as String,
            weight: weight,
            pricePerKg: price,
            subtotal: subtotal,
            createdAt: Value(now),
          ),
        );

        // Update ShipmentItem remaining & sold weight
        final shipItem = await (db.select(db.shipmentItems)..where((s) => s.id.equals(it['shipmentItemId'] as String))).getSingle();
        final newSoldWeight = shipItem.soldWeight + weight;
        final newRemaining = shipItem.initialWeight - newSoldWeight;
        final newStatus = newRemaining <= 0 ? 'TERJUAL_LENGKAP' : 'TERJUAL_SEBAGIAN';

        await (db.update(db.shipmentItems)..where((s) => s.id.equals(shipItem.id))).write(
          ShipmentItemsCompanion(
            soldWeight: Value(newSoldWeight),
            remainingWeight: Value(newRemaining < 0 ? 0.0 : newRemaining),
            status: Value(newStatus),
          ),
        );

        // Alokasi Otomatis ke Petani Sumber Berdasarkan Kontribusi Bobot
        final allocations = await (db.select(db.shipmentAllocations)
              ..where((a) => a.shipmentItemId.equals(shipItem.id)))
            .get();

        final totalSourceWeight = shipItem.initialWeight;
        for (final alloc in allocations) {
          final allocatedWeight = BusinessCalculator.allocateProportionalWeight(
            farmerSourceWeight: alloc.allocatedWeight,
            totalSourceWeight: totalSourceWeight,
            totalSoldWeight: weight,
          );
          final allocatedRevenue = allocatedWeight * price;

          await db.into(db.saleAllocations).insert(
            SaleAllocationsCompanion.insert(
              id: _uuid.v4(),
              saleItemId: saleItemId,
              farmerId: alloc.farmerId,
              submissionItemId: alloc.submissionItemId,
              allocatedWeight: allocatedWeight,
              allocatedRevenue: allocatedRevenue,
              isManualAdjusted: const Value(false),
              createdAt: Value(now),
            ),
          );
        }
      }

      // Jika ada uang tunai dibayarkan saat penjualan -> Masuk Buku Kas
      if (paidAmount > 0) {
        await _recordCashTransaction(
          type: 'KAS_MASUK',
          category: 'PENJUALAN_TUNAI',
          referenceId: invoiceNumber,
          amount: paidAmount,
          notes: 'Penerimaan tunai nota $invoiceNumber',
        );
      }

      // Jika ada sisa piutang -> Catat BuyerReceivable
      if (remainingReceivable > 0) {
        await db.into(db.buyerReceivables).insert(
          BuyerReceivablesCompanion.insert(
            id: _uuid.v4(),
            buyerId: buyerId,
            saleId: saleId,
            totalAmount: totalAmount,
            paidAmount: Value(paidAmount),
            remainingAmount: remainingReceivable,
            status: const Value('BELUM_LUNAS'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      return invoiceNumber;
    });
  }

  // ---------------------------------------------------------
  // 8. PENENTUAN HARGA PETANI & PEMBAYARAN PETANI
  // ---------------------------------------------------------
  Future<void> determineFarmerPrice({
    required String submissionId,
    required String submissionItemId,
    required String farmerId,
    required String commodityId,
    required String pricingMode, // 'TUNGGAL' or 'GRADING'
    required String pricingBasis, // 'BERAT_BERSIH_AWAL' or 'BERAT_SORTIR'
    double singlePrice = 0.0,
    double gradeAPrice = 0.0,
    double gradeBPrice = 0.0,
    double gradeCPrice = 0.0,
    double damageDeduction = 0.0,
    String? notes,
  }) async {
    await db.transaction(() async {
      final now = DateTime.now();
      final item = await (db.select(db.submissionItems)..where((i) => i.id.equals(submissionItemId))).getSingle();
      final gradings = await (db.select(db.gradingRecords)..where((g) => g.submissionItemId.equals(submissionItemId))).get();

      final gradeA = gradings.isNotEmpty ? gradings.first.gradeAWeight : 0.0;
      final gradeB = gradings.isNotEmpty ? gradings.first.gradeBWeight : 0.0;
      final gradeC = gradings.isNotEmpty ? gradings.first.gradeCWeight : 0.0;

      final netPayable = BusinessCalculator.calculateFarmerPayableAmount(
        mode: pricingMode,
        basis: pricingBasis,
        initialNetWeight: item.netWeight,
        gradeAWeight: gradeA,
        gradeBWeight: gradeB,
        gradeCWeight: gradeC,
        singlePrice: singlePrice,
        gradeAPrice: gradeAPrice,
        gradeBPrice: gradeBPrice,
        gradeCPrice: gradeCPrice,
        damageDeduction: damageDeduction,
      );

      final detId = _uuid.v4();
      await db.into(db.farmerPriceDeterminations).insert(
        FarmerPriceDeterminationsCompanion.insert(
          id: detId,
          submissionId: submissionId,
          submissionItemId: submissionItemId,
          farmerId: farmerId,
          commodityId: commodityId,
          pricingBasis: Value(pricingBasis),
          pricingMode: Value(pricingMode),
          singlePrice: Value(singlePrice),
          gradeAPrice: Value(gradeAPrice),
          gradeBPrice: Value(gradeBPrice),
          gradeCPrice: Value(gradeCPrice),
          totalFarmerAmount: netPayable + damageDeduction,
          damageDeduction: Value(damageDeduction),
          netFarmerAmount: netPayable,
          isFinalized: const Value(true),
          determinedAt: Value(now),
          notes: Value(notes),
          createdAt: Value(now),
        ),
      );

      // Create or update FarmerPayable
      final existingPayable = await (db.select(db.farmerPayables)
            ..where((p) => p.submissionId.equals(submissionId)))
          .getSingleOrNull();

      if (existingPayable == null) {
        // Cek apakah ada pembayaran sebelumnya yang belum ditautkan untuk petani ini
        final unlinkedPayments = await (db.select(db.farmerPayments)
              ..where((p) => p.farmerId.equals(farmerId) & p.payableId.isNull()))
            .get();

        double unlinkedPaid = 0.0;
        final payableId = _uuid.v4();
        for (final p in unlinkedPayments) {
          unlinkedPaid += p.amount;
          await (db.update(db.farmerPayments)..where((item) => item.id.equals(p.id))).write(
            FarmerPaymentsCompanion(payableId: Value(payableId)),
          );
        }

        final remaining = netPayable - unlinkedPaid;
        final status = remaining <= 0 ? 'LUNAS' : (unlinkedPaid > 0 ? 'DIBAYAR_SEBAGIAN' : 'BELUM_LUNAS');

        await db.into(db.farmerPayables).insert(
          FarmerPayablesCompanion.insert(
            id: payableId,
            farmerId: farmerId,
            submissionId: submissionId,
            totalAmount: netPayable,
            paidAmount: Value(unlinkedPaid),
            remainingAmount: remaining < 0 ? 0.0 : remaining,
            status: Value(status),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      } else {
        final newTotal = existingPayable.totalAmount + netPayable;
        final newRemaining = newTotal - existingPayable.paidAmount;
        final status = newRemaining <= 0 ? 'LUNAS' : (existingPayable.paidAmount > 0 ? 'DIBAYAR_SEBAGIAN' : 'BELUM_LUNAS');
        await (db.update(db.farmerPayables)..where((p) => p.id.equals(existingPayable.id))).write(
          FarmerPayablesCompanion(
            totalAmount: Value(newTotal),
            remainingAmount: Value(newRemaining < 0 ? 0.0 : newRemaining),
            status: Value(status),
            updatedAt: Value(now),
          ),
        );
      }

      // Perbarui status setoran menjadi HARGA_DITENTUKAN
      await (db.update(db.farmerSubmissions)..where((s) => s.id.equals(submissionId))).write(
        const FarmerSubmissionsCompanion(status: Value('HARGA_DITENTUKAN')),
      );
    });
  }

  /// Ringkasan Harga Jual Pasar untuk Komoditas Tertentu
  Future<Map<String, dynamic>> getMarketSalesSummaryForCommodity({
    required String commodityId,
    String? grade,
  }) async {
    var query = db.select(db.saleItems)..where((s) => s.commodityId.equals(commodityId));
    if (grade != null && grade.isNotEmpty && grade != 'Semua' && grade != 'Campur') {
      query = query..where((s) => s.grade.equals(grade));
    }
    final items = await (query..orderBy([(s) => OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc)])).get();

    if (items.isEmpty) {
      return {
        'hasSales': false,
        'totalSoldWeight': 0.0,
        'totalRevenue': 0.0,
        'weightedAveragePrice': 0.0,
        'minPrice': 0.0,
        'maxPrice': 0.0,
        'salesCount': 0,
        'salesBreakdown': <Map<String, dynamic>>[],
      };
    }

    double totalWeight = 0.0;
    double totalRevenue = 0.0;
    double minPrice = double.infinity;
    double maxPrice = 0.0;
    final breakdown = <Map<String, dynamic>>[];

    for (final it in items) {
      totalWeight += it.weight;
      totalRevenue += it.subtotal;
      if (it.pricePerKg < minPrice) minPrice = it.pricePerKg;
      if (it.pricePerKg > maxPrice) maxPrice = it.pricePerKg;

      final sale = await (db.select(db.sales)..where((s) => s.id.equals(it.saleId))).getSingleOrNull();
      String buyerName = 'Pasar Induk';
      if (sale != null) {
        final buyer = await (db.select(db.buyers)..where((b) => b.id.equals(sale.buyerId))).getSingleOrNull();
        if (buyer != null) buyerName = buyer.name;
      }

      breakdown.add({
        'invoiceNumber': sale?.invoiceNumber ?? '-',
        'date': sale?.saleDate ?? it.createdAt,
        'buyerName': buyerName,
        'grade': it.grade,
        'weight': it.weight,
        'pricePerKg': it.pricePerKg,
        'subtotal': it.subtotal,
      });
    }

    final avgPrice = totalWeight > 0 ? (totalRevenue / totalWeight) : 0.0;

    return {
      'hasSales': true,
      'totalSoldWeight': totalWeight,
      'totalRevenue': totalRevenue,
      'weightedAveragePrice': double.parse(avgPrice.toStringAsFixed(2)),
      'minPrice': minPrice == double.infinity ? 0.0 : minPrice,
      'maxPrice': maxPrice,
      'isMultiplePrices': minPrice != maxPrice && items.length > 1,
      'salesCount': items.length,
      'salesBreakdown': breakdown,
    };
  }

  /// Ambil Seluruh Setoran Petani beserta Rincian Sayur & Harga Jual Pasar
  Future<List<Map<String, dynamic>>> getFarmerSubmissionsWithDetails(String farmerId) async {
    final submissions = await (db.select(db.farmerSubmissions)
          ..where((s) => s.farmerId.equals(farmerId))
          ..orderBy([(s) => OrderingTerm(expression: s.submissionDate, mode: OrderingMode.desc)]))
        .get();

    final result = <Map<String, dynamic>>[];

    for (final sub in submissions) {
      final items = await getSubmissionItems(sub.id);
      final determinations = await (db.select(db.farmerPriceDeterminations)
            ..where((d) => d.submissionId.equals(sub.id)))
          .get();

      final itemsWithDetails = <Map<String, dynamic>>[];
      double subTotalHak = 0.0;
      bool allItemsDetermined = items.isNotEmpty;

      for (final it in items) {
        final comm = await (db.select(db.commodities)..where((c) => c.id.equals(it.commodityId))).getSingleOrNull();
        final det = determinations.where((d) => d.submissionItemId == it.id).firstOrNull;

        if (det != null) {
          subTotalHak += det.netFarmerAmount;
        } else {
          allItemsDetermined = false;
        }

        // Ambil hasil sortir jika ada
        final gradings = await (db.select(db.gradingRecords)..where((g) => g.submissionItemId.equals(it.id))).get();
        final grading = gradings.firstOrNull;

        // Ambil data penjualan aktual komoditas ini di pasar
        final marketSummary = await getMarketSalesSummaryForCommodity(
          commodityId: it.commodityId,
          grade: grading != null ? 'Grade A' : null,
        );

        itemsWithDetails.add({
          'item': it,
          'commodityName': comm?.name ?? 'Sayuran',
          'commodityId': it.commodityId,
          'netWeight': it.netWeight,
          'grading': grading,
          'isDetermined': det != null,
          'determination': det,
          'netFarmerAmount': det?.netFarmerAmount ?? 0.0,
          'singlePrice': det?.singlePrice ?? 0.0,
          'marketSummary': marketSummary,
        });
      }

      final payable = await (db.select(db.farmerPayables)
            ..where((p) => p.submissionId.equals(sub.id)))
          .getSingleOrNull();

      result.add({
        'submission': sub,
        'items': itemsWithDetails,
        'totalHak': subTotalHak,
        'isFullyDetermined': allItemsDetermined,
        'payable': payable,
      });
    }

    return result;
  }

  // Pembayaran Tunai Petani
  Future<String> payFarmer({
    required String farmerId,
    String? payableId,
    required double amount,
    String? notes,
  }) async {
    return await db.transaction(() async {
      final paymentNumber = IdGenerator.farmerPaymentId();
      final now = DateTime.now();

      await db.into(db.farmerPayments).insert(
        FarmerPaymentsCompanion.insert(
          id: _uuid.v4(),
          paymentNumber: paymentNumber,
          farmerId: farmerId,
          payableId: Value(payableId),
          paymentDate: Value(now),
          amount: amount,
          notes: Value(notes),
          createdAt: Value(now),
        ),
      );

      // Deduct payable
      if (payableId != null) {
        final payable = await (db.select(db.farmerPayables)..where((p) => p.id.equals(payableId))).getSingle();
        final newPaid = payable.paidAmount + amount;
        final newRemaining = payable.totalAmount - newPaid;
        final newStatus = newRemaining <= 0 ? 'LUNAS' : 'SEBAGIAN';

        await (db.update(db.farmerPayables)..where((p) => p.id.equals(payableId))).write(
          FarmerPayablesCompanion(
            paidAmount: Value(newPaid),
            remainingAmount: Value(newRemaining < 0 ? 0.0 : newRemaining),
            status: Value(newStatus),
            updatedAt: Value(now),
          ),
        );
      }

      // Catat Kas Keluar
      await _recordCashTransaction(
        type: 'KAS_KELUAR',
        category: 'PEMBAYARAN_PETANI',
        referenceId: paymentNumber,
        amount: amount,
        notes: 'Pembayaran petani $paymentNumber',
      );

      return paymentNumber;
    });
  }

  // ---------------------------------------------------------
  // 9. PIUTANG PEMBELI & PEMBAYARAN PIUTANG
  // ---------------------------------------------------------
  Stream<List<BuyerReceivable>> watchBuyerReceivables() {
    return (db.select(db.buyerReceivables)
          ..where((r) => r.remainingAmount.isBiggerThanValue(0.0))
          ..orderBy([(r) => OrderingTerm(expression: r.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<String> receiveBuyerPayment({
    required String buyerId,
    String? receivableId,
    required double amount,
    String? notes,
  }) async {
    return await db.transaction(() async {
      final receiptNumber = IdGenerator.buyerPaymentId();
      final now = DateTime.now();

      await db.into(db.buyerPayments).insert(
        BuyerPaymentsCompanion.insert(
          id: _uuid.v4(),
          receiptNumber: receiptNumber,
          buyerId: buyerId,
          receivableId: Value(receivableId),
          paymentDate: Value(now),
          amount: amount,
          notes: Value(notes),
          createdAt: Value(now),
        ),
      );

      // Deduct receivable
      if (receivableId != null) {
        final rec = await (db.select(db.buyerReceivables)..where((r) => r.id.equals(receivableId))).getSingle();
        final newPaid = rec.paidAmount + amount;
        final newRemaining = rec.totalAmount - newPaid;
        final newStatus = newRemaining <= 0 ? 'LUNAS' : 'SEBAGIAN';

        await (db.update(db.buyerReceivables)..where((r) => r.id.equals(receivableId))).write(
          BuyerReceivablesCompanion(
            paidAmount: Value(newPaid),
            remainingAmount: Value(newRemaining < 0 ? 0.0 : newRemaining),
            status: Value(newStatus),
            updatedAt: Value(now),
          ),
        );
      }

      // Catat Kas Masuk
      await _recordCashTransaction(
        type: 'KAS_MASUK',
        category: 'PIUTANG_PEMBELI',
        referenceId: receiptNumber,
        amount: amount,
        notes: 'Penerimaan piutang pembeli $receiptNumber',
      );

      return receiptNumber;
    });
  }

  // ---------------------------------------------------------
  // 10. PENGELUARAN & BUKU KAS
  // ---------------------------------------------------------
  Future<String> recordExpense({
    required double amount,
    String? category,
    String? notes,
    bool isPackaging = false,
  }) async {
    return await db.transaction(() async {
      final expenseNumber = IdGenerator.expenseId();
      final now = DateTime.now();

      await db.into(db.expenses).insert(
        ExpensesCompanion.insert(
          id: _uuid.v4(),
          expenseNumber: expenseNumber,
          amount: amount,
          category: Value(category),
          notes: Value(notes),
          isPackagingExpense: Value(isPackaging),
          expenseDate: Value(now),
          createdAt: Value(now),
        ),
      );

      // Catat Kas Keluar
      await _recordCashTransaction(
        type: 'KAS_KELUAR',
        category: isPackaging ? 'BIAYA_KEMASAN' : 'PENGELUARAN',
        referenceId: expenseNumber,
        amount: amount,
        notes: notes ?? 'Pengeluaran operasional $expenseNumber',
      );

      return expenseNumber;
    });
  }

  Stream<List<CashTransaction>> watchCashTransactions() {
    return (db.select(db.cashTransactions)
          ..orderBy([(c) => OrderingTerm(expression: c.transactionDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<double> getCurrentCashBalance() async {
    final lastTx = await (db.select(db.cashTransactions)
          ..orderBy([(c) => OrderingTerm(expression: c.transactionDate, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();

    return lastTx?.balanceAfter ?? 0.0;
  }

  Future<void> _recordCashTransaction({
    required String type, // 'KAS_MASUK' or 'KAS_KELUAR'
    required String category,
    required String referenceId,
    required double amount,
    String? notes,
  }) async {
    final currentBal = await getCurrentCashBalance();
    final newBal = type == 'KAS_MASUK' ? currentBal + amount : currentBal - amount;
    final now = DateTime.now();

    await db.into(db.cashTransactions).insert(
      CashTransactionsCompanion.insert(
        id: _uuid.v4(),
        transactionNumber: IdGenerator.generate('CSH'),
        type: type,
        category: category,
        referenceId: Value(referenceId),
        amount: amount,
        balanceAfter: newBal,
        transactionDate: Value(now),
        notes: Value(notes),
        createdAt: Value(now),
      ),
    );
  }

  // Tutup Kas Harian
  Future<String> recordDailyCashClosing({
    required double physicalCash,
    String? notes,
  }) async {
    final systemBal = await getCurrentCashBalance();
    final diff = physicalCash - systemBal;
    final closingNumber = IdGenerator.closingId();
    final now = DateTime.now();

    await db.into(db.dailyCashClosings).insert(
      DailyCashClosingsCompanion.insert(
        id: _uuid.v4(),
        closingNumber: closingNumber,
        closingDate: Value(now),
        systemBalance: systemBal,
        physicalCash: physicalCash,
        difference: diff,
        notes: Value(notes),
        createdAt: Value(now),
      ),
    );

    return closingNumber;
  }

  // ---------------------------------------------------------
  // 11. LAPORAN KEUANGAN & LABA BERSIH
  // ---------------------------------------------------------
  Future<FinancialResult> getFinancialReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 1. Omzet
    final sales = await (db.select(db.sales)
          ..where((s) => s.saleDate.isBiggerOrEqualValue(startDate) & s.saleDate.isSmallerOrEqualValue(endDate)))
        .get();

    double totalOmzet = 0.0;
    for (final s in sales) {
      totalOmzet += s.totalAmount;
    }

    // 2. Hak Petani
    final prices = await (db.select(db.farmerPriceDeterminations)
          ..where((p) => p.determinedAt.isBiggerOrEqualValue(startDate) & p.determinedAt.isSmallerOrEqualValue(endDate)))
        .get();

    double totalHakPetani = 0.0;
    for (final p in prices) {
      totalHakPetani += p.netFarmerAmount;
    }

    // 3. Kerugian Kerusakan ditanggung Pemilik
    final damages = await (db.select(db.damageRecords)
          ..where((d) => d.recordedAt.isBiggerOrEqualValue(startDate) & d.recordedAt.isSmallerOrEqualValue(endDate)))
        .get();

    double ownerDamageLoss = 0.0;
    for (final d in damages) {
      ownerDamageLoss += d.ownerShareNominal;
    }

    // 4. Pengeluaran Operasional & Kemasan
    final expenses = await (db.select(db.expenses)
          ..where((e) => e.expenseDate.isBiggerOrEqualValue(startDate) & e.expenseDate.isSmallerOrEqualValue(endDate)))
        .get();

    double opExpenses = 0.0;
    double packExpenses = 0.0;
    for (final e in expenses) {
      if (e.isPackagingExpense) {
        packExpenses += e.amount;
      } else {
        opExpenses += e.amount;
      }
    }

    return BusinessCalculator.calculateFinancials(
      totalOmzet: totalOmzet,
      totalHakPetani: totalHakPetani,
      ownerDamageLoss: ownerDamageLoss,
      operationalExpenses: opExpenses,
      packagingExpenses: packExpenses,
    );
  }

  // ---------------------------------------------------------
  // 12. PROFIL BISNIS
  // ---------------------------------------------------------
  Future<BusinessProfile?> getBusinessProfile() async {
    final list = await db.select(db.businessProfiles).get();
    return list.isNotEmpty ? list.first : null;
  }

  Future<void> updateBusinessProfile({
    required String businessName,
    String? ownerName,
    String? phone,
    String? address,
    double defaultTolerance = 2.0,
  }) async {
    final profile = await getBusinessProfile();
    final now = DateTime.now();

    if (profile == null) {
      await db.into(db.businessProfiles).insert(
        BusinessProfilesCompanion.insert(
          id: _uuid.v4(),
          businessName: Value(businessName),
          ownerName: Value(ownerName),
          phone: Value(phone),
          address: Value(address),
          defaultGradingTolerancePercent: Value(defaultTolerance),
          updatedAt: Value(now),
        ),
      );
    } else {
      await (db.update(db.businessProfiles)..where((p) => p.id.equals(profile.id))).write(
        BusinessProfilesCompanion(
          businessName: Value(businessName),
          ownerName: Value(ownerName),
          phone: Value(phone),
          address: Value(address),
          defaultGradingTolerancePercent: Value(defaultTolerance),
          updatedAt: Value(now),
        ),
      );
    }
  }
}
