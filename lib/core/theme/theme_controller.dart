import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({FlutterSecureStorage? storage})
    : mode = ThemeMode.system,
      _storage = storage ?? const FlutterSecureStorage();

  ThemeController.preview([this.mode = ThemeMode.system])
    : _storage = const FlutterSecureStorage();

  static const _storageKey = 'exad_app_theme';
  final FlutterSecureStorage _storage;

  ThemeMode mode;

  Future<void> initialize() async {
    final storedMode = await _storage.read(key: _storageKey);
    mode = switch (storedMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    mode = value;
    if (value == ThemeMode.system) {
      await _storage.delete(key: _storageKey);
    } else {
      await _storage.write(key: _storageKey, value: value.name);
    }
    notifyListeners();
  }
}
