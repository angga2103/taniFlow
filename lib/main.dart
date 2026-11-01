import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'data/services/notification_service.dart';
import 'presentation/providers/providers.dart';
import 'presentation/screens/auth/pin_screen.dart';
import 'presentation/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  try {
    await LocalNotificationService.initialize();
  } catch (_) {}

  runApp(
    const ProviderScope(
      child: TaniFlowApp(),
    ),
  );
}

class TaniFlowApp extends ConsumerWidget {
  const TaniFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = ref.watch(appLockProvider);

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      locale: const Locale('id', 'ID'),
      home: isLocked ? const PinScreen() : const MainNavigationScreen(),
    );
  }
}
