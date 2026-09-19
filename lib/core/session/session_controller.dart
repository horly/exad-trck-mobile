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

  void setLanguageCode(String languageCode) {
    _apiClient.setLanguageCode(languageCode);
  }

  Future<void> initialize() async {
    stage = SessionStage.booting;
    message = null;
    notifyListeners();
    try {
      final tokens = await _tokenStore.readTokens();
      if (tokens == null) {
        stage = SessionStage.signedOut;
        return;
      }
      await _loadAuthenticatedWorkspace();
    } on ApiException catch (error) {
      message = error.message;
      if (_closesSession(error)) {
        await _tokenStore.clearTokens();
        stage = SessionStage.signedOut;
      } else {
        // Preserve the persisted session while the server or network is
        // temporarily unavailable instead of asking the user to sign in.
        stage = SessionStage.booting;
      }
    } catch (_) {
      message = 'La session enregistrée est conservée. Réessayez la connexion.';
      stage = SessionStage.booting;
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

  Future<void> refreshWorkspace({bool silent = false}) async {
    if (workspaceLoading) return;
    workspaceLoading = true;
    message = null;
    if (!silent) notifyListeners();
    try {
      bootstrap = await _apiClient.bootstrap();
      await _loadWorkspaceData();
    } on ApiException catch (error) {
      message = error.message;
      if (_closesSession(error)) {
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

  Future<FleetManagementData> fleetManagement() => _apiClient.fleetManagement();

  Future<String> createFleet({
    required String name,
    required String code,
    String status = 'active',
    String? description,
    int? adminId,
  }) => _apiClient.createFleet(
    name: name,
    code: code,
    status: status,
    description: description,
    adminId: adminId,
  );

  Future<String> updateFleet({
    required int id,
    required String name,
    required String code,
    required String status,
    String? description,
    int? adminId,
  }) => _apiClient.updateFleet(
    id: id,
    name: name,
    code: code,
    status: status,
    description: description,
    adminId: adminId,
  );

  Future<String> deleteFleet(int id) => _apiClient.deleteFleet(id);

  Future<UserManagementData> managedUsers() => _apiClient.managedUsers();

  Future<String> saveManagedUser({
    int? id,
    required String name,
    required String email,
    required String role,
    required int fleetId,
    required List<String> permissions,
    String? password,
    String? phone,
    String? address,
  }) => _apiClient.saveManagedUser(
    id: id,
    name: name,
    email: email,
    role: role,
    fleetId: fleetId,
    permissions: permissions,
    password: password,
    phone: phone,
    address: address,
  );

  Future<String> deleteManagedUser(int id) => _apiClient.deleteManagedUser(id);

  Future<String> createVehicle({
    required int fleetId,
    required String name,
    required String registration,
    required String vehicleType,
    String status = 'active',
    String? brand,
    String? model,
    String? color,
    int? year,
    int? speedLimitKmh,
  }) => _apiClient.createVehicle(
    fleetId: fleetId,
    name: name,
    registration: registration,
    vehicleType: vehicleType,
    status: status,
    brand: brand,
    model: model,
    color: color,
    year: year,
    speedLimitKmh: speedLimitKmh,
  );

  Future<String> updateVehicle({
    required int id,
    required int fleetId,
    required String name,
    required String registration,
    required String vehicleType,
    required String status,
    String? brand,
    String? model,
    String? color,
    int? year,
    int? speedLimitKmh,
  }) => _apiClient.updateVehicle(
    id: id,
    fleetId: fleetId,
    name: name,
    registration: registration,
    vehicleType: vehicleType,
    status: status,
    brand: brand,
    model: model,
    color: color,
    year: year,
    speedLimitKmh: speedLimitKmh,
  );

  Future<String> deleteVehicle(int id) => _apiClient.deleteVehicle(id);

  Future<String> createTracker({
    required int vehicleId,
    required String imei,
    required String brand,
    required String model,
    required String protocol,
    String? name,
    String? simNumber,
    String? operatorName,
  }) => _apiClient.createTracker(
    vehicleId: vehicleId,
    imei: imei,
    brand: brand,
    model: model,
    protocol: protocol,
    name: name,
    simNumber: simNumber,
    operatorName: operatorName,
  );

  Future<String> updateTracker({
    required int id,
    required int vehicleId,
    required String imei,
    required String brand,
    required String model,
    required String protocol,
    String? name,
    String? simNumber,
    String? operatorName,
  }) => _apiClient.updateTracker(
    id: id,
    vehicleId: vehicleId,
    imei: imei,
    brand: brand,
    model: model,
    protocol: protocol,
    name: name,
    simNumber: simNumber,
    operatorName: operatorName,
  );

  Future<String> deleteTracker(int id) => _apiClient.deleteTracker(id);

  Future<List<DriverData>> drivers() => _apiClient.drivers();

  Future<DepartmentCollectionData> departments() => _apiClient.departments();

  Future<String> saveDepartment({
    int? id,
    required int fleetId,
    required String name,
    String? code,
    String? description,
    required String status,
  }) => _apiClient.saveDepartment(
    id: id,
    fleetId: fleetId,
    name: name,
    code: code,
    description: description,
    status: status,
  );

  Future<String> deleteDepartment(int id) => _apiClient.deleteDepartment(id);

  Future<String> requestEngineCommand(
    int vehicleId,
    String action,
    int output,
  ) => _apiClient.requestEngineCommand(vehicleId, action, output);

  Future<List<VehicleEventData>> vehicleEvents(int vehicleId) =>
      _apiClient.vehicleEvents(vehicleId);

  Future<List<VehicleEventData>> notificationEvents({int? afterId}) =>
      _apiClient.notificationEvents(afterId: afterId);

  Future<List<AlertData>> notificationAlerts({int? afterId}) =>
      _apiClient.notificationAlerts(afterId: afterId);

  Future<void> registerPushDevice({
    required String token,
    required String locale,
    required String appVersion,
  }) => _apiClient.registerPushDevice(
    token: token,
    locale: locale,
    appVersion: appVersion,
  );

  Future<NotificationPreferencesData> notificationPreferences() =>
      _apiClient.notificationPreferences();

  Future<NotificationPreferencesData> updateNotificationPreferences({
    required bool vehicleEventsEnabled,
    required bool alertsEnabled,
  }) => _apiClient.updateNotificationPreferences(
    vehicleEventsEnabled: vehicleEventsEnabled,
    alertsEnabled: alertsEnabled,
  );

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

  bool _closesSession(ApiException error) =>
      error.isUnauthorized ||
      (error.statusCode == 403 && error.code == 'ACCOUNT_UNAVAILABLE');
}
