import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';

class ApiResult {
  const ApiResult(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}

class AuthenticationResult {
  const AuthenticationResult({
    required this.twoFactorRequired,
    this.challengeToken,
    this.challengeExpiresIn,
    this.tokens,
  });

  final bool twoFactorRequired;
  final String? challengeToken;
  final int? challengeExpiresIn;
  final AuthTokens? tokens;
}

class ApiClient {
  ApiClient({
    required TokenStore tokenStore,
    http.Client? client,
    String baseUrl = AppConfig.apiBaseUrl,
  }) : _tokenStore = tokenStore,
       _client = client ?? http.Client(),
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final TokenStore _tokenStore;
  final http.Client _client;
  final String _baseUrl;
  String _languageCode = 'fr';
  Future<AuthTokens>? _refreshInFlight;

  void setLanguageCode(String languageCode) {
    _languageCode = languageCode == 'en' ? 'en' : 'fr';
  }

  Future<AuthenticationResult> login({
    required String email,
    required String password,
    required String deviceIdentifier,
    required String deviceName,
    required String platform,
  }) async {
    final result = await _send(
      'POST',
      '/auth/login',
      body: {
        'email': email,
        'password': password,
        'device_identifier': deviceIdentifier,
        'device_name': deviceName,
        'platform': platform,
        'app_version': AppConfig.fullVersion,
      },
    );
    return _authenticationResult(result.body);
  }

  Future<AuthenticationResult> verifyTwoFactor({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  }) async {
    final result = await _send(
      'POST',
      '/auth/two-factor',
      body: {
        'challenge_token': challengeToken,
        'code': ?code,
        'recovery_code': ?recoveryCode,
      },
    );
    return _authenticationResult(result.body);
  }

  Future<BootstrapData> bootstrap() async {
    final result = await _authorized('GET', '/bootstrap');
    return BootstrapData.fromMap(mapOf(result.body['data']));
  }

  Future<DashboardData> dashboard() async {
    final result = await _authorized('GET', '/dashboard');
    return DashboardData.fromMap(mapOf(result.body['data']));
  }

  Future<List<VehicleData>> vehicles() async {
    final result = await _authorized(
      'GET',
      '/vehicles',
      query: {'per_page': '50'},
    );
    return listOfMaps(result.body['data']).map(VehicleData.fromMap).toList();
  }

  Future<FleetManagementData> fleetManagement() async {
    final result = await _authorized('GET', '/management');
    return FleetManagementData.fromMap(mapOf(result.body['data']));
  }

  Future<String> createFleet({
    required String name,
    required String code,
    String status = 'active',
    String? description,
    int? adminId,
  }) async {
    final result = await _authorized(
      'POST',
      '/management/fleets',
      body: {
        'name': name,
        'code': code,
        'description': description,
        'status': status,
        'admin_id': adminId,
      },
    );
    return result.body['message']?.toString() ?? '';
  }

  Future<String> updateFleet({
    required int id,
    required String name,
    required String code,
    required String status,
    String? description,
    int? adminId,
  }) async {
    final result = await _authorized(
      'PUT',
      '/management/fleets/$id',
      body: {
        'name': name,
        'code': code,
        'description': description,
        'status': status,
        'admin_id': adminId,
      },
    );
    return result.body['message']?.toString() ?? '';
  }

  Future<String> deleteFleet(int id) async {
    final result = await _authorized('DELETE', '/management/fleets/$id');
    return result.body['message']?.toString() ?? '';
  }

