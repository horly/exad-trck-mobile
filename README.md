# EXAD Tracking Mobile

Application Flutter officielle de supervision de flotte EXAD Tracking pour Android et iOS.

L’application permet aux comptes clients et aux superadministrateurs autorisés de consulter leur tableau de bord, suivre les véhicules sur une carte, rechercher un véhicule, afficher ses détails opérationnels, ses trajets, ses événements et les alertes de flotte.

## Fonctionnalités principales

- Connexion sécurisée à l’API mobile privée EXAD Tracking.
- Authentification à deux facteurs par code TOTP ou code de récupération.
- Renouvellement automatique des jetons d’accès et de rafraîchissement.
- Stockage sécurisé de la session et de l’identifiant stable de l’appareil.
- Dashboard client limité à sa flotte et console distincte pour le superadministrateur.
- Carte Google Maps avec filtres d’état, recherche et actualisation toutes les 10 secondes.
- Animation des véhicules en mouvement entre deux positions GPS.
- Détails du véhicule, emplacement, conducteur, alimentation, GSM, diagnostic et OBD/CAN.
- Ouverture directe de la carte et focus du marqueur depuis les listes d’activité et de véhicules.
- Consultation des trajets, traces cartographiques et événements.
- Alertes corporate avec distinction des nouvelles et badge de navigation dynamique.
- Interface française et anglaise avec mémorisation de la préférence.
- Géolocalisation du téléphone uniquement à la demande de l’utilisateur.

## Socle technique

| Composant | Usage |
| --- | --- |
| Flutter / Dart | Interface Android et iOS |
| `http` | Communication avec l’API REST |
| `flutter_secure_storage` | Jetons, session, identifiant d’appareil et langue |
| `google_maps_flutter` | Carte, marqueurs et traces GPS |
| `geolocator` | Position ponctuelle du téléphone |
| `flutter_test` | Tests de modèles et tests de widgets |

La version applicative courante est définie dans `pubspec.yaml` : `1.0.0+2`.

## Prérequis

- Flutter stable compatible avec Dart `^3.11.5`.
- Android Studio et un SDK Android pour Android.
- Xcode, CocoaPods et un compte Apple Developer pour iOS.
- Accès à l’API mobile EXAD Tracking.
- Une clé Google Maps distincte et restreinte pour chaque plateforme.

Vérifier l’environnement :

```powershell
flutter doctor
flutter devices
```

## Démarrage rapide

Installer les dépendances :

```powershell
flutter pub get
```

Ajouter la clé Google Maps Android dans `android/local.properties`, fichier local exclu de Git :

```properties
MAPS_API_KEY=VOTRE_CLE_ANDROID_RESTREINTE
```

Lancer l’application sur un appareil détecté :

```powershell
flutter run -d emulator-5554
```

L’API de production est utilisée par défaut :

```text
https://exadtracking.app/api/v1/mobile
```

Une autre base peut être injectée au moment du build :

```powershell
flutter run --dart-define=API_BASE_URL=https://votre-api.example/api/v1/mobile
```

`API_BASE_URL` est une configuration compilée dans l’application. Elle ne doit contenir ni jeton, ni mot de passe, ni secret serveur.

## Vérification

Avant tout commit ou build :

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Générer un APK en incrémentant automatiquement le numéro de build :

```powershell
.\tools\build_apk.ps1 -Mode release
```

## Structure du dépôt

```text
lib/
├── core/                 # API, configuration, modèles, session, stockage, thème
├── features/             # Authentification, dashboard, carte, véhicules, alertes
├── shared/               # Composants visuels partagés
├── app.dart              # Composition MaterialApp et routage selon la session
└── main.dart             # Point d’entrée
test/                     # Tests de modèles et de widgets
android/                  # Configuration et intégration Android
ios/                      # Configuration et intégration iOS
docs/                     # Documentation technique et opérationnelle
```

## Documentation

- [Architecture et flux applicatifs](docs/architecture.md)
- [Contrat et intégration avec l’API](docs/api-integration.md)
- [Environnement et développement local](docs/development.md)
- [Build, signature et livraison](docs/release.md)

La documentation du contrat serveur de référence se trouve également dans le projet web, sous `docs/mobile-api.md`.

## Sécurité

- Aucun secret serveur ne doit être embarqué dans l’application.
- Les jetons sont stockés avec `flutter_secure_storage`, jamais dans des préférences ordinaires.
- Les anciennes paires de jetons sont remplacées après chaque rafraîchissement.
- Une réponse `401` provoque une tentative de renouvellement ; un échec ferme la session locale.
- Les permissions et le cloisonnement de flotte sont imposés par le serveur et reflétés dans l’interface.
- Les clés Google Maps doivent être restreintes au package Android ou au bundle iOS et aux API strictement nécessaires.

## État de préparation des plateformes

- Android debug : fonctionnel avec une clé Maps locale.
- Android release : la configuration utilise encore la signature debug ; configurer une keystore de production avant diffusion.
- iOS : la description d’autorisation de localisation est présente, mais l’initialisation de la clé Google Maps doit être finalisée avant publication.

Consulter la [checklist de livraison](docs/release.md) avant toute distribution à des utilisateurs.
