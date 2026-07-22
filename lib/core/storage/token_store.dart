import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_models.dart';

class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'mobile_access_token';
  static const _refreshKey = 'mobile_refresh_token';
  static const _sessionKey = 'mobile_session_id';
  static const _deviceKey = 'mobile_device_identifier';

  Future<AuthTokens?> readTokens() async {
    final values = await _storage.readAll();
    final tokens = AuthTokens(
      accessToken: values[_accessKey] ?? '',
      refreshToken: values[_refreshKey] ?? '',
      sessionId: values[_sessionKey] ?? '',
    );
    return tokens.isValid ? tokens : null;
  }

  Future<void> writeTokens(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(key: _accessKey, value: tokens.accessToken),
      _storage.write(key: _refreshKey, value: tokens.refreshToken),
      _storage.write(key: _sessionKey, value: tokens.sessionId),
    ]);
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _sessionKey),
    ]);
  }

  Future<String> deviceIdentifier() async {
    final existing = await _storage.read(key: _deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final value = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(key: _deviceKey, value: value);
    return value;
  }
}
