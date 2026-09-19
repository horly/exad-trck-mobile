import 'package:exad_tracking_mobile/core/notifications/notification_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

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
  _FakePushGateway({this.initial});

  final PushMessage? initial;

  @override
  Stream<PushMessage> get foregroundMessages => const Stream.empty();

  @override
  Stream<PushMessage> get openedMessages => const Stream.empty();

  @override
  Future<PushMessage?> initialMessage() async => initial;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();
}
