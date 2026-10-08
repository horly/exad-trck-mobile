import 'dart:io';
import 'dart:ui' as ui;
import 'package:exad_tracking_mobile/core/localization/app_localizations.dart';
import 'package:exad_tracking_mobile/core/models/app_models.dart';
import 'package:exad_tracking_mobile/core/updates/app_update_service.dart';
import 'package:exad_tracking_mobile/core/theme/app_theme.dart';
import 'package:exad_tracking_mobile/features/map/selected_vehicle_strip.dart';
import 'package:exad_tracking_mobile/shared/widgets/app_update_banner.dart';
import 'package:exad_tracking_mobile/shared/widgets/ui_components.dart';
import 'package:exad_tracking_mobile/shared/widgets/vehicle_marker_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleData vehicle({
  Map<String, dynamic>? fuel,
  bool online = true,
  bool moving = false,
  bool parking = false,
}) => VehicleData.fromMapFeature({
  'geometry': {
    'coordinates': [15.2, -4.3],
  },
  'properties': {
    'vehicle_id': 1,
    'vehicle': 'Véhicule de démonstration',
    'registration_number': 'TEST-001',
    'status': online ? 'online' : 'offline',
    'is_moving': moving,
    'is_parking': parking,
    'speed_kmh': 21,
    'gps_status': 'available',
    'network_signal_percent': 100,
    'battery_level_percent': 97,
    'fuel': ?fuel,
  },
});

Widget host(Widget child, {String language = 'fr'}) => MaterialApp(
  locale: Locale(language),
  theme: AppTheme.fromBranding(BrandingData.fallback).copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: AppTheme.fromBranding(BrandingData.fallback)
          .filledButtonTheme
          .style!
          .merge(
            FilledButton.styleFrom(
              textStyle: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
    ),
  ),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

class FakeUpdateService extends AppUpdateService {
  int? nextBuild = 45;
  int checks = 0, opens = 0;
  bool openResult = true;
  @override
  Future<int?> availableBuild() async {
    checks++;
    return nextBuild;
  }

  @override
  Future<bool> openStore() async {
    opens++;
    return openResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'fuel parsing is additive, keeps zero, and does not fabricate missing or invalid values',
    () {
      expect(vehicle().fuel, isNull);
      expect(
        vehicle(fuel: {'liters': 0, 'percent': 0}).fuel!.label('fr'),
        '0,0 L · 0,0 %',
      );
      expect(
        vehicle(fuel: {'liters': -1, 'percent': 101}).fuel!.label('fr'),
        '—',
      );
      expect(
        VehicleData.fromMap({
          'tracking': {
            'fuel': {'liters': 66, 'percent': 55},
          },
        }).fuel!.label('en'),
        '66.0 L · 55.0 %',
      );
    },
  );
  test('map colors and symbols follow movement parking and offline status', () {
    expect(vehicleMarkerColor(vehicle(moving: true)), const Color(0xFF10B981));
    expect(vehicleMarkerIcon(vehicle(moving: true)), Icons.navigation_rounded);
    expect(vehicleMarkerColor(vehicle(parking: true)), const Color(0xFF22A7DF));
    expect(
      vehicleMarkerIcon(vehicle(parking: true)),
      Icons.local_parking_rounded,
    );
    expect(
      vehicleMarkerColor(vehicle(online: false, moving: true)),
      const Color(0xFFEF4444),
    );
  });
  testWidgets(
    'fuel fits the compact selected bar and vehicle list without shifting history',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final car = vehicle(fuel: {'liters': 66, 'percent': 55}, moving: true);
      await tester.pumpWidget(
        host(
          Column(
            children: [
              SelectedVehicleTopStrip(vehicle: car),
              CorporateVehicleRow(vehicle: car),
            ],
          ),
        ),
      );
      expect(find.text('66,0 L'), findsOneWidget);
      expect(find.text('66,0 L · 55,0 %'), findsOneWidget);
      expect(tester.getSize(find.byType(SelectedVehicleTopStrip)).height, 70);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        host(
          Column(
            children: [
              SelectedVehicleTopStrip(vehicle: vehicle()),
              CorporateVehicleRow(vehicle: vehicle()),
            ],
          ),
        ),
      );
      expect(find.byIcon(Icons.local_gas_station_rounded), findsNothing);
    },
  );
  testWidgets(
    'update banner appears for a Play release and opens the Store only on tap',
    (tester) async {
      final service = FakeUpdateService();
      await tester.pumpWidget(host(AppUpdateBanner(service: service)));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle version disponible'), findsOneWidget);
      expect(service.opens, 0);
      await tester.tap(find.text('Mettre à jour'));
      await tester.pumpAndSettle();
      expect(service.opens, 1);
      service.nextBuild = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle version disponible'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('a failed store launch shows an explanation and can be retried', (
    tester,
  ) async {
    final service = FakeUpdateService()..openResult = false;
    await tester.pumpWidget(host(AppUpdateBanner(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mettre à jour'));
    await tester.pumpAndSettle();
    expect(
      find.text('Impossible d’ouvrir le Play Store. Réessayez.'),
      findsOneWidget,
    );
    expect(find.text('Nouvelle version disponible'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'Play check uses availability and handles offline or unsupported installs silently',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(AppUpdateService.channel, null),
      );
      messenger.setMockMethodCallHandler(
        AppUpdateService.channel,
        (_) async => {'available': true, 'build': 45},
      );
      expect(await const AppUpdateService().availableBuild(), 45);
      messenger.setMockMethodCallHandler(
        AppUpdateService.channel,
        (_) async => {'available': false, 'build': 45},
      );
      expect(await const AppUpdateService().availableBuild(), isNull);
      messenger.setMockMethodCallHandler(
        AppUpdateService.channel,
        (_) async => throw PlatformException(code: 'APP_NOT_OWNED'),
      );
      expect(await const AppUpdateService().availableBuild(), isNull);
    },
  );
  testWidgets(
    'narrow dashboard preview keeps update notice and fuel readable',
    (tester) async {
      final fonts = Platform.environment['EXAD_PREVIEW_FONTS'];
      if (fonts != null) {
        await tester.runAsync(() async {
          final text = FontLoader('Roboto')
            ..addFont(
              File(
                '$fonts/roboto-regular.ttf',
              ).readAsBytes().then((b) => ByteData.sublistView(b)),
            )
            ..addFont(
              File(
                '$fonts/roboto-bold.ttf',
              ).readAsBytes().then((b) => ByteData.sublistView(b)),
            );
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              File(
                '$fonts/materialicons-regular.otf',
              ).readAsBytes().then((b) => ByteData.sublistView(b)),
            );
          await Future.wait([text.load(), icons.load()]);
        });
      }
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey(),
          service = FakeUpdateService(),
          car = vehicle(fuel: {'liters': 66, 'percent': 55}, moving: true);
      await tester.pumpWidget(
        host(
          RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: AppTheme.background,
              child: Column(
                children: [
                  SelectedVehicleTopStrip(vehicle: car),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        AppUpdateBanner(service: service),
                        CorporateVehicleRow(vehicle: car),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final output = Platform.environment['EXAD_MOBILE_PREVIEW'];
      if (output != null) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(output).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
