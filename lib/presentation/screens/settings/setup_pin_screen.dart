import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/providers.dart';

class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends ConsumerState<SetupPinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _isBiometricEnabled = false;
  bool _canCheckBio = false;
  bool _hasExistingPin = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final sec = ref.read(pinSecurityProvider);
    final hasPin = await sec.isPinSet();
    final canBio = await sec.canCheckBiometrics();
    final isBio = await sec.isBiometricEnabled();

    if (mounted) {
      setState(() {
        _hasExistingPin = hasPin;
        _canCheckBio = canBio;
        _isBiometricEnabled = isBio;
      });
    }
  }

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (pin.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN harus terdiri dari 6 angka.')),
      );
      return;
    }

    if (pin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi PIN tidak cocok.')),
      );
      return;
    }

    final sec = ref.read(pinSecurityProvider);
    final recoveryCode = await sec.setPin(pin);
    await sec.setBiometricEnabled(_isBiometricEnabled);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('PIN Berhasil Diaktifkan!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SIMPAN KODE PEMULIHAN (RECOVERY CODE) INI DENGAN AMAN:'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLighter,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Center(
                    child: SelectableText(
                      recoveryCode,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Jika sewaktu-waktu Anda lupa PIN, kode ini adalah satu-satunya cara untuk memulihkan akses tanpa menghapus database.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Saya Sudah Mencatatnya'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _removePin() async {
    final sec = ref.read(pinSecurityProvider);
    await sec.removePin();
    await sec.setBiometricEnabled(false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kunci PIN dinonaktifkan.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Kunci PIN & Biometrik'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keamanan Aplikasi TaniFlow',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Lindungi data keuangan, setoran, dan buku kas usaha Anda dengan 6-digit PIN rahasia dan sidik jari.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Buat 6-Digit PIN Baru',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _confirmPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Ulangi 6-Digit PIN',
                prefixIcon: Icon(Icons.lock_reset),
              ),
            ),
            const SizedBox(height: 10),

            if (_canCheckBio) ...[
              SwitchListTile(
                title: const Text('Aktifkan Masuk dengan Sidik Jari (Biometrik)'),
                subtitle: const Text('Buka aplikasi cepat menggunakan sensor fingerprint HP'),
                value: _isBiometricEnabled,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() => _isBiometricEnabled = val);
                },
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _savePin,
              icon: const Icon(Icons.save),
              label: Text(_hasExistingPin ? 'Perbarui PIN Keamanan' : 'Aktifkan PIN Keamanan'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),

            if (_hasExistingPin) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _removePin,
                icon: const Icon(Icons.lock_open, color: AppColors.danger),
                label: const Text('Nonaktifkan Kunci PIN', style: TextStyle(color: AppColors.danger)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppColors.danger),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
