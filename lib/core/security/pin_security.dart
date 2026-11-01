import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class PinSecurityService {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  PinSecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  static const String _keyPinHash = 'user_pin_hash';
  static const String _keyPinSalt = 'user_pin_salt';
  static const String _keyRecoveryCode = 'user_recovery_code';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyLockTimeoutMinutes = 'lock_timeout_minutes';
  static const String _keyLastActiveTimestamp = 'last_active_timestamp';

  // Generate random salt
  String _generateSalt([int length = 32]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  // Hash PIN with Salt using SHA-256
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin:$salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Set new PIN
  Future<String> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    final recoveryCode = _generateRecoveryCode();

    await _storage.write(key: _keyPinSalt, value: salt);
    await _storage.write(key: _keyPinHash, value: hash);
    await _storage.write(key: _keyRecoveryCode, value: recoveryCode);
    await updateLastActive();

    return recoveryCode;
  }

  // Verify PIN
  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _keyPinSalt);
    final storedHash = await _storage.read(key: _keyPinHash);

    if (salt == null || storedHash == null) {
      return false;
    }

    final computedHash = _hashPin(pin, salt);
    final isValid = computedHash == storedHash;
    if (isValid) {
      await updateLastActive();
    }
    return isValid;
  }

  // Check if PIN is configured
  Future<bool> isPinSet() async {
    final hash = await _storage.read(key: _keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  // Verify with Recovery Code
  Future<bool> verifyRecoveryCode(String code) async {
    final storedCode = await _storage.read(key: _keyRecoveryCode);
    if (storedCode == null) return false;
    return storedCode.trim().toUpperCase() == code.trim().toUpperCase();
  }

  // Biometric Auth Settings
  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _keyBiometricEnabled);
    return val == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
  }

  // Biometric Auth
  Future<bool> canCheckBiometrics() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Pindai sidik jari atau wajah untuk membuka TaniFlow',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated) {
        await updateLastActive();
      }
      return authenticated;
    } catch (_) {
      return false;
    }
  }

  // Auto-lock tracking
  Future<void> updateLastActive() async {
    await _storage.write(
      key: _keyLastActiveTimestamp,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<bool> shouldLock() async {
    final isSet = await isPinSet();
    if (!isSet) return false;

    final lastActiveStr = await _storage.read(key: _keyLastActiveTimestamp);
    if (lastActiveStr == null) return true;

    final timeoutStr = await _storage.read(key: _keyLockTimeoutMinutes) ?? '5';
    final timeoutMinutes = int.tryParse(timeoutStr) ?? 5;

    final lastActive = DateTime.fromMillisecondsSinceEpoch(int.parse(lastActiveStr));
    final difference = DateTime.now().difference(lastActive);

    return difference.inMinutes >= timeoutMinutes;
  }

  // Remove PIN
  Future<void> removePin() async {
    await _storage.delete(key: _keyPinHash);
    await _storage.delete(key: _keyPinSalt);
    await _storage.delete(key: _keyRecoveryCode);
  }

  String _generateRecoveryCode() {
    final rand = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
