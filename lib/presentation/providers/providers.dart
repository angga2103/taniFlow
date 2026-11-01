import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/pin_security.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/tani_repository.dart';
import '../../data/services/drive_backup_service.dart';
import '../../data/services/printer_service.dart';

// Database & Core Services
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final repositoryProvider = Provider<TaniRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TaniRepository(db);
});

final pinSecurityProvider = Provider<PinSecurityService>((ref) {
  return PinSecurityService();
});

final printerServiceProvider = Provider<ThermalPrinterService>((ref) {
  return ThermalPrinterService();
});

final driveBackupServiceProvider = Provider<DriveBackupService>((ref) {
  return DriveBackupService();
});

// Master Data Streams
final activeFarmersProvider = StreamProvider<List<Farmer>>((ref) {
  return ref.watch(repositoryProvider).watchActiveFarmers();
});

final activeBuyersProvider = StreamProvider<List<Buyer>>((ref) {
  return ref.watch(repositoryProvider).watchActiveBuyers();
});

final commoditiesProvider = StreamProvider<List<Commodity>>((ref) {
  return ref.watch(repositoryProvider).watchCommodities();
});

final commodityUnitsProvider = StreamProvider<List<CommodityUnit>>((ref) {
  return ref.watch(repositoryProvider).watchUnits();
});

// Operations Streams
final submissionsProvider = StreamProvider<List<FarmerSubmission>>((ref) {
  return ref.watch(repositoryProvider).watchSubmissions();
});

final pendingGradingItemsProvider = StreamProvider<List<SubmissionItem>>((ref) {
  return ref.watch(repositoryProvider).watchPendingGradingItems();
});

final shipmentsProvider = StreamProvider<List<Shipment>>((ref) {
  return ref.watch(repositoryProvider).watchShipments();
});

final salesProvider = StreamProvider<List<Sale>>((ref) {
  return ref.watch(repositoryProvider).watchSales();
});

final receivablesProvider = StreamProvider<List<BuyerReceivable>>((ref) {
  return ref.watch(repositoryProvider).watchBuyerReceivables();
});

// Cash & Finance
final cashTransactionsProvider = StreamProvider<List<CashTransaction>>((ref) {
  return ref.watch(repositoryProvider).watchCashTransactions();
});

final currentCashBalanceProvider = FutureProvider<double>((ref) async {
  // trigger refresh when transactions change
  ref.watch(cashTransactionsProvider);
  return await ref.watch(repositoryProvider).getCurrentCashBalance();
});

final businessProfileProvider = FutureProvider<BusinessProfile?>((ref) async {
  return await ref.watch(repositoryProvider).getBusinessProfile();
});

// App Lock State Notifier
class AppLockNotifier extends StateNotifier<bool> {
  final PinSecurityService _securityService;

  AppLockNotifier(this._securityService) : super(false) {
    checkInitialLock();
  }

  Future<void> checkInitialLock() async {
    final shouldLock = await _securityService.shouldLock();
    state = shouldLock;
  }

  void unlock() {
    state = false;
  }

  void lock() {
    state = true;
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier(ref.watch(pinSecurityProvider));
});
