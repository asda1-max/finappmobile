import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service for biometric authentication (fingerprint / face).
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if biometric hardware is available.
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types.
  static Future<List<BiometricType>> getAvailableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Prompt the user for biometric authentication.
  /// Returns true if authentication succeeds.
  static Future<bool> authenticate({
    String reason = 'Authenticate to access Tick Watchers',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
