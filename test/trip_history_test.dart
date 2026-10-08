import 'dart:async';
import 'package:exad_tracking_mobile/core/localization/app_localizations.dart';
import 'package:exad_tracking_mobile/core/models/app_models.dart';
import 'package:exad_tracking_mobile/features/map/trip_history_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> payload() => {
  'tracking_configured': true,
  'summary': {'count': 1, 'distance_km': 1.25, 'duration_seconds': 120},
  'trips': [
    {
      'id': 't1',
      'index': 1,
      'date': '05.10.2026',
      'end_date': '05.10.2026',
      'start_time': '08:00',
      'end_time': '08:02',
      'start_address': 'Avenue de test A',
      'end_address': 'Avenue de test B',
      'color': '#795548',
      'distance_km': 1.25,
      'duration_seconds': 120,
      'coordinates': [
        [15.22, -4.33],
        [15.23, -4.33],
      ],
      'start_coordinates': [15.22001, -4.33001],
      'end_coordinates': [15.23001, -4.33001],
    },
  ],
  'history': {
    'parking_count': 1,
    'parking_seconds': 300,
    'elapsed_seconds': 420,
    'items': [
      {
        'type': 'trip',
        'id': 't1',
        'date': '05.10.2026',
        'start_time': '08:00',
        'end_time': '08:02',
        'start_address': 'Avenue de test A',
        'duration_seconds': 120,
      },
      {
        'type': 'parking',
        'id': 'p1',
        'date': '05.10.2026',
        'end_date': '05.10.2026',
        'start_time': '08:02',
        'end_time': '08:07',
        'address': 'Avenue de test B',
        'coordinates': [15.23, -4.33],
        'duration_seconds': 300,
      },
    ],
  },
};

Widget panel(
  HistoryLoader load,
  void Function(List<VehicleTripData>, VehicleHistoryItem?) selected, {
  void Function(VehicleTripData, double)? replay,
  double width = 390,
}) => MaterialApp(
  locale: const Locale('fr'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomLeft,
      child: SizedBox(
        width: width,
        height: 500,
        child: TripHistoryPanel(
          vehicleName: 'Suzuki Horly',
          load: load,
          onSelection: selected,
          onPlayback: replay ?? (_, _) {},
          onClose: () {},
        ),
      ),
    ),
  ),
);

void main() {
  test(
    'parses parking and exact endpoints while retaining compatibility with old servers',
    () {
      final result = VehicleTripsData.fromMap(payload());
      expect(result.trips.first.startCoordinate!.longitude, 15.22001);
      expect(result.trips.first.endCoordinate!.latitude, -4.33001);
      expect(result.history.last.coordinate!.latitude, -4.33);
      expect(result.parkingSeconds, 300);
      expect(VehicleTripsData.fromMap({'trips': []}).history, isEmpty);
      expect(historyCoordinate([15, double.nan]), isNull);
      expect(historyCoordinate([181, 91]), isNull);
    },
  );
  testWidgets(
    'opens overview then details and selects trip and parking on the map',
    (tester) async {
      List<VehicleTripData> trips = [];
      VehicleHistoryItem? parking;
      await tester.pumpWidget(
        panel((_, _, _) async => VehicleTripsData.fromMap(payload()), (a, b) {
          trips = a;
          parking = b;
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-overview')), findsOneWidget);
      expect(trips.length, 1);
      await tester.tap(find.byKey(const Key('history-overview')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history-item-t1')));
      await tester.pumpAndSettle();
      expect(trips.single.id, 't1');
      await tester.scrollUntilVisible(
        find.byKey(const Key('history-item-p1')),
        160,
        scrollable: find.descendant(
          of: find.byKey(const Key('history-details')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const Key('history-item-p1')));
      await tester.pumpAndSettle();
      expect(trips, isEmpty);
      expect(parking?.id, 'p1');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('parking only periods remain visible in a narrow panel', (
    tester,
  ) async {
    final raw = payload();
    raw['trips'] = [];
    raw['history']['items'].removeAt(0);
    await tester.pumpWidget(
      panel(
        (_, _, _) async => VehicleTripsData.fromMap(raw),
        (_, _) {},
        width: 300,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-overview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-item-p1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'ignores an obsolete response after a refresh and cancels playback on dispose',
    (tester) async {
      final old = Completer<VehicleTripsData>();
      int count = 0, callbacks = 0;
      await tester.pumpWidget(
        panel(
          (_, _, _) => count++ == 0
              ? old.future
              : Future.value(VehicleTripsData.fromMap(payload())),
          (_, _) {},
          replay: (_, _) => callbacks++,
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Actualiser'));
      await tester.pumpAndSettle();
      old.complete(VehicleTripsData.fromMap({'trips': []}));
      await tester.pumpAndSettle();
      expect(find.text('Suzuki Horly'), findsOneWidget);
      await tester.tap(find.byTooltip('Lire le parcours'));
      await tester.pump(const Duration(seconds: 1));
      expect(callbacks, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
