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
        'app_version': '1.0.0',
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

  Future<VehicleDetailData> vehicleDetails(int vehicleId) async {
    final result = await _authorized('GET', '/vehicles/$vehicleId/details');
    return VehicleDetailData.fromMap(mapOf(result.body['data']));
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

  Future<VehicleTripsData> vehicleTrips(
    int vehicleId, {
    String period = 'today',
  }) async {
    final result = await _authorized(
      'GET',
      '/vehicles/$vehicleId/trips',
      query: {'period': period},
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
        bearerToken: tokens.accessToken,
      );
    } on ApiException catch (error) {
      if (!allowRefresh || !error.isUnauthorized) rethrow;
      final refreshed = await _refresh(tokens.refreshToken);
      return _send(
        method,
        path,
        query: query,
        bearerToken: refreshed.accessToken,
      );
    }
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
    } on ApiException {
      await _tokenStore.clearTokens();
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
