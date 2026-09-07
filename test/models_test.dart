import 'package:exad_tracking_mobile/core/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse les etats et la trace live de la carte', () {
    final vehicle = VehicleData.fromMapFeature({
      'geometry': {
        'type': 'Point',
        'coordinates': [15.312, -4.325],
      },
      'properties': {
        'vehicle_id': 7,
        'vehicle': 'Toyota Hiace',
        'registration_number': '1234BV01',
        'status': 'online',
        'speed_kmh': 42,
        'heading': 90,
        'is_moving': true,
        'is_parking': false,
        'is_stationary_running': false,
        'gps_status': 'available',
        'gps_quality_percent': 70,
        'network_signal_percent': 80,
        'battery_level_percent': 88,
        'trail': [
          [15.310, -4.326],
          [15.311, -4.3255],
          [15.312, -4.325],
        ],
      },
    });

    expect(vehicle.isMoving, isTrue);
    expect(vehicle.isParking, isFalse);
    expect(vehicle.gpsStatus, 'available');
    expect(vehicle.gpsQualityPercent, 70);
    expect(vehicle.networkSignalPercent, 80);
    expect(vehicle.batteryLevelPercent, 88);
    expect(vehicle.heading, 90);
    expect(vehicle.trail, hasLength(3));
    expect(vehicle.trail.last.latitude, -4.325);
    expect(vehicle.trail.last.longitude, 15.312);
  });

  test(
    'garde le GPS disponible avec une position en ligne sans satellites',
    () {
      final vehicle = VehicleData.fromMapFeature({
        'geometry': {
          'type': 'Point',
          'coordinates': [15.312, -4.325],
        },
        'properties': {
          'vehicle_id': 8,
          'vehicle': 'Véhicule GPS',
          'registration_number': 'GPS-001',
          'status': 'online',
          'speed_kmh': 0,
        },
      });

      expect(vehicle.gpsQualityPercent, isNull);
      expect(vehicle.hasAvailableGps, isTrue);
    },
  );

  test('parse les rubriques operationnelles du detail vehicule', () {
    final data = VehicleDetailData.fromMap({
      'id': 12,
      'name': 'Toyota Hiace',
      'registration_number': '1234BV01',
      'status': 'active',
      'fleet': {'id': 2, 'name': 'EXAD CARS', 'code': 'EX-CRS'},
      'tracking': {
        'configured': true,
        'status': 'online',
        'online': true,
        'speed_kmh': 24,
      },
      'details': {
        'tracker': {
          'id': 91,
          'name': 'Traceur Direction',
          'imei': '868120000000001',
          'brand': 'teltonika',
          'model': 'FMB920',
        },
        'location': {
          'gps_quality_percent': 70,
          'latitude': -4.325,
          'longitude': 15.31,
          'heading_degrees': 90,
          'movement': true,
          'ignition': true,
          'address': 'Kinshasa',
        },
        'driver': {
          'full_name': 'Jean Conducteur',
          'identifier_uid': 'RFID-001',
        },
        'power': {'external_voltage': 12.8, 'battery_level_percent': 90},
        'gsm': {'signal_percent': 80, 'operator_name': 'Vodacom'},
        'diagnostic': {'satellites': 10, 'io_count': 2, 'sensor_count': 1},
        'obd_can': {
          'rpm': 1800,
          'engine_temperature_c': 84,
          'states': {
            'ignition_on': true,
            'engine_running': true,
            'front_left_door_open': false,
            'rear_right_door_open': true,
            'hood_open': false,
            'trunk_open': false,
            'doors_open': true,
          },
        },
        'engine_control': {
          'supported': true,
          'allowed': true,
          'immobilized': false,
          'busy': false,
          'next_action': 'immobilize',
          'outputs': {
            '1': {
              'number': 1,
              'active': false,
              'busy': false,
              'next_action': 'immobilize',
            },
            '2': {
              'number': 2,
              'active': true,
              'busy': true,
              'next_action': 'release',
            },
          },
        },
        'recent_events': [
          {
            'id': 1,
            'type': 'movement_started',
            'title': 'Debut de deplacement',
            'message': 'Le vehicule est en mouvement.',
          },
        ],
      },
    });

    expect(data.vehicle.name, 'Toyota Hiace');
    expect(data.tracker?.id, 91);
    expect(data.tracker?.imei, '868120000000001');
    expect(data.tracker?.model, 'FMB920');
    expect(data.location?.address, 'Kinshasa');
    expect(data.driver?.fullName, 'Jean Conducteur');
    expect(data.power?.batteryLevelPercent, 90);
    expect(data.gsm?.signalPercent, 80);
    expect(data.diagnostic?.satellites, 10);
    expect(data.obdCan?.rpm, 1800);
    expect(data.obdCan?.hasData, isTrue);
    expect(data.obdCan?.states.ignitionOn, isTrue);
    expect(data.obdCan?.states.engineRunning, isTrue);
    expect(data.obdCan?.states.frontLeftDoorOpen, isFalse);
    expect(data.obdCan?.states.rearRightDoorOpen, isTrue);
    expect(data.obdCan?.states.doorsOpen, isTrue);
    expect(data.engineControl?.isVisible, isTrue);
    expect(data.engineControl?.nextAction, 'immobilize');
    expect(data.engineControl?.outputs, hasLength(2));
    expect(data.engineControl?.outputs.first.number, 1);
    expect(data.engineControl?.outputs.first.active, isFalse);
    expect(data.engineControl?.outputs.last.number, 2);
    expect(data.engineControl?.outputs.last.active, isTrue);
    expect(data.engineControl?.outputs.last.busy, isTrue);
    expect(data.recentEvents, hasLength(1));
  });

  test('calcule un pourcentage depuis la tension interne si nécessaire', () {
    const nativeLevel = VehiclePowerDetail(
      internalBatteryVoltage: 3.4,
      batteryLevelPercent: 88,
    );
    const voltageOnly = VehiclePowerDetail(internalBatteryVoltage: 3.94);

    expect(nativeLevel.effectiveBatteryLevelPercent, 88);
    expect(voltageOnly.effectiveBatteryLevelPercent, 71);
  });

  test('parse les départements et leurs capacités de gestion', () {
    final collection = DepartmentCollectionData.fromMap({
      'data': [
        {
          'id': 4,
          'name': 'Operations',
          'code': 'OPS',
          'status': 'active',
          'drivers_count': 3,
          'fleet': {'id': 2, 'name': 'EXAD CARS', 'code': 'EX-CRS'},
        },
      ],
      'management': {
        'can_manage': true,
        'can_delete': false,
        'fleets': [
          {'id': 2, 'name': 'EXAD CARS', 'code': 'EX-CRS'},
        ],
      },
    });

    expect(collection.departments.single.name, 'Operations');
    expect(collection.departments.single.driversCount, 3);
    expect(collection.departments.single.isActive, isTrue);
    expect(collection.fleets.single.id, 2);
    expect(collection.canManage, isTrue);
    expect(collection.canDelete, isFalse);
  });

  test('parse un chauffeur sans modele d identifiant', () {
    final driver = DriverData.fromMap({
      'id': 8,
      'full_name': 'Arnold Lula',
      'employee_id': 'CH-001',
      'phone': '+243810000001',
      'email': 'arnold@example.test',
      'status': 'active',
      'fleet': {'id': 2, 'name': 'EXAD CARS', 'code': 'EX-CRS'},
      'department': {'id': 4, 'name': 'Operations', 'code': 'OPS'},
      'vehicles': [
        {'id': 12, 'name': 'Toyota Hiace', 'registration_number': '1234BV01'},
      ],
    });

    expect(driver.fullName, 'Arnold Lula');
    expect(driver.isActive, isTrue);
    expect(driver.department?.name, 'Operations');
    expect(driver.vehicles.single.registration, '1234BV01');
  });
}
