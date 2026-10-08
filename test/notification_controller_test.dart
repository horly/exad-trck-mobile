import 'package:exad_tracking_mobile/core/api/api_client.dart';
import 'package:exad_tracking_mobile/core/models/app_models.dart';
import 'package:exad_tracking_mobile/core/notifications/notification_controller.dart';
import 'package:exad_tracking_mobile/core/session/session_controller.dart';
import 'package:exad_tracking_mobile/core/storage/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mémorise séparément le choix des événements et des alertes', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final gateway = _FakeNotificationGateway();
    final controller = NotificationController(
      storage: const FlutterSecureStorage(),
      gateway: gateway,
      pushGateway: _FakePushGateway(),
    );

    await controller.initialize();
    expect(controller.eventsEnabled, isFalse);
    expect(controller.alertsEnabled, isFalse);

    expect(await controller.setEventsEnabled(true), isTrue);
    expect(controller.eventsEnabled, isTrue);
    expect(controller.alertsEnabled, isFalse);

    expect(await controller.setAlertsEnabled(true), isTrue);
    expect(controller.eventsEnabled, isTrue);
    expect(controller.alertsEnabled, isTrue);
    expect(gateway.permissionRequests, 2);

    final restored = NotificationController(
      storage: const FlutterSecureStorage(),
      gateway: _FakeNotificationGateway(),
      pushGateway: _FakePushGateway(),
    );
    await restored.initialize();

    expect(restored.eventsEnabled, isTrue);
    expect(restored.alertsEnabled, isTrue);
  });

  test('publie la destination d\'une notification sélectionnée', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final gateway = _FakeNotificationGateway();
    final controller = NotificationController(
      storage: const FlutterSecureStorage(),
      gateway: gateway,
      pushGateway: _FakePushGateway(),
    );

    await controller.initialize();
    gateway.select('alert:42');

    final request = controller.takePendingOpenRequest();
    expect(request?.category, 'alert');
    expect(request?.id, 42);
    expect(controller.takePendingOpenRequest(), isNull);
  });

  test(
    'conserve une notification Firebase ayant démarré l\'application',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final controller = NotificationController(
        storage: const FlutterSecureStorage(),
        gateway: _FakeNotificationGateway(),
        pushGateway: _FakePushGateway(
          initial: const PushMessage(
            category: 'vehicle_event',
            id: 17,
            title: 'Mouvement démarré',
            body: 'Le véhicule roule.',
          ),
        ),
      );

      await controller.initialize();

      final request = controller.takePendingOpenRequest();
      expect(request?.category, 'vehicle_event');
      expect(request?.id, 17);
    },
  );
  test(
    'demande la permission et resynchronise le jeton au retour au premier plan',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      final tokenStore = TokenStore(storage: storage);
      final api = _NotificationApiClient(tokenStore: tokenStore);
      final session = SessionController(tokenStore: tokenStore, apiClient: api)
        ..stage = SessionStage.signedIn
        ..bootstrap = const BootstrapData(
          user: AppUser(
            id: 1,
            name: 'Admin EXAD',
            email: 'admin@example.com',
            role: 'admin',
            permissions: {},
            twoFactorEnabled: false,
          ),
          branding: BrandingData.fallback,
        );
      final gateway = _FakeNotificationGateway();
      final controller = NotificationController(
        storage: storage,
        gateway: gateway,
        pushGateway: _FakePushGateway(tokenValue: 'firebase-token'),
      );

      await controller.initialize();
      await controller.attachSession(session);

      expect(gateway.permissionRequests, 1);
      expect(api.registrationCalls, 1);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(gateway.permissionRequests, 2);
      expect(api.registrationCalls, 2);

      controller.dispose();
    },
  );
}

class _FakeNotificationGateway implements SystemNotificationGateway {
  int permissionRequests = 0;
  void Function(String?)? onSelected;

  @override
  Future<void> initialize(void Function(String?) onNotificationSelected) async {
    onSelected = onNotificationSelected;
  }

  void select(String payload) => onSelected?.call(payload);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> showAlert(PushMessage message) async {}

  @override
  Future<void> showVehicleEvent(PushMessage message) async {}
}

class _FakePushGateway implements PushMessagingGateway {
  _FakePushGateway({this.initial, this.tokenValue});

  final PushMessage? initial;
  final String? tokenValue;

  @override
  Stream<PushMessage> get foregroundMessages => const Stream.empty();

  @override
  Stream<PushMessage> get openedMessages => const Stream.empty();

  @override
  Future<PushMessage?> initialMessage() async => initial;

  @override
  Future<String?> token() async => tokenValue;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();
}

class _NotificationApiClient extends ApiClient {
  _NotificationApiClient({required super.tokenStore});

  int registrationCalls = 0;

  @override
  Future<NotificationPreferencesData> notificationPreferences() async =>
      const NotificationPreferencesData(
        vehicleEventsEnabled: true,
        alertsEnabled: true,
      );

  @override
  Future<void> registerPushDevice({
    required String token,
    required String locale,
    required String appVersion,
  }) async {
    registrationCalls++;
  }
}
