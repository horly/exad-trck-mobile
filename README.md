# EXAD Tracking Mobile

Application Flutter Android/iOS destinée aux comptes clients EXAD Tracking.

## Architecture

- `lib/core/api` : client HTTP, renouvellement des jetons et erreurs API.
- `lib/core/storage` : stockage sécurisé de la session et identifiant d’appareil.
- `lib/core/session` : état global d’authentification et données de flotte.
- `lib/core/localization` : langue du téléphone et préférence FR/EN persistante.
- `lib/features/auth` : connexion et authentification à deux facteurs.
- `lib/features/dashboard` : synthèse opérationnelle de la flotte.
- `lib/features/map` : vue interactive des véhicules positionnés.
- `lib/features/vehicles` : recherche et état des véhicules.
- `lib/features/alerts` : alertes de la flotte.
- `lib/features/more` : profil, permissions et déconnexion.

## API locale

L’émulateur Android utilise par défaut :

```text
https://exadtracking.app/api/v1/mobile
```

Une autre URL peut être fournie au build :

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1/mobile
```

Les jetons d’accès et de rafraîchissement sont conservés avec
`flutter_secure_storage`. L’application ne contient aucune clé serveur.

## Google Maps Android

La carte utilise `google_maps_flutter`. La clé mobile doit être distincte de la
clé web ou serveur et rester absente de Git.

1. Activer **Maps SDK for Android** dans Google Cloud avec la facturation.
2. Créer une clé restreinte aux applications Android.
3. Autoriser l’application `com.exad.exad_tracking_mobile` avec le SHA-1 du
   certificat de signature.
4. Ajouter la clé dans `android/local.properties` :

```properties
MAPS_API_KEY=VOTRE_CLE_ANDROID
```

SHA-1 du certificat de développement actuel :

```text
DA:0C:99:F1:D6:2E:12:28:16:A3:B9:31:27:5A:8F:4F:A5:8E:03:49
```

Une clé et un SHA-1 propres à la signature de production seront configurés au
moment de préparer la publication Play Store.

La géolocalisation est demandée seulement lorsque l’utilisateur appuie sur le
bouton « Ma position ». Aucun suivi en arrière-plan n’est activé.

## Espaces et langue

- Un compte client obtient un dashboard opérationnel limité à sa flotte.
- Un superadmin obtient une console de supervision globale et une navigation
  visuellement distincte.
- La langue suit le téléphone par défaut. Le choix peut être remplacé par
  Français ou English depuis la connexion ou les préférences du compte.

## Vérification

```powershell
flutter analyze
flutter test
```
