import 'dart:io';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/app_models.dart';
import '../storage/token_store.dart';

enum SessionStage { booting, signedOut, twoFactor, signedIn }

class SessionController extends ChangeNotifier {
  factory SessionController({TokenStore? tokenStore, ApiClient? apiClient}) {
    final store = tokenStore ?? TokenStore();
    return SessionController._(
      store,
      apiClient ?? ApiClient(tokenStore: store),
    );
  }

  SessionController._(this._tokenStore, this._apiClient);

  factory SessionController.preview() {
    final store = TokenStore();
    return SessionController._(store, ApiClient(tokenStore: store))
      ..stage = SessionStage.signedOut;
  }

  final TokenStore _tokenStore;
  final ApiClient _apiClient;

  SessionStage stage = SessionStage.booting;
  bool busy = false;
  bool workspaceLoading = false;
  bool useRecoveryCode = false;
  String? message;
  String? challengeToken;
  Map<String, String> fieldErrors = const {};
  BootstrapData? bootstrap;
  DashboardData dashboard = DashboardData.empty;
  List<VehicleData> vehicles = const [];
  List<VehicleData> mapVehicles = const [];
  List<AlertData> alerts = const [];

  BrandingData get branding => bootstrap?.branding ?? BrandingData.fallback;
  AppUser? get user => bootstrap?.user;

  Future<void> initialize() async {
    stage = SessionStage.booting;
    notifyListeners();
    try {
      final tokens = await _tokenStore.readTokens();
      if (tokens == null) {
        stage = SessionStage.signedOut;
        return;
      }
      await _loadAuthenticatedWorkspace();
    } on ApiException catch (error) {
      if (error.isUnauthorized) await _tokenStore.clearTokens();
      message = error.message;
      stage = SessionStage.signedOut;
    } catch (_) {
      message = 'La session enregistrée n’a pas pu être restaurée.';
      stage = SessionStage.signedOut;
    } finally {
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _beginAction();
    try {
      final deviceIdentifier = await _tokenStore.deviceIdentifier();
      final result = await _apiClient.login(
        email: email.trim(),
        password: password,
        deviceIdentifier: deviceIdentifier,
        deviceName: Platform.isIOS ? 'iPhone EXAD' : 'Android EXAD',
        platform: Platform.isIOS ? 'ios' : 'android',
      );

      if (result.twoFactorRequired) {
        challengeToken = result.challengeToken;
        stage = SessionStage.twoFactor;
      } else {
        await _acceptTokens(result.tokens!);
      }
    } on ApiException catch (error) {
      message = error.message;
      fieldErrors = error.fieldErrors;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> verifyTwoFactor(String value) async {
    final challenge = challengeToken;
    if (challenge == null) {
      stage = SessionStage.signedOut;
      notifyListeners();
      return;
    }

    _beginAction();
    try {
      final result = await _apiClient.verifyTwoFactor(
        challengeToken: challenge,
        code: useRecoveryCode ? null : value.trim(),
        recoveryCode: useRecoveryCode ? value.trim() : null,
      );
      await _acceptTokens(result.tokens!);
    } on ApiException catch (error) {
      message = error.message;
      fieldErrors = error.fieldErrors;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void toggleRecoveryCode() {
    useRecoveryCode = !useRecoveryCode;
    message = null;
    fieldErrors = const {};
    notifyListeners();
  }

  void cancelTwoFactor() {
    challengeToken = null;
    useRecoveryCode = false;
    message = null;
    fieldErrors = const {};
    stage = SessionStage.signedOut;
    notifyListeners();
  }

  Future<void> refreshWorkspace() async {
    if (workspaceLoading) return;
    workspaceLoading = true;
    message = null;
    notifyListeners();
    try {
      await _loadWorkspaceData();
    } on ApiException catch (error) {
      message = error.message;
      if (error.isUnauthorized) {
        await _tokenStore.clearTokens();
        stage = SessionStage.signedOut;
      }
    } finally {
      workspaceLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    busy = true;
    notifyListeners();
    try {
      await _apiClient.logout();
    } finally {
      bootstrap = null;
      dashboard = DashboardData.empty;
      vehicles = const [];
      mapVehicles = const [];
      alerts = const [];
      busy = false;
      stage = SessionStage.signedOut;
      notifyListeners();
    }
  }

  void clearErrors() {
    if (message == null && fieldErrors.isEmpty) return;
    message = null;
    fieldErrors = const {};
    notifyListeners();
  }

  Future<VehicleDetailData> vehicleDetails(int vehicleId) =>
      _apiClient.vehicleDetails(vehicleId);

  Future<List<VehicleEventData>> vehicleEvents(int vehicleId) =>
      _apiClient.vehicleEvents(vehicleId);

  Future<VehicleTripsData> vehicleTrips(
    int vehicleId, {
    String period = 'today',
  }) => _apiClient.vehicleTrips(vehicleId, period: period);

  Future<List<VehicleData>> mapSnapshot() => _apiClient.mapVehicles();

  Future<void> _acceptTokens(AuthTokens tokens) async {
    await _tokenStore.writeTokens(tokens);
    await _loadAuthenticatedWorkspace();
  }

  Future<void> _loadAuthenticatedWorkspace() async {
    bootstrap = await _apiClient.bootstrap();
    stage = SessionStage.signedIn;
    await _loadWorkspaceData();
  }

  Future<void> _loadWorkspaceData() async {
    final canViewMap = user?.hasPermission('map_view') == true;
    final results = await Future.wait([
      _apiClient.dashboard(),
      _apiClient.vehicles(),
      _apiClient.alerts(),
      if (canViewMap) _apiClient.mapVehicles(),
    ]);

    dashboard = results[0] as DashboardData;
    vehicles = results[1] as List<VehicleData>;
    alerts = results[2] as List<AlertData>;
    mapVehicles = canViewMap ? results[3] as List<VehicleData> : const [];
  }

  void _beginAction() {
    busy = true;
    message = null;
    fieldErrors = const {};
    notifyListeners();
  }
}
