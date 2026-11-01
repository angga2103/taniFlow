import 'package:drift/drift.dart';

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

class BusinessProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get businessName => text().withDefault(const Constant('Usaha Tani'))();
  TextColumn get ownerName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  RealColumn get defaultGradingTolerancePercent => real().withDefault(const Constant(2.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get eventDate => dateTime()();
  DateTimeColumn get reminderDate => dateTime().nullable()();
  TextColumn get eventType => text().withDefault(const Constant('OPERASIONAL'))(); 
  // OPERASIONAL, JATUH_TEMPO_PETANI, JATUH_TEMPO_PEMBELI, PENGIRIMAN, LAIN_LAIN
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class AuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()(); // SUBMISSION, GRADING, SHIPMENT, SALE, ALLOCATION, PAYMENT, CASH
  TextColumn get entityId => text()();
  TextColumn get action => text()(); // CREATE, UPDATE, DELETE, REVERSAL, ADJUSTMENT
  TextColumn get beforeValue => text().nullable()();
  TextColumn get afterValue => text().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get actor => text().withDefault(const Constant('PEMILIK'))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class BackupHistories extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  IntColumn get fileSize => integer()();
  DateTimeColumn get backupDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get backupType => text().withDefault(const Constant('MANUAL'))(); // MANUAL, OTOMATIS
  BoolColumn get isGoogleDrive => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('SUKSES'))(); // SUKSES, GAGAL
  TextColumn get errorMessage => text().nullable()();
  TextColumn get hashCheck => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class NotificationSettings extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // PETANI_DUE, PEMBELI_DUE, SHIPMENT_ALERT, BACKUP_REMINDER
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(1))();
  TextColumn get remindTime => text().withDefault(const Constant('08:00'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
