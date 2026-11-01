import 'package:drift/drift.dart';
import 'master_tables.dart';
import 'operational_tables.dart';

class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text().unique()(); // PJL-YYYYMMDD-XXXX
  TextColumn get shipmentId => text().references(Shipments, #id)();
  TextColumn get buyerId => text().references(Buyers, #id)();
  DateTimeColumn get saleDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalAmount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get remainingAmount => real()(); // totalAmount - paidAmount (Piutang)
  TextColumn get paymentType => text().withDefault(const Constant('TUNAI'))(); // TUNAI, TEMPO
  TextColumn get status => text().withDefault(const Constant('LUNAS'))(); // LUNAS, BELUM_LUNAS
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get shipmentItemId => text().references(ShipmentItems, #id)();
  TextColumn get commodityId => text().references(Commodities, #id)();
  TextColumn get grade => text()();
  RealColumn get weight => real()();
  RealColumn get pricePerKg => real()();
  RealColumn get subtotal => real()(); // weight * pricePerKg
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class SaleAllocations extends Table {
  TextColumn get id => text()();
  TextColumn get saleItemId => text().references(SaleItems, #id)();
  TextColumn get farmerId => text().references(Farmers, #id)();
  TextColumn get submissionItemId => text().references(SubmissionItems, #id)();
  RealColumn get allocatedWeight => real()();
  RealColumn get allocatedRevenue => real()(); // allocatedWeight * pricePerKg
  BoolColumn get isManualAdjusted => boolean().withDefault(const Constant(false))();
  RealColumn get previousWeight => real().nullable()();
  TextColumn get adjustReason => text().nullable()();
  DateTimeColumn get adjustedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
