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
        'trail': [
          [15.310, -4.326],
          [15.311, -4.3255],
          [15.312, -4.325],
        ],
      },
    });

    expect(vehicle.isMoving, isTrue);
    expect(vehicle.isParking, isFalse);
    expect(vehicle.heading, 90);
    expect(vehicle.trail, hasLength(3));
    expect(vehicle.trail.last.latitude, -4.325);
    expect(vehicle.trail.last.longitude, 15.312);
  });

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
        'obd_can': {'rpm': 1800, 'engine_temperature_c': 84},
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
    expect(data.recentEvents, hasLength(1));
  });
}
