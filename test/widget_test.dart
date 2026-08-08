import 'package:exad_tracking_mobile/app.dart';
import 'package:exad_tracking_mobile/core/localization/app_localizations.dart';
import 'package:exad_tracking_mobile/core/models/app_models.dart';
import 'package:exad_tracking_mobile/core/session/session_controller.dart';
import 'package:exad_tracking_mobile/features/dashboard/superadmin_dashboard_screen.dart';
import 'package:exad_tracking_mobile/features/vehicles/vehicles_screen.dart';
import 'package:exad_tracking_mobile/shared/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
    expect(find.widgetWithText(Badge, '1'), findsWidgets);

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

  testWidgets('demande l’ouverture de la carte au clic sur un véhicule', (
    tester,
  ) async {
    final session = _session(role: 'admin');
    VehicleData? requestedVehicle;

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
          body: VehiclesScreen(
            session: session,
            onOpenMap: (vehicle) => requestedVehicle = vehicle,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Toyota Hiace'));
    await tester.pump();

    expect(requestedVehicle?.id, 1);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('ouvre la carte depuis l’activité du parc', (tester) async {
    final session = _session(role: 'superadmin');
    VehicleData? requestedVehicle;

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
          body: SuperadminDashboardScreen(
            session: session,
            onOpenVehicles: () {},
            onOpenOnlineVehicles: () {},
            onOpenAlerts: () {},
            onOpenVehicleMap: (vehicle) => requestedVehicle = vehicle,
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Toyota Hiace'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Toyota Hiace'));
    await tester.pump();

    expect(requestedVehicle?.id, 1);
  });

  testWidgets('rend un indicateur de dashboard cliquable', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 180,
            child: MetricTile(
              label: 'En ligne',
              value: 2,
              icon: Icons.signal_cellular_alt,
              color: Colors.green,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('En ligne'));
    await tester.pump();

    expect(tapped, isTrue);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
  });

  testWidgets('distingue une nouvelle alerte dans la liste corporate', (
    tester,
  ) async {
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
        home: const Scaffold(
          body: CorporateAlertRow(
            alert: AlertData(
              id: 1,
              title: 'Aucun signal',
              message: 'Le véhicule ne transmet plus de signal.',
              severity: 'high',
              status: 'new',
              vehicle: 'PALISADE',
              occurredAt: '2026-08-08T10:30:00Z',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Nouveau'), findsOneWidget);
    expect(find.text('PALISADE'), findsOneWidget);
    expect(find.byIcon(Icons.notification_important_outlined), findsOneWidget);
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
