import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'tables/master_tables.dart';
import 'tables/operational_tables.dart';
import 'tables/sales_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/system_tables.dart';
import 'connection/native.dart' as conn;

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Farmers,
  Buyers,
  Commodities,
  CommodityUnits,
  UnitConversions,
  MarketPriceReferences,
  FarmerSubmissions,
  SubmissionItems,
  SubmissionPhotos,
  GradingRecords,
  PackagingRecords,
  DamageRecords,
  Shipments,
  ShipmentItems,
  ShipmentAllocations,
  Sales,
  SaleItems,
  SaleAllocations,
  FarmerPriceDeterminations,
  FarmerPayables,
  FarmerPayments,
  BuyerReceivables,
  BuyerPayments,
  Expenses,
  CashTransactions,
  DailyCashClosings,
  AppSettings,
  BusinessProfiles,
  CalendarEvents,
  AuditLogs,
  BackupHistories,
  NotificationSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? conn.openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedInitialData();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _seedInitialData() async {
    const uuid = Uuid();
    final now = DateTime.now();

    // 1. Initial Business Profile
    await into(businessProfiles).insert(
      BusinessProfilesCompanion.insert(
        id: uuid.v4(),
        businessName: const Value('Pengepul Hasil Tani Mandiri'),
        ownerName: const Value('H. Sukirman'),
        phone: const Value('081234567890'),
        address: const Value('Sentra Sayur Mayur Agropolitan, Jawa Barat'),
        defaultGradingTolerancePercent: const Value(2.0),
        updatedAt: Value(now),
      ),
    );

    // 2. Default Commodity Units
    final kgUnitId = uuid.v4();
    final gramUnitId = uuid.v4();
    final keranjangUnitId = uuid.v4();
    final karungUnitId = uuid.v4();
    final ikatUnitId = uuid.v4();
    final petiUnitId = uuid.v4();

    await into(commodityUnits).insert(
      CommodityUnitsCompanion.insert(
        id: kgUnitId,
        name: 'Kilogram',
        symbol: 'kg',
        isDefaultBase: const Value(true),
        createdAt: Value(now),
      ),
    );
    await into(commodityUnits).insert(
      CommodityUnitsCompanion.insert(
        id: gramUnitId,
        name: 'Gram',
        symbol: 'g',
        isDefaultBase: const Value(false),
        createdAt: Value(now),
      ),
    );
    await into(commodityUnits).insert(
      CommodityUnitsCompanion.insert(
        id: keranjangUnitId,
        name: 'Keranjang',
        symbol: 'krj',
        isDefaultBase: const Value(false),
        createdAt: Value(now),
      ),
    );
    await into(commodityUnits).insert(
      CommodityUnitsCompanion.insert(
        id: karungUnitId,
        name: 'Karung',
        symbol: 'krg',
        isDefaultBase: const Value(false),
        createdAt: Value(now),
      ),
    );
    await into(commodityUnits).insert(
      CommodityUnitsCompanion.insert(
        id: ikatUnitId,
        name: 'Ikat',
        symbol: 'ikt',
        isDefaultBase: const Value(false),
        createdAt: Value(now),
      ),
    );
    await into(commodityUnits).insert(
      CommodityUnitsCompanion.insert(
        id: petiUnitId,
        name: 'Peti',
        symbol: 'pti',
        isDefaultBase: const Value(false),
        createdAt: Value(now),
      ),
    );

    // 3. Default Commodities
    final defaultCommodities = [
      {'name': 'Cabai Merah Keriting', 'tol': 2.0},
      {'name': 'Cabai Rawit Merah', 'tol': 2.0},
      {'name': 'Tomat Buah', 'tol': 2.5},
      {'name': 'Kacang Panjang', 'tol': 2.0},
      {'name': 'Labu Air', 'tol': 1.5},
      {'name': 'Jagung Manis', 'tol': 2.0},
      {'name': 'Bawang Merah', 'tol': 3.0},
      {'name': 'Kangkung', 'tol': 2.0},
      {'name': 'Bayam', 'tol': 2.0},
      {'name': 'Sawi Hijau / Caisim', 'tol': 2.0},
      {'name': 'Buncis', 'tol': 2.0},
      {'name': 'Terong Ungu', 'tol': 2.0},
    ];

    for (final c in defaultCommodities) {
      final commId = uuid.v4();
      await into(commodities).insert(
        CommoditiesCompanion.insert(
          id: commId,
          name: c['name'] as String,
          defaultLossTolerancePercent: Value(c['tol'] as double),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Default conversion example for Tomat & Cabai: 1 Keranjang = 20 kg (Tomat), 15 kg (Cabai)
      if ((c['name'] as String).contains('Tomat')) {
        await into(unitConversions).insert(
          UnitConversionsCompanion.insert(
            id: uuid.v4(),
            commodityId: commId,
            unitId: keranjangUnitId,
            toKgMultiplier: 20.0,
            createdAt: Value(now),
          ),
        );
      } else if ((c['name'] as String).contains('Cabai')) {
        await into(unitConversions).insert(
          UnitConversionsCompanion.insert(
            id: uuid.v4(),
            commodityId: commId,
            unitId: keranjangUnitId,
            toKgMultiplier: 15.0,
            createdAt: Value(now),
          ),
        );
      }
    }

    // 4. Default Sample Farmers (Active)
    final farmerAId = uuid.v4();
    final farmerBId = uuid.v4();
    final farmerCId = uuid.v4();
    await into(farmers).insert(
      FarmersCompanion.insert(
        id: farmerAId,
        name: 'Pak Budi Santoso',
        phone: const Value('081320112233'),
        address: const Value('Desa Sukamaju, RT 02/03'),
        notes: const Value('Petani spesialis Cabai dan Buncis'),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await into(farmers).insert(
      FarmersCompanion.insert(
        id: farmerBId,
        name: 'Pak Wayan Subrata',
        phone: const Value('081298765432'),
        address: const Value('Desa Mekarsari, Blok C'),
        notes: const Value('Petani Tomat dan Terong'),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await into(farmers).insert(
      FarmersCompanion.insert(
        id: farmerCId,
        name: 'Ibu Siti Aminah',
        phone: const Value('085712348899'),
        address: const Value('Desa Karanganyar'),
        notes: const Value('Petani Kacang Panjang dan Jagung'),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // 5. Default Sample Buyers (Active)
    await into(buyers).insert(
      BuyersCompanion.insert(
        id: uuid.v4(),
        name: 'Haji Rusli (Kios Barokah Induk)',
        phone: const Value('081809988771'),
        address: const Value('Pasar Induk Kramat Jati, Los C-12'),
        notes: const Value('Langganan partai besar, tempo 3 hari'),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await into(buyers).insert(
      BuyersCompanion.insert(
        id: uuid.v4(),
        name: 'Pak Hendra (Pasar Cibitung)',
        phone: const Value('087811224455'),
        address: const Value('Pasar Induk Cibitung, Blok D'),
        notes: const Value('Pembeli komoditas cabai dan tomat'),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // 6. Default App Settings
    await into(appSettings).insert(
      AppSettingsCompanion.insert(
        key: 'is_onboarding_completed',
        value: 'true',
        updatedAt: Value(now),
      ),
    );
    await into(appSettings).insert(
      AppSettingsCompanion.insert(
        key: 'security_pin_enabled',
        value: 'false',
        updatedAt: Value(now),
      ),
    );
    await into(appSettings).insert(
      AppSettingsCompanion.insert(
        key: 'auto_lock_duration_minutes',
        value: '5',
        updatedAt: Value(now),
      ),
    );
  }
}
