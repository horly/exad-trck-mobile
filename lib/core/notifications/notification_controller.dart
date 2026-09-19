import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../session/session_controller.dart';

class PushMessage {
  const PushMessage({
    required this.category,
    required this.id,
    required this.title,
    required this.body,
  });

  final String category;
  final int id;
  final String title;
  final String body;
}

class NotificationOpenRequest {
  const NotificationOpenRequest({required this.category, required this.id});

  final String category;
  final int id;

  bool get isAlert => category == 'alert';
}

abstract interface class PushMessagingGateway {
  Future<String?> token();
  Stream<String> get tokenRefresh;
  Stream<PushMessage> get foregroundMessages;
  Stream<PushMessage> get openedMessages;
  Future<PushMessage?> initialMessage();
}

class FirebasePushMessagingGateway implements PushMessagingGateway {
  FirebasePushMessagingGateway({FirebaseMessaging? messaging})
    : _messaging = messaging;

  final FirebaseMessaging? _messaging;
  FirebaseMessaging get messaging => _messaging ?? FirebaseMessaging.instance;

  @override
  Future<String?> token() => messaging.getToken();

  @override
  Stream<String> get tokenRefresh => messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_fromRemoteMessage);

  @override
  Stream<PushMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(_fromRemoteMessage);

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await messaging.getInitialMessage();
    return message == null ? null : _fromRemoteMessage(message);
  }

  PushMessage _fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final category = data['category'] ?? '';
    final recordId = category == 'alert' ? data['alert_id'] : data['event_id'];
    return PushMessage(
      category: category,
      id: int.tryParse(recordId ?? '') ?? message.hashCode.abs(),
      title: message.notification?.title ?? data['title'] ?? 'EXAD Tracking',
      body: message.notification?.body ?? data['body'] ?? '',
    );
  }
}

abstract interface class SystemNotificationGateway {
  Future<void> initialize(ValueChanged<String?> onNotificationSelected);
  Future<bool> requestPermission();
  Future<void> showVehicleEvent(PushMessage message);
  Future<void> showAlert(PushMessage message);
}

class LocalSystemNotificationGateway implements SystemNotificationGateway {
  LocalSystemNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _supported = false;

  @override
  Future<void> initialize(ValueChanged<String?> onNotificationSelected) async {
    _supported = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!_supported) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        onNotificationSelected(response.payload);
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      onNotificationSelected(launchDetails?.notificationResponse?.payload);
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'vehicle_events',
        'Événements des véhicules',
        description: 'Contact, mouvements et autres événements des véhicules',
        importance: Importance.defaultImportance,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'fleet_alerts',
        'Alertes de flotte',
        description:
            'Alertes de sécurité et anomalies nécessitant une attention',
        importance: Importance.high,
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> showVehicleEvent(PushMessage message) async {
    if (!_supported) return;
    await _plugin.show(
      id: 100000 + (message.id % 800000),
      title: message.title,
      body: message.body,
      payload: 'vehicle_event:${message.id}',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'vehicle_events',
          'Événements des véhicules',
          channelDescription:
              'Contact, mouvements et autres événements des véhicules',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.status,
          groupKey: 'exad_vehicle_events',
        ),
      ),
    );
  }

  @override
  Future<void> showAlert(PushMessage message) async {
    if (!_supported) return;
    await _plugin.show(
      id: 1000000 + (message.id % 800000),
      title: message.title,
      body: message.body,
      payload: 'alert:${message.id}',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fleet_alerts',
          'Alertes de flotte',
          channelDescription:
              'Alertes de sécurité et anomalies nécessitant une attention',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          groupKey: 'exad_fleet_alerts',
        ),
      ),
    );
  }
}

