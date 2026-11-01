import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/providers.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  String _enteredPin = '';
  String? _errorMessage;
  bool _canBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final security = ref.read(pinSecurityProvider);
    final canBio = await security.canCheckBiometrics();
    final isBioEnabled = await security.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _canBiometric = canBio && isBioEnabled;
      });
      if (_canBiometric) {
        _authenticateBiometric();
      }
    }
  }

  Future<void> _authenticateBiometric() async {
    final security = ref.read(pinSecurityProvider);
    final success = await security.authenticateWithBiometrics();
    if (success && mounted) {
      ref.read(appLockProvider.notifier).unlock();
    }
  }

  void _onNumberPressed(int number) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += number.toString();
        _errorMessage = null;
      });

      if (_enteredPin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    final security = ref.read(pinSecurityProvider);
    final isValid = await security.verifyPin(_enteredPin);
    if (isValid && mounted) {
      ref.read(appLockProvider.notifier).unlock();
    } else {
      if (mounted) {
        setState(() {
          _enteredPin = '';
          _errorMessage = 'PIN salah. Silakan coba lagi.';
        });
      }
    }
  }

  void _showRecoveryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pemulihan Akses (Recovery Code)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan 8 karakter Recovery Code yang Anda dapatkan saat mengatur PIN:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Contoh: ABCD1234',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final security = ref.read(pinSecurityProvider);
                final isValid = await security.verifyRecoveryCode(textController.text.trim());
                if (!context.mounted) return;
                if (isValid) {
                  await security.removePin();
                  ref.read(appLockProvider.notifier).unlock();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN berhasil direset. Silakan buat PIN baru di pengaturan.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recovery Code tidak valid.')),
                  );
                }
              },
              child: const Text('Verifikasi'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            children: [
              const Spacer(),
              // Logo & App Name
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                AppStrings.appTagline,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Text(
                'Masukkan 6-Digit PIN Anda',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? AppColors.accent : Colors.white24,
                      border: Border.all(
                        color: isFilled ? AppColors.accent : Colors.white54,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const Spacer(),
              // Numpad
              _buildNumpad(),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _showRecoveryDialog,
                child: const Text(
                  'Lupa PIN? Gunakan Recovery Code',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey(1),
            _buildKey(2),
            _buildKey(3),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey(4),
            _buildKey(5),
            _buildKey(6),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey(7),
            _buildKey(8),
            _buildKey(9),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _canBiometric
                ? IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.fingerprint, color: Colors.white),
                    onPressed: _authenticateBiometric,
                  )
                : const SizedBox(width: 72, height: 72),
            _buildKey(0),
            IconButton(
              iconSize: 28,
              icon: const Icon(Icons.backspace_outlined, color: Colors.white),
              onPressed: _onBackspace,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(int number) {
    return InkWell(
      onTap: () => _onNumberPressed(number),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          number.toString(),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
