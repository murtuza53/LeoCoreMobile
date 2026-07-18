import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper over [LocalAuthentication] for fingerprint/biometric unlock.
class Biometrics {
  final LocalAuthentication _auth = LocalAuthentication();

  /// True when the device has hardware + at least one enrolled biometric.
  Future<bool> available() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts for a fingerprint/biometric. Returns true only on success.
  /// [BiometricResult.error] carries a user-facing reason when it fails.
  Future<BiometricResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return ok ? const BiometricResult(true) : const BiometricResult(false);
    } on PlatformException catch (e) {
      return BiometricResult(false, error: _message(e.code));
    } catch (_) {
      return const BiometricResult(false, error: 'Fingerprint unlock failed.');
    }
  }

  static String _message(String code) {
    switch (code) {
      case 'NotEnrolled':
        return 'No fingerprint enrolled — add one in device settings.';
      case 'NotAvailable':
        return 'Fingerprint is not available on this device.';
      case 'LockedOut':
        return 'Too many attempts. Try again later.';
      case 'PermanentlyLockedOut':
        return 'Fingerprint locked. Unlock your device with your PIN first.';
      case 'PasscodeNotSet':
        return 'Set a screen lock on your device to use fingerprint.';
      default:
        return 'Fingerprint unlock failed.';
    }
  }
}

class BiometricResult {
  final bool ok;
  final String? error;
  const BiometricResult(this.ok, {this.error});
}
