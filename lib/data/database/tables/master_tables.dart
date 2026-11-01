import 'package:drift/drift.dart';

class Farmers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Buyers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Commodities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get defaultLossTolerancePercent => real().withDefault(const Constant(2.0))(); // Default 2%
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class CommodityUnits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // Kg, Gram, Keranjang, Karung, Ikat, Peti
  TextColumn get symbol => text()(); // kg, g, krj, krg, ikt, pti
  BoolColumn get isDefaultBase => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class UnitConversions extends Table {
  TextColumn get id => text()();
  TextColumn get commodityId => text().references(Commodities, #id)();
  TextColumn get unitId => text().references(CommodityUnits, #id)();
  RealColumn get toKgMultiplier => real()(); // e.g. 1 Keranjang Tomat = 20 kg
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MarketPriceReferences extends Table {
  TextColumn get id => text()();
  TextColumn get commodityId => text().references(Commodities, #id)();
  TextColumn get grade => text()(); // Grade A, Grade B, Grade C, Campur
  RealColumn get pricePerKg => real()();
  DateTimeColumn get recordedDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
