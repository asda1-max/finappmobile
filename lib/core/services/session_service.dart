import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing session data (JWT token, username)
/// using encrypted storage (AES encryption at rest).
class SessionService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'auth_token';
  static const _keyUsername = 'auth_username';
  static const _keyEmail = 'auth_email';
  static const _keyProfilePic = 'auth_profile_pic';
  static const _keyPortfolioGoals = 'auth_portfolio_goals';
  static const _keyMinat = 'auth_minat';
  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyLoggedOut = 'logged_out';

  /// Save session after successful login.
  static Future<void> saveSession({
    required String token,
    required String username,
    required String email,
    String? profilePic,
    String? portfolioGoals,
    String? minat,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyEmail, value: email);
    if (profilePic != null) {
      await _storage.write(key: _keyProfilePic, value: profilePic);
    }
    if (portfolioGoals != null) {
      await _storage.write(key: _keyPortfolioGoals, value: portfolioGoals);
    }
    if (minat != null) {
      await _storage.write(key: _keyMinat, value: minat);
    }
    // Clear the logged-out flag since we're actively logged in now.
    await _storage.delete(key: _keyLoggedOut);
  }

  /// Get stored JWT token.
  static Future<String?> getToken() async {
    return _storage.read(key: _keyToken);
  }

  /// Get stored username.
  static Future<String?> getUsername() async {
    return _storage.read(key: _keyUsername);
  }

  /// Get stored email.
  static Future<String?> getEmail() async {
    return _storage.read(key: _keyEmail);
  }

  /// Get stored profile picture.
  static Future<String?> getProfilePic() async {
    return _storage.read(key: _keyProfilePic);
  }

  /// Get stored portfolio goals.
  static Future<String?> getPortfolioGoals() async {
    return _storage.read(key: _keyPortfolioGoals);
  }

  /// Get stored minat.
  static Future<String?> getMinat() async {
    return _storage.read(key: _keyMinat);
  }



  /// Check if user is actively logged in (not soft-logged-out).
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    final loggedOut = await _storage.read(key: _keyLoggedOut);
    return token != null && token.isNotEmpty && loggedOut != 'true';
  }

  /// Check if stored credentials exist for biometric re-login,
  /// regardless of whether the user has soft-logged-out.
  static Future<bool> hasStoredCredentials() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Soft logout — marks the session as logged out but **preserves**
  /// the token + biometric preference so that biometric can restore
  /// the session later without re-entering a password.
  static Future<void> softLogout() async {
    await _storage.write(key: _keyLoggedOut, value: 'true');
  }

  /// Hard clear — wipes all session data including the token and
  /// biometric preference. Use when the user explicitly disables
  /// biometric or you need a full reset.
  static Future<void> clearSession() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyProfilePic);
    await _storage.delete(key: _keyPortfolioGoals);
    await _storage.delete(key: _keyMinat);
    await _storage.delete(key: _keyLoggedOut);
  }

  /// Enable/disable biometric login.
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
        key: _keyBiometricEnabled, value: enabled.toString());
  }

  /// Check if biometric login is enabled.
  static Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _keyBiometricEnabled);
    return val == 'true';
  }
}
