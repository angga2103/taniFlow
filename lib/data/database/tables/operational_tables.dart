import 'package:drift/drift.dart';
import 'master_tables.dart';

class FarmerSubmissions extends Table {
  TextColumn get id => text()();
  TextColumn get transactionNumber => text().unique()(); // STR-YYYYMMDD-XXXX
  TextColumn get farmerId => text().references(Farmers, #id)();
  DateTimeColumn get submissionDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('MENUNGGU_SORTIR'))(); 
  // MENUNGGU_SORTIR, SEBAGIAN_SORTIR, SELESAI_SORTIR, DIBATALKAN
  RealColumn get totalGrossWeight => real().withDefault(const Constant(0.0))();
  RealColumn get totalTareWeight => real().withDefault(const Constant(0.0))();
  RealColumn get totalNetWeight => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class SubmissionItems extends Table {
  TextColumn get id => text()();
  TextColumn get submissionId => text().references(FarmerSubmissions, #id)();
  TextColumn get commodityId => text().references(Commodities, #id)();
  RealColumn get grossWeight => real()();
  RealColumn get tareWeight => real()();
  RealColumn get netWeight => real()(); // grossWeight - tareWeight
  TextColumn get unitId => text().nullable().references(CommodityUnits, #id)();
  RealColumn get unitQuantity => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('MENUNGGU_SORTIR'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class SubmissionPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get submissionId => text().references(FarmerSubmissions, #id)();
  TextColumn get photoPath => text()();
  TextColumn get caption => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class GradingRecords extends Table {
  TextColumn get id => text()();
  TextColumn get submissionId => text().references(FarmerSubmissions, #id)();
  TextColumn get submissionItemId => text().references(SubmissionItems, #id)();
  TextColumn get farmerId => text().references(Farmers, #id)();
  TextColumn get commodityId => text().references(Commodities, #id)();
  DateTimeColumn get gradingDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get incomingNetWeight => real()();
  TextColumn get pricingMode => text().withDefault(const Constant('GRADING'))(); // TUNGGAL or GRADING
  RealColumn get tolerancePercent => real().withDefault(const Constant(2.0))();
  RealColumn get gradeAWeight => real().withDefault(const Constant(0.0))();
  RealColumn get gradeBWeight => real().withDefault(const Constant(0.0))();
  RealColumn get gradeCWeight => real().withDefault(const Constant(0.0))();
  RealColumn get damagedWeight => real().withDefault(const Constant(0.0))();
  RealColumn get unexplainedDiffWeight => real().withDefault(const Constant(0.0))();
  TextColumn get diffReason => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PackagingRecords extends Table {
  TextColumn get id => text()();
  TextColumn get relatedType => text()(); // SUBMISSION or SHIPMENT
  TextColumn get relatedId => text()();
  TextColumn get packagingType => text()(); // Keranjang, Karung, Peti, Plastik
  IntColumn get quantity => integer()();
  RealColumn get unitCost => real()();
  RealColumn get totalCost => real()();
  RealColumn get tareWeightPerUnit => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class DamageRecords extends Table {
  TextColumn get id => text()();
  TextColumn get submissionId => text().references(FarmerSubmissions, #id)();
  TextColumn get farmerId => text().references(Farmers, #id)();
  TextColumn get commodityId => text().references(Commodities, #id)();
  TextColumn get grade => text()(); // Grade A, B, C, Afkir
  RealColumn get damageWeight => real()();
  RealColumn get estimatedLossValue => real().withDefault(const Constant(0.0))();
  TextColumn get responsibleParty => text().withDefault(const Constant('PEMILIK'))(); 
  // PEMILIK, PETANI, BERSAMA, NOMINAL_MANUAL, PERSENTASE_MANUAL
  RealColumn get ownerShareNominal => real().withDefault(const Constant(0.0))();
  RealColumn get farmerShareNominal => real().withDefault(const Constant(0.0))();
  TextColumn get reason => text()();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Shipments extends Table {
  TextColumn get id => text()();
  TextColumn get shipmentNumber => text().unique()(); // KRM-YYYYMMDD-XXXX
  DateTimeColumn get shipmentDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get driverName => text().nullable()();
  TextColumn get vehicleNumber => text().nullable()();
  TextColumn get destinationMarket => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('SIAP_KIRIM'))(); 
  // SIAP_KIRIM, TERKIRIM, TERJUAL_SEBAGIAN, SELESAI
  RealColumn get totalWeight => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ShipmentItems extends Table {
  TextColumn get id => text()();
  TextColumn get shipmentId => text().references(Shipments, #id)();
  TextColumn get commodityId => text().references(Commodities, #id)();
  TextColumn get grade => text()(); // Grade A, Grade B, Grade C, Campur
  RealColumn get initialWeight => real()();
  RealColumn get soldWeight => real().withDefault(const Constant(0.0))();
  RealColumn get remainingWeight => real()(); // initialWeight - soldWeight
  RealColumn get discountedSoldWeight => real().withDefault(const Constant(0.0))();
  RealColumn get discardedWeight => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('BELUM_TERJUAL'))(); 
  // BELUM_TERJUAL, TERJUAL_SEBAGIAN, TERJUAL_LENGKAP, SELESAI_DENGAN_SISA_RUSAK
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ShipmentAllocations extends Table {
  TextColumn get id => text()();
  TextColumn get shipmentItemId => text().references(ShipmentItems, #id)();
  TextColumn get submissionItemId => text().references(SubmissionItems, #id)();
  TextColumn get farmerId => text().references(Farmers, #id)();
  RealColumn get allocatedWeight => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
