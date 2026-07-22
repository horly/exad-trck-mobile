import 'package:flutter/material.dart';

Map<String, dynamic> mapOf(dynamic value) {
  return value is Map<String, dynamic> ? value : <String, dynamic>{};
}

List<Map<String, dynamic>> listOfMaps(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList(growable: false);
}

int intOf(dynamic value) {
  if (value is int) return value;
  return int.tryParse('$value') ?? 0;
}

double? doubleOf(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
  });

  final String accessToken;
  final String refreshToken;
  final String sessionId;

  factory AuthTokens.fromMap(Map<String, dynamic> map) {
    return AuthTokens(
      accessToken: map['access_token']?.toString() ?? '',
      refreshToken: map['refresh_token']?.toString() ?? '',
      sessionId: map['session_id']?.toString() ?? '',
    );
  }

  bool get isValid => accessToken.isNotEmpty && refreshToken.isNotEmpty;
}

class FleetInfo {
  const FleetInfo({required this.id, required this.name, required this.code});

  final int id;
  final String name;
  final String code;

  factory FleetInfo.fromMap(Map<String, dynamic> map) {
    return FleetInfo(
      id: intOf(map['id']),
      name: map['name']?.toString() ?? '-',
      code: map['code']?.toString() ?? '-',
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    required this.twoFactorEnabled,
    this.phone,
    this.photoUrl,
    this.fleet,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? photoUrl;
  final FleetInfo? fleet;
  final Map<String, bool> permissions;
  final bool twoFactorEnabled;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final rawPermissions = mapOf(map['permissions']);
    final fleet = mapOf(map['fleet']);
    return AppUser(
      id: intOf(map['id']),
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      role: map['role']?.toString() ?? 'user',
      phone: map['phone']?.toString(),
      photoUrl: map['profile_photo_url']?.toString(),
      fleet: fleet.isEmpty ? null : FleetInfo.fromMap(fleet),
      permissions: rawPermissions.map(
        (key, value) => MapEntry(key, value == true),
      ),
      twoFactorEnabled: map['two_factor_enabled'] == true,
    );
  }

  bool hasPermission(String permission) => permissions[permission] == true;

  bool get isSuperadmin => role.toLowerCase() == 'superadmin';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class BrandingData {
  const BrandingData({
    required this.appName,
    required this.shortName,
    required this.primary,
    required this.secondary,
    required this.button,
    required this.accent,
    this.logoUrl,
    this.internalLogoUrl,
    this.supportEmail,
    this.supportPhone,
  });

  final String appName;
  final String shortName;
  final String? logoUrl;
  final String? internalLogoUrl;
  final Color primary;
  final Color secondary;
  final Color button;
  final Color accent;
  final String? supportEmail;
  final String? supportPhone;

  factory BrandingData.fromMap(Map<String, dynamic> map) {
    final colors = mapOf(map['colors']);
    final support = mapOf(map['support']);
    return BrandingData(
      appName: map['app_name']?.toString() ?? 'EXAD Tracking',
      shortName: map['short_name']?.toString() ?? 'EXAD Tracking',
      logoUrl: map['logo_url']?.toString(),
      internalLogoUrl: map['internal_logo_url']?.toString(),
      primary: colorFromHex(
        colors['primary']?.toString(),
        const Color(0xFF171064),
      ),
      secondary: colorFromHex(
        colors['secondary']?.toString(),
        const Color(0xFF2F67E8),
      ),
      button: colorFromHex(
        colors['button']?.toString(),
        const Color(0xFF171064),
      ),
      accent: colorFromHex(
        colors['accent']?.toString(),
        const Color(0xFF6D3DF2),
      ),
      supportEmail: support['email']?.toString(),
      supportPhone: support['phone']?.toString(),
    );
  }

  static const fallback = BrandingData(
    appName: 'EXAD Tracking',
    shortName: 'EXAD Tracking',
    primary: Color(0xFF171064),
    secondary: Color(0xFF2F67E8),
    button: Color(0xFF171064),
    accent: Color(0xFF6D3DF2),
  );
}

Color colorFromHex(String? value, Color fallback) {
  if (value == null) return fallback;
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return fallback;
  return Color(0xFF000000 | parsed);
}

class BootstrapData {
  const BootstrapData({required this.user, required this.branding});

  final AppUser user;
  final BrandingData branding;

  factory BootstrapData.fromMap(Map<String, dynamic> map) {
    return BootstrapData(
      user: AppUser.fromMap(mapOf(map['user'])),
      branding: BrandingData.fromMap(mapOf(map['branding'])),
    );
  }
}

class VehicleData {
  const VehicleData({
    required this.id,
    required this.name,
    required this.registration,
    required this.status,
    required this.trackingStatus,
    required this.isOnline,
    required this.speed,
    this.trackingConfigured = false,
    this.isMoving = false,
    this.isParking = false,
    this.isStationaryRunning = false,
    this.trail = const [],
    this.heading,
    this.ignition,
    this.movement,
    this.brand,
    this.model,
    this.address,
    this.latitude,
    this.longitude,
    this.lastSignalAt,
    this.fleet,
  });

  final int id;
  final String name;
  final String registration;
  final String? brand;
  final String? model;
  final String status;
  final String trackingStatus;
  final bool isOnline;
  final int speed;
  final bool trackingConfigured;
  final bool isMoving;
  final bool isParking;
  final bool isStationaryRunning;
  final List<GeoCoordinateData> trail;
  final int? heading;
  final bool? ignition;
  final bool? movement;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? lastSignalAt;
  final FleetInfo? fleet;

  factory VehicleData.fromMap(Map<String, dynamic> map) {
    final tracking = mapOf(map['tracking']);
    final position = mapOf(tracking['position']);
    final fleet = mapOf(map['fleet']);
    return VehicleData(
      id: intOf(map['id']),
      name: map['name']?.toString() ?? 'Véhicule',
      registration: map['registration_number']?.toString() ?? '-',
      brand: map['brand']?.toString(),
      model: map['model']?.toString(),
      status: map['status']?.toString() ?? 'inactive',
      trackingStatus: tracking['status']?.toString() ?? 'not_configured',
      isOnline: tracking['online'] == true,
      speed: intOf(tracking['speed_kmh']),
      trackingConfigured: tracking['configured'] == true,
      isMoving:
          tracking['online'] == true &&
          tracking['ignition'] != false &&
          tracking['movement'] == true,
      isParking: tracking['online'] == true && tracking['ignition'] == false,
      isStationaryRunning:
          tracking['online'] == true &&
          tracking['ignition'] == true &&
          tracking['movement'] != true,
      heading: tracking['heading'] == null ? null : intOf(tracking['heading']),
      ignition: tracking['ignition'] as bool?,
      movement: tracking['movement'] as bool?,
      address: position['address']?.toString(),
      latitude: doubleOf(position['latitude']),
      longitude: doubleOf(position['longitude']),
      lastSignalAt: tracking['last_signal_at']?.toString(),
      fleet: fleet.isEmpty ? null : FleetInfo.fromMap(fleet),
    );
  }

  factory VehicleData.fromMapFeature(Map<String, dynamic> feature) {
    final properties = mapOf(feature['properties']);
    final geometry = mapOf(feature['geometry']);
    final coordinates = geometry['coordinates'] is List
        ? geometry['coordinates'] as List
        : const [];
    final fleet = mapOf(properties['fleet']);
    final rawTrail = properties['trail'] is List
        ? properties['trail'] as List
        : const [];
    final trail = <GeoCoordinateData>[];
    for (final coordinate in rawTrail) {
      if (coordinate is! List || coordinate.length < 2) continue;
      final longitude = doubleOf(coordinate[0]);
      final latitude = doubleOf(coordinate[1]);
      if (latitude == null || longitude == null) continue;
      trail.add(GeoCoordinateData(latitude, longitude));
    }
    return VehicleData(
      id: intOf(properties['vehicle_id']),
      name: properties['vehicle']?.toString() ?? 'Véhicule',
      registration: properties['registration_number']?.toString() ?? '-',
      status: 'active',
      trackingStatus: properties['status']?.toString() ?? 'inactive',
      isOnline: properties['status'] == 'online',
      speed: intOf(properties['speed_kmh']),
      trackingConfigured: true,
      isMoving: properties['is_moving'] == true,
      isParking: properties['is_parking'] == true,
      isStationaryRunning: properties['is_stationary_running'] == true,
      trail: trail,
      heading: properties['heading'] == null
          ? null
          : intOf(properties['heading']),
      ignition: properties['ignition'] as bool?,
      movement: properties['movement'] as bool?,
      address: properties['address']?.toString(),
      longitude: coordinates.isNotEmpty ? doubleOf(coordinates[0]) : null,
      latitude: coordinates.length > 1 ? doubleOf(coordinates[1]) : null,
      lastSignalAt: properties['last_signal_at']?.toString(),
      fleet: fleet.isEmpty ? null : FleetInfo.fromMap(fleet),
    );
  }
}

class VehicleDetailData {
  const VehicleDetailData({
    required this.vehicle,
    required this.recentEvents,
    this.tracker,
    this.location,
    this.driver,
    this.power,
    this.gsm,
    this.diagnostic,
    this.obdCan,
  });

  final VehicleData vehicle;
  final VehicleTrackerDetail? tracker;
  final VehicleLocationDetail? location;
  final VehicleDriverDetail? driver;
  final VehiclePowerDetail? power;
  final VehicleGsmDetail? gsm;
  final VehicleDiagnosticDetail? diagnostic;
  final VehicleObdDetail? obdCan;
  final List<VehicleEventData> recentEvents;

  factory VehicleDetailData.fromMap(Map<String, dynamic> map) {
    final details = mapOf(map['details']);
    final tracker = mapOf(details['tracker']);
    final location = mapOf(details['location']);
    final driver = mapOf(details['driver']);
    final power = mapOf(details['power']);
    final gsm = mapOf(details['gsm']);
    final diagnostic = mapOf(details['diagnostic']);
    final obdCan = mapOf(details['obd_can']);
    return VehicleDetailData(
      vehicle: VehicleData.fromMap(map),
      tracker: tracker.isEmpty ? null : VehicleTrackerDetail.fromMap(tracker),
      location: location.isEmpty
          ? null
          : VehicleLocationDetail.fromMap(location),
      driver: driver.isEmpty ? null : VehicleDriverDetail.fromMap(driver),
      power: power.isEmpty ? null : VehiclePowerDetail.fromMap(power),
      gsm: gsm.isEmpty ? null : VehicleGsmDetail.fromMap(gsm),
      diagnostic: diagnostic.isEmpty
          ? null
          : VehicleDiagnosticDetail.fromMap(diagnostic),
      obdCan: obdCan.isEmpty ? null : VehicleObdDetail.fromMap(obdCan),
      recentEvents: listOfMaps(
        details['recent_events'],
      ).map(VehicleEventData.fromMap).toList(),
    );
  }
}

class VehicleTrackerDetail {
  const VehicleTrackerDetail({
    required this.id,
    required this.name,
    required this.imei,
    this.brand,
    this.model,
  });

  final int id;
  final String name;
  final String imei;
  final String? brand;
  final String? model;

  factory VehicleTrackerDetail.fromMap(Map<String, dynamic> map) {
    return VehicleTrackerDetail(
      id: intOf(map['id']),
      name: map['name']?.toString() ?? '-',
      imei: map['imei']?.toString() ?? '-',
      brand: map['brand']?.toString(),
      model: map['model']?.toString(),
    );
  }
}

class VehicleLocationDetail {
  const VehicleLocationDetail({
    this.gpsQualityPercent,
    this.latitude,
    this.longitude,
    this.altitudeMeters,
    this.address,
    this.headingDegrees,
    this.movement,
    this.ignition,
    this.parkingStartedAt,
    this.updatedAt,
  });

  final int? gpsQualityPercent;
  final double? latitude;
  final double? longitude;
  final double? altitudeMeters;
  final String? address;
  final int? headingDegrees;
  final bool? movement;
  final bool? ignition;
  final String? parkingStartedAt;
  final String? updatedAt;

  factory VehicleLocationDetail.fromMap(Map<String, dynamic> map) {
    return VehicleLocationDetail(
      gpsQualityPercent: map['gps_quality_percent'] == null
          ? null
          : intOf(map['gps_quality_percent']),
      latitude: doubleOf(map['latitude']),
      longitude: doubleOf(map['longitude']),
      altitudeMeters: doubleOf(map['altitude_meters']),
      address: map['address']?.toString(),
      headingDegrees: map['heading_degrees'] == null
          ? null
          : intOf(map['heading_degrees']),
      movement: map['movement'] as bool?,
      ignition: map['ignition'] as bool?,
      parkingStartedAt: map['parking_started_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}

class VehicleDriverDetail {
  const VehicleDriverDetail({
    required this.fullName,
    this.employeeId,
    this.department,
    this.identifierUid,
    this.identifierType,
    this.phone,
    this.status,
  });

  final String fullName;
  final String? employeeId;
  final String? department;
  final String? identifierUid;
  final String? identifierType;
  final String? phone;
  final String? status;

  factory VehicleDriverDetail.fromMap(Map<String, dynamic> map) {
    return VehicleDriverDetail(
      fullName: map['full_name']?.toString() ?? '-',
      employeeId: map['employee_id']?.toString(),
      department: map['department']?.toString(),
      identifierUid: map['identifier_uid']?.toString(),
      identifierType: map['identifier_type']?.toString(),
      phone: map['phone']?.toString(),
      status: map['status']?.toString(),
    );
  }
}

class VehiclePowerDetail {
  const VehiclePowerDetail({
    this.externalVoltage,
    this.internalBatteryVoltage,
    this.batteryLevelPercent,
    this.ignition,
    this.updatedAt,
  });

  final double? externalVoltage;
  final double? internalBatteryVoltage;
  final int? batteryLevelPercent;
  final bool? ignition;
  final String? updatedAt;

  factory VehiclePowerDetail.fromMap(Map<String, dynamic> map) {
    return VehiclePowerDetail(
      externalVoltage: doubleOf(map['external_voltage']),
      internalBatteryVoltage: doubleOf(map['internal_battery_voltage']),
      batteryLevelPercent: map['battery_level_percent'] == null
          ? null
          : intOf(map['battery_level_percent']),
      ignition: map['ignition'] as bool?,
      updatedAt: map['updated_at']?.toString(),
    );
  }
}

class VehicleGsmDetail {
  const VehicleGsmDetail({
    this.signalPercent,
    this.operatorName,
    this.simNumber,
    this.codec,
    this.updatedAt,
  });

  final int? signalPercent;
  final String? operatorName;
  final String? simNumber;
  final String? codec;
  final String? updatedAt;

  factory VehicleGsmDetail.fromMap(Map<String, dynamic> map) {
    return VehicleGsmDetail(
      signalPercent: map['signal_percent'] == null
          ? null
          : intOf(map['signal_percent']),
      operatorName: map['operator_name']?.toString(),
      simNumber: map['sim_number']?.toString(),
      codec: map['codec']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}

class VehicleDiagnosticDetail {
  const VehicleDiagnosticDetail({
    this.satellites,
    this.protocol,
    this.driverIdentifierUid,
    this.odometerKm,
    this.engineSeconds,
    required this.ioCount,
    required this.sensorCount,
    this.updatedAt,
  });

  final int? satellites;
  final String? protocol;
  final String? driverIdentifierUid;
  final double? odometerKm;
  final int? engineSeconds;
  final int ioCount;
  final int sensorCount;
  final String? updatedAt;

  factory VehicleDiagnosticDetail.fromMap(Map<String, dynamic> map) {
    return VehicleDiagnosticDetail(
      satellites: map['satellites'] == null ? null : intOf(map['satellites']),
      protocol: map['protocol']?.toString(),
      driverIdentifierUid: map['driver_identifier_uid']?.toString(),
      odometerKm: doubleOf(map['odometer_km']),
      engineSeconds: map['engine_seconds'] == null
          ? null
          : intOf(map['engine_seconds']),
      ioCount: intOf(map['io_count']),
      sensorCount: intOf(map['sensor_count']),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}

class VehicleObdDetail {
  const VehicleObdDetail({
    this.runtimeSeconds,
    this.rpm,
    this.speedKmh,
    this.throttlePercent,
    this.engineTemperatureC,
    this.moduleVoltage,
    this.engineLoadPercent,
    this.fuelLevelPercent,
    this.faultDistanceKm,
    this.errorsCount,
    this.distanceSinceClearKm,
    this.updatedAt,
  });

  final int? runtimeSeconds;
  final int? rpm;
  final int? speedKmh;
  final double? throttlePercent;
  final double? engineTemperatureC;
  final double? moduleVoltage;
  final double? engineLoadPercent;
  final double? fuelLevelPercent;
  final int? faultDistanceKm;
  final int? errorsCount;
  final int? distanceSinceClearKm;
  final String? updatedAt;

  bool get hasData =>
      runtimeSeconds != null ||
      rpm != null ||
      speedKmh != null ||
      throttlePercent != null ||
      engineTemperatureC != null ||
      moduleVoltage != null ||
      engineLoadPercent != null ||
      fuelLevelPercent != null ||
      faultDistanceKm != null ||
      errorsCount != null ||
      distanceSinceClearKm != null;

  factory VehicleObdDetail.fromMap(Map<String, dynamic> map) {
    return VehicleObdDetail(
      runtimeSeconds: map['runtime_seconds'] == null
          ? null
          : intOf(map['runtime_seconds']),
      rpm: map['rpm'] == null ? null : intOf(map['rpm']),
      speedKmh: map['speed_kmh'] == null ? null : intOf(map['speed_kmh']),
      throttlePercent: doubleOf(map['throttle_percent']),
      engineTemperatureC: doubleOf(map['engine_temperature_c']),
      moduleVoltage: doubleOf(map['module_voltage']),
      engineLoadPercent: doubleOf(map['engine_load_percent']),
      fuelLevelPercent: doubleOf(map['fuel_level_percent']),
      faultDistanceKm: map['fault_distance_km'] == null
          ? null
          : intOf(map['fault_distance_km']),
      errorsCount: map['errors_count'] == null
          ? null
          : intOf(map['errors_count']),
      distanceSinceClearKm: map['distance_since_clear_km'] == null
          ? null
          : intOf(map['distance_since_clear_km']),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}

class VehicleEventData {
  const VehicleEventData({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.startedAt,
    this.endedAt,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String type;
  final String title;
  final String message;
  final String? startedAt;
  final String? endedAt;
  final double? latitude;
  final double? longitude;

  factory VehicleEventData.fromMap(Map<String, dynamic> map) {
    final location = mapOf(map['location']);
    return VehicleEventData(
      id: intOf(map['id']),
      type: map['type']?.toString() ?? 'event',
      title: map['title']?.toString() ?? 'Evenement',
      message: map['message']?.toString() ?? '',
      startedAt: map['started_at']?.toString(),
      endedAt: map['ended_at']?.toString(),
      latitude: doubleOf(location['latitude']),
      longitude: doubleOf(location['longitude']),
    );
  }
}

class GeoCoordinateData {
  const GeoCoordinateData(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class VehicleTripData {
  const VehicleTripData({
    required this.id,
    required this.index,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.startAddress,
    required this.endAddress,
    required this.distanceKm,
    required this.durationSeconds,
    required this.averageSpeedKmh,
    required this.maxSpeedKmh,
    required this.color,
    required this.coordinates,
  });

  final String id;
  final int index;
  final String date;
  final String startTime;
  final String endTime;
  final String startAddress;
  final String endAddress;
  final double distanceKm;
  final int durationSeconds;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
  final Color color;
  final List<GeoCoordinateData> coordinates;

  factory VehicleTripData.fromMap(Map<String, dynamic> map) {
    final rawCoordinates = map['coordinates'] is List
        ? map['coordinates'] as List
        : const [];
    final coordinates = <GeoCoordinateData>[];
    for (final coordinate in rawCoordinates) {
      if (coordinate is! List || coordinate.length < 2) continue;
      final longitude = doubleOf(coordinate[0]);
      final latitude = doubleOf(coordinate[1]);
      if (latitude == null || longitude == null) continue;
      coordinates.add(GeoCoordinateData(latitude, longitude));
    }

    return VehicleTripData(
      id: map['id']?.toString() ?? 'trip-${intOf(map['index'])}',
      index: intOf(map['index']),
      date: map['date']?.toString() ?? '-',
      startTime: map['start_time']?.toString() ?? '-',
      endTime: map['end_time']?.toString() ?? '-',
      startAddress: map['start_address']?.toString() ?? '-',
      endAddress: map['end_address']?.toString() ?? '-',
      distanceKm: doubleOf(map['distance_km']) ?? 0,
      durationSeconds: intOf(map['duration_seconds']),
      averageSpeedKmh: doubleOf(map['average_speed_kmh']) ?? 0,
      maxSpeedKmh: doubleOf(map['max_speed_kmh']) ?? 0,
      color: colorFromHex(map['color']?.toString(), const Color(0xFF2563EB)),
      coordinates: coordinates,
    );
  }
}

class VehicleTripsData {
  const VehicleTripsData({
    required this.trackingConfigured,
    required this.count,
    required this.distanceKm,
    required this.durationSeconds,
    required this.trips,
  });

  final bool trackingConfigured;
  final int count;
  final double distanceKm;
  final int durationSeconds;
  final List<VehicleTripData> trips;

  factory VehicleTripsData.fromMap(Map<String, dynamic> map) {
    final summary = mapOf(map['summary']);
    return VehicleTripsData(
      trackingConfigured: map['tracking_configured'] == true,
      count: intOf(summary['count']),
      distanceKm: doubleOf(summary['distance_km']) ?? 0,
      durationSeconds: intOf(summary['duration_seconds']),
      trips: listOfMaps(map['trips']).map(VehicleTripData.fromMap).toList(),
    );
  }
}

class AlertData {
  const AlertData({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.status,
    this.vehicle,
    this.occurredAt,
  });

  final int id;
  final String title;
  final String message;
  final String severity;
  final String status;
  final String? vehicle;
  final String? occurredAt;

  factory AlertData.fromMap(Map<String, dynamic> map) {
    final vehicle = mapOf(map['vehicle']);
    return AlertData(
      id: intOf(map['id']),
      title: map['title']?.toString() ?? 'Alerte',
      message: map['message']?.toString() ?? '',
      severity: map['severity']?.toString() ?? 'info',
      status: map['status']?.toString() ?? 'new',
      vehicle: vehicle['name']?.toString(),
      occurredAt: map['occurred_at']?.toString(),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.totalVehicles,
    required this.onlineVehicles,
    required this.movingVehicles,
    required this.attentionVehicles,
    required this.newAlerts,
    required this.vehicles,
    required this.alerts,
    this.totalFleets = 0,
    this.fleetDistribution = const [],
  });

  final int totalVehicles;
  final int onlineVehicles;
  final int movingVehicles;
  final int attentionVehicles;
  final int newAlerts;
  final List<VehicleData> vehicles;
  final List<AlertData> alerts;
  final int totalFleets;
  final List<FleetSummary> fleetDistribution;

  factory DashboardData.fromMap(Map<String, dynamic> map) {
    final summary = mapOf(map['summary']);
    return DashboardData(
      totalVehicles: intOf(summary['vehicles_total']),
      onlineVehicles: intOf(summary['vehicles_online']),
      movingVehicles: intOf(summary['vehicles_moving']),
      attentionVehicles: intOf(summary['vehicles_attention']),
      newAlerts: intOf(summary['new_alerts']),
      totalFleets: intOf(summary['fleets_total']),
      vehicles: listOfMaps(map['vehicles']).map(VehicleData.fromMap).toList(),
      alerts: listOfMaps(map['recent_alerts']).map(AlertData.fromMap).toList(),
      fleetDistribution: listOfMaps(
        map['fleet_distribution'],
      ).map(FleetSummary.fromMap).toList(),
    );
  }

  static const empty = DashboardData(
    totalVehicles: 0,
    onlineVehicles: 0,
    movingVehicles: 0,
    attentionVehicles: 0,
    newAlerts: 0,
    vehicles: [],
    alerts: [],
  );
}

class FleetSummary {
  const FleetSummary({
    required this.id,
    required this.name,
    required this.code,
    required this.totalVehicles,
    required this.onlineVehicles,
  });

  final int id;
  final String name;
  final String code;
  final int totalVehicles;
  final int onlineVehicles;

  factory FleetSummary.fromMap(Map<String, dynamic> map) {
    return FleetSummary(
      id: intOf(map['id']),
      name: map['name']?.toString() ?? '-',
      code: map['code']?.toString() ?? '-',
      totalVehicles: intOf(map['vehicles_total']),
      onlineVehicles: intOf(map['vehicles_online']),
    );
  }
}