class NotificationController extends ChangeNotifier {
  NotificationController({
    FlutterSecureStorage? storage,
    SystemNotificationGateway? gateway,
    PushMessagingGateway? pushGateway,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _gateway = gateway ?? LocalSystemNotificationGateway(),
       _pushGateway = pushGateway ?? FirebasePushMessagingGateway();

  static const _eventsEnabledKey = 'notifications_vehicle_events_enabled';
  static const _alertsEnabledKey = 'notifications_alerts_enabled';

  final FlutterSecureStorage _storage;
  final SystemNotificationGateway _gateway;
  final PushMessagingGateway _pushGateway;

  SessionController? _session;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<PushMessage>? _messageSubscription;
  StreamSubscription<PushMessage>? _openedMessageSubscription;
  final StreamController<NotificationOpenRequest> _openRequestController =
      StreamController<NotificationOpenRequest>.broadcast();
  NotificationOpenRequest? _pendingOpenRequest;
  bool _syncing = false;
  String _languageCode = 'fr';

  bool initialized = false;
  bool eventsEnabled = false;
  bool alertsEnabled = false;
  bool permissionDenied = false;

  Stream<NotificationOpenRequest> get openRequests =>
      _openRequestController.stream;

  NotificationOpenRequest? takePendingOpenRequest() {
    final request = _pendingOpenRequest;
    _pendingOpenRequest = null;
    return request;
  }

  Future<void> initialize() async {
    try {
      final values = await _storage.readAll();
      eventsEnabled = values[_eventsEnabledKey] == 'true';
      alertsEnabled = values[_alertsEnabledKey] == 'true';
      await _gateway.initialize(_handleLocalNotificationSelected);
      _messageSubscription = _pushGateway.foregroundMessages.listen(
        _showForegroundMessage,
      );
      _openedMessageSubscription = _pushGateway.openedMessages.listen(
        _handleOpenedPushMessage,
      );
      final initialMessage = await _pushGateway.initialMessage();
      if (initialMessage != null) _handleOpenedPushMessage(initialMessage);
      _tokenSubscription = _pushGateway.tokenRefresh.listen(
        (token) => unawaited(_registerToken(token)),
      );
    } catch (_) {
      // Notification initialization must never prevent access to the app.
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  void setLanguageCode(String languageCode) {
    _languageCode = languageCode == 'en' ? 'en' : 'fr';
    if (_session != null) unawaited(attachSession(_session!));
  }

  Future<void> attachSession(SessionController session) async {
    _session = session;
    if (!initialized || session.user == null || _syncing) return;
    _syncing = true;
    try {
      final serverPreferences = await session.notificationPreferences();
      eventsEnabled = serverPreferences.vehicleEventsEnabled;
      alertsEnabled = serverPreferences.alertsEnabled;
      await _persistPreferences();
      final token = await _pushGateway.token();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (_) {
      // Retry automatically when the application resumes.
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<bool> setEventsEnabled(bool enabled) async {
    if (enabled && !await _allowNotifications()) return false;
    eventsEnabled = enabled;
    await _persistAndSyncPreferences();
    notifyListeners();
    return true;
  }

  Future<bool> setAlertsEnabled(bool enabled) async {
    if (enabled && !await _allowNotifications()) return false;
    alertsEnabled = enabled;
    await _persistAndSyncPreferences();
    notifyListeners();
    return true;
  }

  Future<bool> _allowNotifications() async {
    try {
      permissionDenied = !await _gateway.requestPermission();
    } catch (_) {
      permissionDenied = true;
    }
    notifyListeners();
    return !permissionDenied;
  }

  Future<void> _persistAndSyncPreferences() async {
    await _persistPreferences();
    final session = _session;
    if (session == null) return;
    try {
      await session.updateNotificationPreferences(
        vehicleEventsEnabled: eventsEnabled,
        alertsEnabled: alertsEnabled,
      );
      final token = await _pushGateway.token();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (_) {
      // Keep the local choice; attachSession will retry after resume.
    }
  }

  Future<void> _persistPreferences() => Future.wait([
    _storage.write(key: _eventsEnabledKey, value: '$eventsEnabled'),
    _storage.write(key: _alertsEnabledKey, value: '$alertsEnabled'),
  ]);

  Future<void> _registerToken(String token) async {
    final session = _session;
    if (session == null || session.user == null) return;
    try {
      await session.registerPushDevice(
        token: token,
        locale: _languageCode,
        appVersion: AppConfig.fullVersion,
      );
    } catch (_) {
      // A refresh or a future token event will retry registration.
    }
  }

  Future<void> _showForegroundMessage(PushMessage message) async {
    if (message.category == 'vehicle_event' && eventsEnabled) {
      await _gateway.showVehicleEvent(message);
    } else if (message.category == 'alert' && alertsEnabled) {
      await _gateway.showAlert(message);
    }
  }

  void _handleOpenedPushMessage(PushMessage message) {
    _requestOpen(message.category, message.id);
  }

  void _handleLocalNotificationSelected(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final separator = payload.indexOf(':');
    if (separator <= 0 || separator == payload.length - 1) return;
    final category = payload.substring(0, separator);
    final id = int.tryParse(payload.substring(separator + 1));
    if (id == null) return;
    _requestOpen(category, id);
  }

  void _requestOpen(String category, int id) {
    if (category != 'alert' && category != 'vehicle_event') return;
    final current = _pendingOpenRequest;
    if (current?.category == category && current?.id == id) return;
    final request = NotificationOpenRequest(category: category, id: id);
    _pendingOpenRequest = request;
    _openRequestController.add(request);
  }

  @override
  void dispose() {
    unawaited(_tokenSubscription?.cancel());
    unawaited(_messageSubscription?.cancel());
    unawaited(_openedMessageSubscription?.cancel());
    unawaited(_openRequestController.close());
    super.dispose();
  }
}
