import 'package:drift/drift.dart';
import 'master_tables.dart';
import 'operational_tables.dart';
import 'sales_tables.dart';

class FarmerPriceDeterminations extends Table {
  TextColumn get id => text()();
  TextColumn get submissionId => text().references(FarmerSubmissions, #id)();
  TextColumn get submissionItemId => text().references(SubmissionItems, #id)();
  TextColumn get farmerId => text().references(Farmers, #id)();
  TextColumn get commodityId => text().references(Commodities, #id)();
  TextColumn get pricingBasis => text().withDefault(const Constant('BERAT_SORTIR'))(); // BERAT_BERSIH_AWAL or BERAT_SORTIR
  TextColumn get pricingMode => text().withDefault(const Constant('GRADING'))(); // TUNGGAL or GRADING
  RealColumn get avgSellingPrice => real().withDefault(const Constant(0.0))();
  RealColumn get singlePrice => real().withDefault(const Constant(0.0))();
  RealColumn get gradeAPrice => real().withDefault(const Constant(0.0))();
  RealColumn get gradeBPrice => real().withDefault(const Constant(0.0))();
  RealColumn get gradeCPrice => real().withDefault(const Constant(0.0))();
  RealColumn get totalFarmerAmount => real()();
  RealColumn get damageDeduction => real().withDefault(const Constant(0.0))();
  RealColumn get netFarmerAmount => real()(); // totalFarmerAmount - damageDeduction
  BoolColumn get isFinalized => boolean().withDefault(const Constant(true))();
  DateTimeColumn get determinedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class FarmerPayables extends Table {
  TextColumn get id => text()();
  TextColumn get farmerId => text().references(Farmers, #id)();
  TextColumn get submissionId => text().references(FarmerSubmissions, #id)();
  RealColumn get totalAmount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get remainingAmount => real()(); // totalAmount - paidAmount
  TextColumn get status => text().withDefault(const Constant('BELUM_LUNAS'))(); // BELUM_LUNAS, SEBAGIAN, LUNAS
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class FarmerPayments extends Table {
  TextColumn get id => text()();
  TextColumn get paymentNumber => text().unique()(); // BYR-YYYYMMDD-XXXX
  TextColumn get farmerId => text().references(Farmers, #id)();
  TextColumn get payableId => text().nullable().references(FarmerPayables, #id)();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get amount => real()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class BuyerReceivables extends Table {
  TextColumn get id => text()();
  TextColumn get buyerId => text().references(Buyers, #id)();
  TextColumn get saleId => text().references(Sales, #id)();
  RealColumn get totalAmount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get remainingAmount => real()(); // totalAmount - paidAmount
  TextColumn get status => text().withDefault(const Constant('BELUM_LUNAS'))(); // BELUM_LUNAS, SEBAGIAN, LUNAS
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class BuyerPayments extends Table {
  TextColumn get id => text()();
  TextColumn get receiptNumber => text().unique()(); // KWT-YYYYMMDD-XXXX
  TextColumn get buyerId => text().references(Buyers, #id)();
  TextColumn get receivableId => text().nullable().references(BuyerReceivables, #id)();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get amount => real()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get expenseNumber => text().unique()(); // BIA-YYYYMMDD-XXXX
  TextColumn get category => text().nullable()(); // Kemasan, Transportasi, Tenaga Kerja, Operasional, Lainnya
  RealColumn get amount => real()();
  DateTimeColumn get expenseDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  BoolColumn get isPackagingExpense => boolean().withDefault(const Constant(false))();
  TextColumn get relatedPackagingRecordId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class CashTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get transactionNumber => text().unique()();
  TextColumn get type => text()(); // KAS_MASUK or KAS_KELUAR
  TextColumn get category => text()(); // PENJUALAN_TUNAI, PIUTANG_PEMBELI, PEMBAYARAN_PETANI, PENGELUARAN, LAIN_LAIN
  TextColumn get referenceId => text().nullable()();
  RealColumn get amount => real()();
  RealColumn get balanceAfter => real()();
  DateTimeColumn get transactionDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class DailyCashClosings extends Table {
  TextColumn get id => text()();
  TextColumn get closingNumber => text().unique()(); // CLS-YYYYMMDD-XXXX
  DateTimeColumn get closingDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get systemBalance => real()();
  RealColumn get physicalCash => real()();
  RealColumn get difference => real()(); // physicalCash - systemBalance
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
