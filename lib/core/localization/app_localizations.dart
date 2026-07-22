import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocaleController extends ChangeNotifier {
  LocaleController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  LocaleController.preview([this.locale = const Locale('fr')])
    : _storage = const FlutterSecureStorage();

  static const _storageKey = 'exad_app_locale';
  final FlutterSecureStorage _storage;

  Locale? locale;

  Future<void> initialize() async {
    final languageCode = await _storage.read(key: _storageKey);
    locale = switch (languageCode) {
      'fr' => const Locale('fr'),
      'en' => const Locale('en'),
      _ => null,
    };
    notifyListeners();
  }

  Future<void> useSystemLocale() async {
    locale = null;
    await _storage.delete(key: _storageKey);
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    locale = value;
    await _storage.write(key: _storageKey, value: value.languageCode);
    notifyListeners();
  }
}

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('fr'), Locale('en')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const delegate = _AppLocalizationsDelegate();

  String text(String key) {
    final language = locale.languageCode == 'en' ? 'en' : 'fr';
    return _values[language]?[key] ?? _values['fr']?[key] ?? key;
  }

  String format(String key, Map<String, Object> values) {
    var result = text(key);
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }

  static const _values = <String, Map<String, String>>{
    'fr': {
      'login': 'Connexion',
      'login_subtitle': 'Accédez à votre espace de suivi de flotte.',
      'secure_area': 'ESPACE SÉCURISÉ',
      'email': 'Adresse e-mail',
      'email_hint': 'nom@entreprise.com',
      'email_required': 'L’adresse e-mail est requise.',
      'password': 'Mot de passe',
      'password_required': 'Le mot de passe est requis.',
      'sign_in': 'Se connecter',
      'show': 'Afficher',
      'hide': 'Masquer',
      'secure_connection': 'Connexion chiffrée et sécurisée',
      'mobile_platform': 'PLATEFORME MOBILE DE GESTION DE FLOTTE',
      'mobile_value': 'Vos véhicules, vos alertes et vos opérations, partout.',
      'language': 'Langue',
      'system_language': 'Langue du téléphone',
      'french': 'Français',
      'english': 'English',
      'back': 'Retour',
      'two_factor': 'Vérification en deux étapes',
      'two_factor_code_help':
          'Saisissez le code à 6 chiffres de votre application d’authentification.',
      'recovery_help': 'Saisissez l’un de vos codes de récupération.',
      'security_code': 'Code de sécurité',
      'recovery_code': 'Code de récupération',
      'verify': 'Vérifier',
      'use_recovery': 'Utiliser un code de récupération',
      'use_temporary': 'Utiliser le code temporaire',
      'home': 'Accueil',
      'map': 'Carte',
      'vehicles': 'Véhicules',
      'alerts': 'Alertes',
      'more': 'Plus',
      'supervision': 'Supervision',
      'fleet_space': 'ESPACE CLIENT',
      'superadmin_space': 'CONSOLE SUPERADMIN',
      'hello': 'Bonjour {name}',
      'global_overview': 'Vue globale de la plateforme EXAD Tracking',
      'fleet_overview': 'Vue opérationnelle de votre flotte',
      'fleets': 'Flottes',
      'online': 'En ligne',
      'moving': 'En déplacement',
      'attention': 'À vérifier',
      'fleet_activity': 'Activité de la flotte',
      'platform_activity': 'Activité du parc',
      'recent_alerts': 'Alertes récentes',
      'no_vehicle': 'Aucun véhicule disponible.',
      'no_alert': 'Aucune alerte récente.',
      'view_all': 'Voir tout',
      'global_fleet_distribution': 'Répartition des flottes',
      'active_fleets': 'Flottes représentées dans le parc mobile',
      'account_access': 'Compte et accès mobile',
      'role': 'Rôle',
      'fleet': 'Flotte',
      'unassigned': 'Non affectée',
      'two_factor_short': 'Double authentification',
      'enabled': 'Activée',
      'disabled': 'Désactivée',
      'authorized_access': 'Accès autorisés',
      'logout': 'Se déconnecter',
      'settings': 'Préférences',
      'vehicle_count': '{count} véhicule(s) dans votre flotte',
      'search_vehicle': 'Rechercher par nom ou immatriculation',
      'all': 'Tous',
      'offline': 'Hors ligne',
      'no_search_result': 'Aucun véhicule ne correspond à cette recherche.',
      'status': 'Statut',
      'speed': 'Vitesse',
      'last_position': 'Dernière position',
      'last_signal': 'Dernier signal',
      'new_alert_count': '{count} nouvelle(s) alerte(s)',
      'only_new_alerts': 'Afficher uniquement les nouvelles',
      'no_alert_selection': 'Aucune alerte dans cette sélection.',
      'positioned_vehicle_count': '{count} véhicule(s) positionné(s)',
      'refresh': 'Actualiser',
      'live_tracking': 'Suivi direct',
      'updating': 'Mise \u00e0 jour...',
      'waiting_for_update': 'En attente du signal',
      'updated_at': 'Actualis\u00e9 \u00e0 {time}',
      'map_refresh_failed':
          'La carte ne peut pas \u00eatre actualis\u00e9e pour le moment.',
      'stationary_running': 'Moteur allum\u00e9',
      'maintenance': 'Maintenance',
      'inactive': 'Inactif',
      'no_position': 'Aucune position disponible pour votre flotte.',
      'move_zoom': 'Déplacer et zoomer',
      'close': 'Fermer',
      'map_menu': 'Véhicules sur la carte',
      'show_map_menu': 'Afficher la liste des véhicules',
      'hide_map_menu': 'Masquer la liste des véhicules',
      'my_location': 'Ma position',
      'location_permission_title': 'Activer la géolocalisation',
      'location_permission_help':
          'Autorisez EXAD Tracking à utiliser votre position pendant l’utilisation de l’application.',
      'location_service_disabled':
          'La localisation du téléphone est désactivée.',
      'location_permission_denied': 'L’accès à votre position a été refusé.',
      'location_unavailable': 'Votre position est momentanément indisponible.',
      'allow': 'Autoriser',
      'open_settings': 'Ouvrir les paramètres',
      'not_now': 'Plus tard',
      'vehicle_details': 'Détails du véhicule',
      'tracker_details': 'Détails du traceur',
      'model': 'Modèle',
      'details': 'Détails',
      'tracking': 'Suivi GPS',
      'configured': 'Configuré',
      'not_configured': 'Aucun traceur',
      'ignition': 'Contact',
      'on': 'Allumé',
      'off': 'Éteint',
      'heading': 'Direction',
      'trips': 'Trajets',
      'events': 'Événements',
      'no_event': 'Aucun événement pour ce véhicule.',
      'no_trip': 'Aucun trajet sur cette période.',
      'today': 'Aujourd’hui',
      'yesterday': 'Hier',
      'this_week': 'Cette semaine',
      'this_month': 'Ce mois',
      'trip_number': 'Trajet {number}',
      'distance': 'Distance',
      'duration': 'Durée',
      'average_speed': 'Vitesse moyenne',
      'maximum_speed': 'Vitesse maximale',
      'registration': 'Immatriculation',
      'location': 'Emplacement',
      'gps_quality': 'Qualité GPS',
      'coordinates': 'Coordonnées',
      'movement_state': 'État',
      'address': 'Adresse',
      'altitude': 'Altitude',
      'driver': 'Conducteur',
      'no_driver_identified': 'Aucun conducteur identifié pour ce véhicule.',
      'name': 'Nom',
      'employee_id': 'Identifiant employé',
      'department': 'Département',
      'identifier': 'Identifiant RFID / iButton / NFC',
      'phone': 'Téléphone',
      'power': 'Alimentation',
      'data_unavailable': 'Donnée indisponible.',
      'external_voltage': 'Tension externe',
      'internal_battery': 'Batterie interne',
      'battery_level': 'Niveau batterie',
      'signal': 'Signal',
      'operator': 'Opérateur',
      'tracker_diagnostic': 'Diagnostic traceur',
      'satellites': 'Satellites',
      'protocol': 'Protocole',
      'odometer': 'Odomètre',
      'engine_hours': 'Heures moteur',
      'inputs_outputs': 'Entrées / sorties',
      'sensors': 'Capteurs',
      'no_obd_data': 'Aucune donnée OBD/CAN reçue pour ce traceur.',
      'runtime': 'Temps moteur',
      'throttle': 'Papillon',
      'engine_temperature': 'Température moteur',
      'module_voltage': 'Tension du module',
      'engine_load': 'Charge moteur',
      'fuel_level': 'Niveau carburant',
      'fault_distance': 'Distance avec défaut',
      'errors': 'Erreurs OBD',
      'distance_since_clear': 'Distance depuis réinitialisation',
      'recent_events': 'Derniers événements',
      'parking': 'En stationnement',
      'moving_now': 'En mouvement',
      'stopped': 'À l’arrêt',
      'map_configuration_missing':
          'La clé Google Maps Android doit être configurée pour afficher le fond de carte.',
    },
    'en': {
      'login': 'Sign in',
      'login_subtitle': 'Access your fleet tracking workspace.',
      'secure_area': 'SECURE WORKSPACE',
      'email': 'Email address',
      'email_hint': 'name@company.com',
      'email_required': 'The email address is required.',
      'password': 'Password',
      'password_required': 'The password is required.',
      'sign_in': 'Sign in',
      'show': 'Show',
      'hide': 'Hide',
      'secure_connection': 'Encrypted and secure connection',
      'mobile_platform': 'MOBILE FLEET MANAGEMENT PLATFORM',
      'mobile_value': 'Your vehicles, alerts and operations, everywhere.',
      'language': 'Language',
      'system_language': 'Phone language',
      'french': 'Français',
      'english': 'English',
      'back': 'Back',
      'two_factor': 'Two-step verification',
      'two_factor_code_help':
          'Enter the 6-digit code from your authenticator app.',
      'recovery_help': 'Enter one of your recovery codes.',
      'security_code': 'Security code',
      'recovery_code': 'Recovery code',
      'verify': 'Verify',
      'use_recovery': 'Use a recovery code',
      'use_temporary': 'Use the temporary code',
      'home': 'Home',
      'map': 'Map',
      'vehicles': 'Vehicles',
      'alerts': 'Alerts',
      'more': 'More',
      'supervision': 'Supervision',
      'fleet_space': 'CLIENT WORKSPACE',
      'superadmin_space': 'SUPERADMIN CONSOLE',
      'hello': 'Hello {name}',
      'global_overview': 'Global EXAD Tracking platform overview',
      'fleet_overview': 'Operational view of your fleet',
      'fleets': 'Fleets',
      'online': 'Online',
      'moving': 'Moving',
      'attention': 'To review',
      'fleet_activity': 'Fleet activity',
      'platform_activity': 'Platform activity',
      'recent_alerts': 'Recent alerts',
      'no_vehicle': 'No vehicle available.',
      'no_alert': 'No recent alert.',
      'view_all': 'View all',
      'global_fleet_distribution': 'Fleet distribution',
      'active_fleets': 'Fleets represented in the mobile vehicle base',
      'account_access': 'Account and mobile access',
      'role': 'Role',
      'fleet': 'Fleet',
      'unassigned': 'Unassigned',
      'two_factor_short': 'Two-factor authentication',
      'enabled': 'Enabled',
      'disabled': 'Disabled',
      'authorized_access': 'Authorized access',
      'logout': 'Sign out',
      'settings': 'Preferences',
      'vehicle_count': '{count} vehicle(s) in your fleet',
      'search_vehicle': 'Search by name or registration',
      'all': 'All',
      'offline': 'Offline',
      'no_search_result': 'No vehicle matches this search.',
      'status': 'Status',
      'speed': 'Speed',
      'last_position': 'Last position',
      'last_signal': 'Last signal',
      'new_alert_count': '{count} new alert(s)',
      'only_new_alerts': 'Show new alerts only',
      'no_alert_selection': 'No alert in this selection.',
      'positioned_vehicle_count': '{count} positioned vehicle(s)',
      'refresh': 'Refresh',
      'live_tracking': 'Live tracking',
      'updating': 'Updating...',
      'waiting_for_update': 'Waiting for signal',
      'updated_at': 'Updated at {time}',
      'map_refresh_failed': 'The map cannot be refreshed right now.',
      'stationary_running': 'Engine running',
      'maintenance': 'Maintenance',
      'inactive': 'Inactive',
      'no_position': 'No position available for your fleet.',
      'move_zoom': 'Pan and zoom',
      'close': 'Close',
      'map_menu': 'Vehicles on the map',
      'show_map_menu': 'Show vehicle list',
      'hide_map_menu': 'Hide vehicle list',
      'my_location': 'My location',
      'location_permission_title': 'Enable location',
      'location_permission_help':
          'Allow EXAD Tracking to use your location while using the app.',
      'location_service_disabled': 'Phone location services are disabled.',
      'location_permission_denied': 'Location access was denied.',
      'location_unavailable': 'Your location is temporarily unavailable.',
      'allow': 'Allow',
      'open_settings': 'Open settings',
      'not_now': 'Not now',
      'vehicle_details': 'Vehicle details',
      'tracker_details': 'Tracker details',
      'model': 'Model',
      'details': 'Details',
      'tracking': 'GPS tracking',
      'configured': 'Configured',
      'not_configured': 'No tracker',
      'ignition': 'Ignition',
      'on': 'On',
      'off': 'Off',
      'heading': 'Heading',
      'trips': 'Trips',
      'events': 'Events',
      'no_event': 'No event for this vehicle.',
      'no_trip': 'No trip for this period.',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'this_week': 'This week',
      'this_month': 'This month',
      'trip_number': 'Trip {number}',
      'distance': 'Distance',
      'duration': 'Duration',
      'average_speed': 'Average speed',
      'maximum_speed': 'Maximum speed',
      'registration': 'Registration',
      'location': 'Location',
      'gps_quality': 'GPS quality',
      'coordinates': 'Coordinates',
      'movement_state': 'State',
      'address': 'Address',
      'altitude': 'Altitude',
      'driver': 'Driver',
      'no_driver_identified': 'No driver identified for this vehicle.',
      'name': 'Name',
      'employee_id': 'Employee ID',
      'department': 'Department',
      'identifier': 'RFID / iButton / NFC identifier',
      'phone': 'Phone',
      'power': 'Power',
      'data_unavailable': 'Data unavailable.',
      'external_voltage': 'External voltage',
      'internal_battery': 'Internal battery',
      'battery_level': 'Battery level',
      'signal': 'Signal',
      'operator': 'Operator',
      'tracker_diagnostic': 'Tracker diagnostic',
      'satellites': 'Satellites',
      'protocol': 'Protocol',
      'odometer': 'Odometer',
      'engine_hours': 'Engine hours',
      'inputs_outputs': 'Inputs / outputs',
      'sensors': 'Sensors',
      'no_obd_data': 'No OBD/CAN data received for this tracker.',
      'runtime': 'Engine runtime',
      'throttle': 'Throttle',
      'engine_temperature': 'Engine temperature',
      'module_voltage': 'Module voltage',
      'engine_load': 'Engine load',
      'fuel_level': 'Fuel level',
      'fault_distance': 'Distance with fault',
      'errors': 'OBD errors',
      'distance_since_clear': 'Distance since reset',
      'recent_events': 'Latest events',
      'parking': 'Parked',
      'moving_now': 'Moving',
      'stopped': 'Stopped',
      'map_configuration_missing':
          'The Android Google Maps key must be configured to display the basemap.',
    },
  };
}

extension AppLocalizationContext on BuildContext {
  String tr(String key) => AppLocalizations.of(this).text(key);

  String trFormat(String key, Map<String, Object> values) =>
      AppLocalizations.of(this).format(key, values);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (item) => item.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
