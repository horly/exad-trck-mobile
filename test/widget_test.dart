import 'package:exad_tracking_mobile/app.dart';
import 'package:exad_tracking_mobile/core/localization/app_localizations.dart';
import 'package:exad_tracking_mobile/core/models/app_models.dart';
import 'package:exad_tracking_mobile/core/session/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche la connexion corporate en français', (tester) async {
    await tester.pumpWidget(
      ExadTrackingApp(
        sessionController: SessionController.preview(),
        localeController: LocaleController.preview(),
      ),
    );

    expect(find.text('PLATEFORME MOBILE DE GESTION DE FLOTTE'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('adapte la connexion à la langue anglaise', (tester) async {
    await tester.pumpWidget(
      ExadTrackingApp(
        sessionController: SessionController.preview(),
        localeController: LocaleController.preview(const Locale('en')),
      ),
    );

    expect(find.text('MOBILE FLEET MANAGEMENT PLATFORM'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Email address'), findsOneWidget);
  });

  testWidgets('affiche le tableau de bord client et ouvre les véhicules', (
    tester,
  ) async {
    final session = _session(role: 'admin');
    await tester.pumpWidget(
      ExadTrackingApp(
        sessionController: session,
        localeController: LocaleController.preview(),
      ),
    );

    expect(find.text('ESPACE CLIENT'), findsOneWidget);
    expect(find.text('Bonjour Admin'), findsOneWidget);
    expect(find.text('EXAD CARS · EX-CRS'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard), findsOneWidget);

    await tester.tap(find.text('Véhicules').last);
    await tester.pumpAndSettle();
    expect(find.text('1 véhicule(s) dans votre flotte'), findsOneWidget);
  });

  testWidgets('affiche une console distincte au superadmin', (tester) async {
    final session = _session(role: 'superadmin');
    await tester.pumpWidget(
      ExadTrackingApp(
        sessionController: session,
        localeController: LocaleController.preview(),
      ),
    );

    expect(find.text('CONSOLE SUPERADMIN'), findsOneWidget);
    expect(find.text('Supervision'), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('Répartition des flottes'), findsOneWidget);
    expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
  });
}

SessionController _session({required String role}) {
  const fleet = FleetInfo(id: 1, name: 'EXAD CARS', code: 'EX-CRS');
  return SessionController.preview()
    ..stage = SessionStage.signedIn
    ..bootstrap = BootstrapData(
      user: AppUser(
        id: 1,
        name: 'Admin EXAD',
        email: 'admin@example.com',
        role: role,
        permissions: const {'map_view': false},
        twoFactorEnabled: false,
        fleet: role == 'superadmin' ? null : fleet,
      ),
      branding: BrandingData.fallback,
    )
    ..dashboard = const DashboardData(
      totalVehicles: 3,
      onlineVehicles: 2,
      movingVehicles: 1,
      attentionVehicles: 1,
      newAlerts: 1,
      totalFleets: 1,
      fleetDistribution: [
        FleetSummary(
          id: 1,
          name: 'EXAD CARS',
          code: 'EX-CRS',
          totalVehicles: 1,
          onlineVehicles: 1,
        ),
      ],
      vehicles: [
        VehicleData(
          id: 1,
          name: 'Toyota Hiace',
          registration: '1234BV01',
          status: 'active',
          trackingStatus: 'online',
          isOnline: true,
          speed: 18,
          fleet: fleet,
        ),
      ],
      alerts: [],
    )
    ..vehicles = const [
      VehicleData(
        id: 1,
        name: 'Toyota Hiace',
        registration: '1234BV01',
        status: 'active',
        trackingStatus: 'online',
        isOnline: true,
        speed: 18,
        fleet: fleet,
      ),
    ];
}
