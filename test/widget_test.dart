import 'package:exad_tracking_mobile/app.dart';
import 'package:exad_tracking_mobile/core/updates/app_update_service.dart';
import 'package:exad_tracking_mobile/core/localization/app_localizations.dart';
import 'package:exad_tracking_mobile/core/models/app_models.dart';
import 'package:exad_tracking_mobile/core/session/session_controller.dart';
import 'package:exad_tracking_mobile/features/dashboard/superadmin_dashboard_screen.dart';
import 'package:exad_tracking_mobile/features/departments/departments_screen.dart';
import 'package:exad_tracking_mobile/features/drivers/drivers_screen.dart';
import 'package:exad_tracking_mobile/features/vehicles/vehicles_screen.dart';
import 'package:exad_tracking_mobile/shared/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AppUpdateService.channel,
          (_) async => {'available': false, 'build': 44},
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppUpdateService.channel, null);
  });
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
    final navigation = find.byType(NavigationBar);
    expect(
      find.descendant(of: navigation, matching: find.text('Véhicules')),
      findsNothing,
    );
    expect(
      find.descendant(of: navigation, matching: find.text('Alertes')),
      findsNothing,
    );

    await tester.tap(find.text('Véhicules').first);
    await tester.pumpAndSettle();
    expect(find.byType(VehiclesScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
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

  testWidgets('réserve la gestion du parc mobile au superadmin', (
    tester,
  ) async {
    final superadmin = _session(role: 'superadmin');
    await tester.pumpWidget(
      ExadTrackingApp(
        sessionController: superadmin,
        localeController: LocaleController.preview(),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Plus'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gestion du parc'), findsOneWidget);
    expect(find.text('Gestion des utilisateurs'), findsOneWidget);

    final client = _session(role: 'admin');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ExadTrackingApp(
        sessionController: client,
        localeController: LocaleController.preview(),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Plus'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gestion du parc'), findsNothing);
    expect(find.text('Gestion des utilisateurs'), findsOneWidget);
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

  testWidgets('réduit et réaffiche les véhicules d’une flotte', (tester) async {
    final session = _session(role: 'superadmin')
      ..vehicles = const [
        VehicleData(
          id: 1,
          name: 'Toyota Hiace',
          registration: '1234BV01',
          status: 'active',
          trackingStatus: 'online',
          isOnline: true,
          speed: 18,
          fleet: FleetInfo(id: 1, name: 'EXAD CARS', code: 'EX-CRS'),
        ),
        VehicleData(
          id: 2,
          name: 'Suzuki Horly',
          registration: '6052BE01',
          status: 'active',
          trackingStatus: 'online',
          isOnline: true,
          speed: 0,
          fleet: FleetInfo(id: 2, name: 'Horly Flotte', code: 'HAM'),
        ),
      ];

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
          body: VehiclesScreen(session: session, onOpenMap: (_) {}),
        ),
      ),
    );

    expect(find.text('EXAD CARS (1)'), findsOneWidget);
    expect(find.text('Toyota Hiace'), findsOneWidget);
    expect(find.text('Suzuki Horly'), findsOneWidget);

    await tester.tap(find.text('EXAD CARS (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Toyota Hiace'), findsNothing);
    expect(find.text('Suzuki Horly'), findsOneWidget);

    await tester.tap(find.text('EXAD CARS (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Toyota Hiace'), findsOneWidget);
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

  testWidgets('affiche les chauffeurs en lecture seule sans identifiant', (
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
        home: DriversScreen(
          session: _session(role: 'admin'),
          loadDrivers: () async => const [
            DriverData(
              id: 8,
              fullName: 'Arnold Lula',
              employeeId: 'CH-001',
              phone: '+243810000001',
              email: 'arnold@example.test',
              status: 'active',
              fleet: FleetInfo(id: 1, name: 'EXAD CARS', code: 'EX-CRS'),
              department: DriverDepartmentData(
                id: 4,
                name: 'Operations',
                code: 'OPS',
              ),
              vehicles: [
                DriverVehicleData(
                  id: 1,
                  name: 'Toyota Hiace',
                  registration: '1234BV01',
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arnold Lula'), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('Toyota Hiace (1234BV01)'), findsOneWidget);
    expect(find.text('38000009A29C2114'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('affiche les départements en lecture seule pour un utilisateur', (
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
        home: DepartmentsScreen(
          session: _session(role: 'user'),
          loadDepartments: () async => const DepartmentCollectionData(
            departments: [
              DepartmentData(
                id: 4,
                name: 'Operations',
                code: 'OPS',
                status: 'active',
                driversCount: 3,
                fleet: FleetInfo(id: 1, name: 'EXAD CARS', code: 'EX-CRS'),
              ),
            ],
            fleets: [],
            canManage: false,
            canDelete: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('3 chauffeur(s)'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('utilise le bouton d\'ajout standard pour les départements', (
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
        home: DepartmentsScreen(
          session: _session(role: 'admin'),
          loadDepartments: () async => const DepartmentCollectionData(
            departments: [],
            fleets: [FleetInfo(id: 1, name: 'EXAD CARS', code: 'EX-CRS')],
            canManage: true,
            canDelete: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Nouveau département'), findsOneWidget);
    expect(find.byType(CorporateAddButton), findsOneWidget);
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
        management: role == 'superadmin'
            ? const {
                'fleets': true,
                'vehicles': true,
                'trackers': true,
                'users': true,
              }
            : {
                'fleets': false,
                'vehicles': false,
                'trackers': false,
                'users': role == 'admin',
              },
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