  Future<UserManagementData> managedUsers() async {
    final users = <ManagedUserData>[];
    UserManagementData? managementData;
    var page = 1;
    var lastPage = 1;

    do {
      final result = await _authorized(
        'GET',
        '/management/users',
        query: {'page': '$page', 'per_page': '100'},
      );
      final current = UserManagementData.fromMap(result.body);
      managementData ??= current;
      users.addAll(current.users);
      lastPage = intOf(mapOf(result.body['meta'])['last_page']);
      if (lastPage < 1) lastPage = 1;
      page++;
    } while (page <= lastPage);

    final data = managementData;
    return UserManagementData(
      users: users,
      fleets: data.fleets,
      roles: data.roles,
      permissions: data.permissions,
      canCreate: data.canCreate,
    );
  }

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
  }) async {
    final result = await _authorized(
      id == null ? 'POST' : 'PUT',
      id == null ? '/management/users' : '/management/users/$id',
      body: {
        'name': name,
        'email': email,
        'role': role,
        'fleet_id': fleetId,
        'permissions': permissions,
        'password': password,
        'password_confirmation': password,
        'phone': phone,
        'address': address,
      },
    );
    return result.body['message']?.toString() ?? '';
  }

  Future<String> deleteManagedUser(int id) async {
    final result = await _authorized('DELETE', '/management/users/$id');
    return result.body['message']?.toString() ?? '';
  }

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
  }) async {
    final result = await _authorized(
      'POST',
      '/management/vehicles',
      body: {
        'fleet_id': fleetId,
        'name': name,
        'registration_number': registration,
        'vehicle_type': vehicleType,
        'brand': brand,
        'model': model,
        'color': color,
        'year': year,
        'speed_limit_kmh': speedLimitKmh,
        'status': status,
      },
    );
    return result.body['message']?.toString() ?? '';
  }

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
  }) async {
    final result = await _authorized(
      'PUT',
      '/management/vehicles/$id',
      body: {
        'fleet_id': fleetId,
        'name': name,
        'registration_number': registration,
        'vehicle_type': vehicleType,
        'brand': brand,
        'model': model,
        'color': color,
        'year': year,
        'speed_limit_kmh': speedLimitKmh,
        'status': status,
      },
    );
    return result.body['message']?.toString() ?? '';
  }

  Future<String> deleteVehicle(int id) async {
    final result = await _authorized('DELETE', '/management/vehicles/$id');
    return result.body['message']?.toString() ?? '';
  }

  Future<String> createTracker({
    required int vehicleId,
    required String imei,
    required String brand,
    required String model,
    required String protocol,
    String? name,
    String? simNumber,
    String? operatorName,
  }) async {
    final result = await _authorized(
      'POST',
      '/management/trackers',
      body: {
        'vehicle_id': vehicleId,
        'imei': imei,
        'brand': brand,
        'model': model,
        'protocol': protocol,
        'name': name,
        'sim_number': simNumber,
        'operator_name': operatorName,
      },
    );
    return result.body['message']?.toString() ?? '';
  }

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
  }) async {
    final result = await _authorized(
      'PUT',
      '/management/trackers/$id',
      body: {
        'vehicle_id': vehicleId,
        'imei': imei,
        'brand': brand,
        'model': model,
        'protocol': protocol,
        'name': name,
        'sim_number': simNumber,
        'operator_name': operatorName,
      },
    );
    return result.body['message']?.toString() ?? '';
  }

  Future<String> deleteTracker(int id) async {
    final result = await _authorized('DELETE', '/management/trackers/$id');
    return result.body['message']?.toString() ?? '';
  }

  Future<List<DriverData>> drivers() async {
    final drivers = <DriverData>[];
    var page = 1;
    var lastPage = 1;

    do {
      final result = await _authorized(
        'GET',
        '/drivers',
        query: {'per_page': '50', 'page': '$page'},
      );
      drivers.addAll(listOfMaps(result.body['data']).map(DriverData.fromMap));
      lastPage = intOf(mapOf(result.body['meta'])['last_page']);
      if (lastPage < 1) lastPage = 1;
      page++;
    } while (page <= lastPage);

    return drivers;
  }

  Future<DepartmentCollectionData> departments() async {
    final departments = <DepartmentData>[];
    var page = 1;
    var lastPage = 1;
    DepartmentCollectionData? collection;

    do {
      final result = await _authorized(
        'GET',
        '/departments',
        query: {'per_page': '100', 'page': '$page'},
      );
      collection = DepartmentCollectionData.fromMap(result.body);
      departments.addAll(collection.departments);
      lastPage = intOf(mapOf(result.body['meta'])['last_page']);
      if (lastPage < 1) lastPage = 1;
      page++;
    } while (page <= lastPage);

    return DepartmentCollectionData(
      departments: departments,
      fleets: collection.fleets,
      canManage: collection.canManage,
      canDelete: collection.canDelete,
    );
  }

  Future<String> saveDepartment({
    int? id,
    required int fleetId,
    required String name,
    String? code,
    String? description,
    required String status,
  }) async {
    final result = await _authorized(
      id == null ? 'POST' : 'PUT',
      id == null ? '/departments' : '/departments/$id',
      body: {
        'fleet_id': fleetId,
        'name': name,
        'code': code,
        'description': description,
        'status': status,
      },
    );
    return result.body['message']?.toString() ?? '';
  }

  Future<String> deleteDepartment(int id) async {
    final result = await _authorized('DELETE', '/departments/$id');
    return result.body['message']?.toString() ?? '';
  }

  Future<VehicleDetailData> vehicleDetails(int vehicleId) async {
    final result = await _authorized('GET', '/vehicles/$vehicleId/details');
    return VehicleDetailData.fromMap(mapOf(result.body['data']));
  }

  Future<String> requestEngineCommand(
    int vehicleId,
    String action,
    int output,
  ) async {
    final result = await _authorized(
      'POST',
      '/vehicles/$vehicleId/engine-commands',
      body: {'action': action, 'output': output, 'confirmation': true},
    );
    return result.body['message']?.toString() ?? '';
  }

  Future<List<VehicleEventData>> vehicleEvents(int vehicleId) async {
    final result = await _authorized(
      'GET',
      '/events',
      query: {'vehicle_id': '$vehicleId', 'per_page': '50'},
    );
    return listOfMaps(
      result.body['data'],
    ).map(VehicleEventData.fromMap).toList();
  }

  Future<List<VehicleEventData>> notificationEvents({int? afterId}) async {
    final result = await _authorized(
      'GET',
      '/events',
      query: {'per_page': '50', if (afterId != null) 'after_id': '$afterId'},
    );
    return listOfMaps(
      result.body['data'],
    ).map(VehicleEventData.fromMap).toList();
  }

  Future<VehicleTripsData> vehicleTrips(
    int vehicleId, {
    String period = 'today',
    String? startDate,
    String? endDate,
  }) async {
    final result = await _authorized(
      'GET',
      '/vehicles/$vehicleId/trips',
      query: {'period': period, 'start_date': ?startDate, 'end_date': ?endDate},
    );
    return VehicleTripsData.fromMap(mapOf(result.body['data']));
  }

  Future<List<AlertData>> alerts() async {
    final result = await _authorized(
      'GET',
      '/alerts',
      query: {'per_page': '50'},
    );
    return listOfMaps(result.body['data']).map(AlertData.fromMap).toList();
  }

  Future<List<AlertData>> notificationAlerts({int? afterId}) async {
    final result = await _authorized(
      'GET',
      '/alerts',
      query: {'per_page': '50', if (afterId != null) 'after_id': '$afterId'},
    );
    return listOfMaps(result.body['data']).map(AlertData.fromMap).toList();
  }

  Future<void> registerPushDevice({
    required String token,
    required String locale,
    required String appVersion,
  }) async {
    await _authorized(
      'PUT',
      '/push-devices/current',
      body: {
        'token': token,
        'platform': 'android',
        'locale': locale,
        'app_version': appVersion,
      },
    );
  }

  Future<NotificationPreferencesData> notificationPreferences() async {
    final result = await _authorized('GET', '/notification-preferences');
    return NotificationPreferencesData.fromMap(mapOf(result.body['data']));
  }

  Future<NotificationPreferencesData> updateNotificationPreferences({
    required bool vehicleEventsEnabled,
    required bool alertsEnabled,
  }) async {
    final result = await _authorized(
      'PATCH',
      '/notification-preferences',
      body: {
        'vehicle_events_enabled': vehicleEventsEnabled,
        'alerts_enabled': alertsEnabled,
      },
    );
    return NotificationPreferencesData.fromMap(mapOf(result.body['data']));
  }

  Future<List<VehicleData>> mapVehicles() async {
    final result = await _authorized('GET', '/map/vehicles');
    final data = mapOf(result.body['data']);
    final geoJson = mapOf(data['geojson']);
    return listOfMaps(
      geoJson['features'],
    ).map(VehicleData.fromMapFeature).toList();
  }

  Future<void> logout() async {
    try {
      await _authorized('POST', '/auth/logout', allowRefresh: false);
    } finally {
      await _tokenStore.clearTokens();
    }
  }

  Future<ApiResult> _authorized(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool allowRefresh = true,
  }) async {
    final tokens = await _tokenStore.readTokens();
    if (tokens == null) {
      throw const ApiException(
        message: 'Votre session mobile est fermée.',
        statusCode: 401,
        code: 'NO_MOBILE_SESSION',
      );
    }

    try {
      return await _send(
        method,
        path,
        query: query,
        body: body,
        bearerToken: tokens.accessToken,
      );
    } on ApiException catch (error) {
      if (!allowRefresh || !error.isUnauthorized) rethrow;
      final current = await _tokenStore.readTokens();
      final refreshed =
          current != null && current.accessToken != tokens.accessToken
          ? current
          : await _refreshSingleFlight(tokens.refreshToken);
      return _send(
        method,
        path,
        query: query,
        body: body,
        bearerToken: refreshed.accessToken,
      );
    }
  }

  Future<AuthTokens> _refreshSingleFlight(String refreshToken) {
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    final future = _refresh(refreshToken);
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    });
  }

  Future<AuthTokens> _refresh(String refreshToken) async {
    try {
      final result = await _send(
        'POST',
        '/auth/refresh',
        bearerToken: refreshToken,
      );
      final data = mapOf(result.body['data']);
      final tokens = AuthTokens.fromMap(mapOf(data['tokens']));
      if (!tokens.isValid) {
        throw const ApiException(
          message: 'La réponse de renouvellement est incomplète.',
          statusCode: 401,
        );
      }
      await _tokenStore.writeTokens(tokens);
      return tokens;
    } on ApiException catch (error) {
      // A timeout, a server error or a temporary loss of connectivity must
      // never destroy a valid session. Only an explicit rejection of the
      // refresh token by the authentication server closes it.
      if (error.isUnauthorized) {
        final current = await _tokenStore.readTokens();
        if (current?.refreshToken == refreshToken) {
          await _tokenStore.clearTokens();
        }
      }
      rethrow;
    }
  }

  AuthenticationResult _authenticationResult(Map<String, dynamic> body) {
    final data = mapOf(body['data']);
    if (data['two_factor_required'] == true) {
      return AuthenticationResult(
        twoFactorRequired: true,
        challengeToken: data['challenge_token']?.toString(),
        challengeExpiresIn: intOf(data['expires_in']),
      );
    }

    final tokens = AuthTokens.fromMap(mapOf(data['tokens']));
    if (!tokens.isValid) {
      throw const ApiException(
        message: 'Le serveur n’a pas retourné une session mobile valide.',
      );
    }
    return AuthenticationResult(twoFactorRequired: false, tokens: tokens);
  }

  Future<ApiResult> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    String? bearerToken,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Accept-Language': _languageCode,
      'Content-Type': 'application/json',
      if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
    };

    try {
      final future = switch (method) {
        'POST' => _client.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        'PUT' => _client.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        'PATCH' => _client.patch(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        'DELETE' => _client.delete(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        _ => _client.get(uri, headers: headers),
      };
      final response = await future.timeout(const Duration(seconds: 18));
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final responseBody = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResult(response.statusCode, responseBody);
      }

      throw _exceptionFromResponse(response.statusCode, responseBody);
    } on TimeoutException {
      throw const ApiException(
        message: 'Le serveur met trop de temps à répondre.',
      );
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException(message: 'La réponse du serveur est invalide.');
    } catch (_) {
      throw const ApiException(
        message: 'Impossible de joindre le serveur EXAD Tracking.',
      );
    }
  }

  ApiException _exceptionFromResponse(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    final error = mapOf(body['error']);
    final rawErrors = mapOf(body['errors']);
    final fieldErrors = <String, String>{};
    for (final entry in rawErrors.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        fieldErrors[entry.key] = value.first.toString();
      } else if (value != null) {
        fieldErrors[entry.key] = value.toString();
      }
    }

    return ApiException(
      statusCode: statusCode,
      code: error['code']?.toString(),
      message:
          error['message']?.toString() ??
          body['message']?.toString() ??
          fieldErrors.values.firstOrNull ??
          'La requête n’a pas pu être traitée.',
      fieldErrors: fieldErrors,
    );
  }
}
