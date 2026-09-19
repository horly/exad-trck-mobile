import 'package:exad_tracking_mobile/core/api/api_client.dart';
import 'package:exad_tracking_mobile/core/localization/app_localizations.dart';
import 'package:exad_tracking_mobile/core/models/app_models.dart';
import 'package:exad_tracking_mobile/core/session/session_controller.dart';
import 'package:exad_tracking_mobile/core/storage/token_store.dart';
import 'package:exad_tracking_mobile/features/map/map_vehicle_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('masque les secrets du traceur et affiche CAN pour un admin', (
    tester,
  ) async {
    await _openDetails(tester, role: 'admin');

    _expectClientCanVisibility();
    expect(find.text('Toyota Hiace (1234BV01)'), findsOneWidget);
  });

  testWidgets(
    'masque les secrets du traceur et affiche CAN pour un utilisateur',
    (tester) async {
      await _openDetails(tester, role: 'user');

      _expectClientCanVisibility();
    },
  );

  testWidgets('affiche les informations du traceur au superadmin', (
    tester,
  ) async {
    await _openDetails(tester, role: 'superadmin');

    expect(find.text('868120000000001'), findsOneWidget);
    expect(find.text('Teltonika FMB920'), findsOneWidget);
    expect(find.text('GSM'), findsOneWidget);
    expect(find.text('Diagnostic traceur'), findsOneWidget);
    expect(find.text('OBD / CAN'), findsOneWidget);
  });
}

void _expectClientCanVisibility() {
  expect(find.text('868120000000001'), findsNothing);
  expect(find.text('FMB920'), findsNothing);
  expect(find.text('GSM'), findsNothing);
  expect(find.text('Diagnostic traceur'), findsNothing);
  expect(find.text('OBD / CAN'), findsOneWidget);
  expect(find.text('1800'), findsOneWidget);
}

Future<void> _openDetails(WidgetTester tester, {required String role}) async {
  final details = _details();
  final tokenStore = TokenStore();
  final session =
      SessionController(
          tokenStore: tokenStore,
          apiClient: _VehicleDetailApiClient(
            tokenStore: tokenStore,
            details: details,
          ),
        )
        ..stage = SessionStage.signedIn
        ..bootstrap = BootstrapData(
          user: AppUser(
            id: 1,
            name: 'Compte test',
            email: 'test@example.com',
            role: role,
            permissions: const {'map_view': true},
            management: const {},
            twoFactorEnabled: false,
            fleet: details.vehicle.fleet,
          ),
          branding: BrandingData.fallback,
        );

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showVehicleDetailsSheet(context, session, details.vehicle),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

VehicleDetailData _details() => VehicleDetailData.fromMap({
  'id': 12,
  'name': 'Toyota Hiace',
  'registration_number': '1234BV01',
  'status': 'active',
  'fleet': {'id': 2, 'name': 'EXAD CARS', 'code': 'EX-CRS'},
  'tracking': {
    'configured': true,
    'status': 'online',
    'online': true,
    'speed_kmh': 0,
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
      'movement': false,
      'ignition': false,
      'address': 'Kinshasa',
    },
    'power': {'external_voltage': 12.8, 'battery_level_percent': 90},
    'gsm': {
      'signal_percent': 80,
      'operator_name': 'Vodacom',
      'sim_number': '0900000001',
      'codec': '8E',
    },
    'diagnostic': {
      'satellites': 10,
      'protocol': 'TCP',
      'io_count': 2,
      'sensor_count': 1,
    },
    'obd_can': {
      'rpm': 1800,
      'states': {'ignition_on': true},
    },
    'recent_events': [],
  },
});

class _VehicleDetailApiClient extends ApiClient {
  _VehicleDetailApiClient({required super.tokenStore, required this.details});

  final VehicleDetailData details;

  @override
  Future<VehicleDetailData> vehicleDetails(int vehicleId) async => details;
}
