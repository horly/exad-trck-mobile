# Développement local

## Installation

Depuis la racine du dépôt :

```powershell
flutter doctor
flutter pub get
flutter devices
```

Le projet exige un SDK Dart compatible avec `^3.11.5`. Utiliser de préférence le canal Flutter stable commun à l’équipe.

## Configuration de l’API

Sans option, l’application utilise la production :

```text
https://exadtracking.app/api/v1/mobile
```

Pour un environnement de développement accessible en HTTPS :

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=https://dev.example/api/v1/mobile
```

Pour joindre un serveur exécuté sur la machine hôte depuis l’émulateur Android, l’adresse de l’hôte est généralement `10.0.2.2`. Android bloque toutefois le HTTP non chiffré par défaut ; privilégier HTTPS ou ajouter une configuration réseau limitée au build debug. Ne jamais autoriser globalement le trafic clair dans un build de production.

## Google Maps Android

La clé Android est lue dans `android/local.properties` et injectée dans le manifeste par Gradle :

```properties
sdk.dir=C:\\Users\\UTILISATEUR\\AppData\\Local\\Android\\Sdk
flutter.sdk=C:\\chemin\\vers\\flutter
MAPS_API_KEY=VOTRE_CLE_ANDROID
```

`local.properties` est exclu de Git. La clé Google Cloud doit être restreinte :

- API autorisée : Maps SDK for Android ;
- package : `com.exad.exad_tracking_mobile` ;
- SHA-1 : empreinte du certificat utilisé pour le build concerné.

Empreinte du certificat de développement historiquement utilisé :

```text
DA:0C:99:F1:D6:2E:12:28:16:A3:B9:31:27:5A:8F:4F:A5:8E:03:49
```

Cette empreinte ne doit pas être utilisée comme restriction du build de production. Ajouter séparément le SHA-1 de la keystore de diffusion.

## Google Maps iOS

Le projet iOS contient déjà la description de localisation `NSLocationWhenInUseUsageDescription`. L’initialisation de Google Maps n’est pas encore présente dans `AppDelegate.swift`.

Avant de tester la carte sur iOS :

1. créer une clé réservée au Maps SDK for iOS ;
2. la restreindre au bundle identifier de l’application ;
3. prévoir une injection locale ou CI, sans committer la clé ;
4. appeler `GMSServices.provideAPIKey(...)` au démarrage ;
5. installer les pods et vérifier sur un appareil réel.

## Exécution

Android :

```powershell
flutter run -d emulator-5554
```

Chrome peut servir à vérifier des widgets génériques, mais la carte et le stockage sécurisé doivent être validés sur Android ou iOS :

```powershell
flutter run -d chrome
```

Lister les appareils disponibles :

```powershell
flutter devices
```

## Qualité du code

Formater sans modifier lors d’une vérification CI :

```powershell
dart format --output=none --set-exit-if-changed lib test
```

Formater localement :

```powershell
dart format lib test
```

Analyser et tester :

```powershell
flutter analyze
flutter test
```

La suite actuelle couvre :

- le parsing des états de véhicules et de la trace cartographique ;
- le parsing des rubriques détaillées du véhicule ;
- les écrans de connexion FR/EN ;
- les dashboards client et superadmin ;
- la navigation vers les véhicules.

Toute correction de données ou de rendu doit ajouter un test lorsqu’une régression peut être reproduite sans Google Maps natif.

## Ajout d’une fonctionnalité

Ordre recommandé :

1. confirmer le contrat dans l’API Laravel ;
2. adapter les modèles Dart ;
3. ajouter la méthode dans `ApiClient` ;
4. exposer l’action via `SessionController` ;
5. construire l’écran dans le dossier `features` approprié ;
6. ajouter les libellés français et anglais ;
7. ajouter ou adapter les tests ;
8. exécuter formatage, analyse et tests ;
9. vérifier sur un appareil à faible largeur.

## Données et confidentialité

- Ne pas utiliser de vrais mots de passe ou jetons dans les fixtures.
- Éviter de joindre aux commits des captures contenant des positions réelles.
- Ne pas imprimer les réponses d’authentification dans les logs.
- Ne pas committer `local.properties`, keystores, profils de provisioning ou clés Maps.
- Utiliser des données synthétiques dans les tests et la documentation.

## Dépannage

### La carte reste grise

- vérifier `MAPS_API_KEY` dans `android/local.properties` ;
- vérifier la facturation Google Cloud ;
- vérifier le package et le SHA-1 autorisés ;
- vérifier que Maps SDK for Android est activé ;
- reconstruire complètement l’application après modification de la clé.

### L’API est inaccessible depuis l’émulateur

- utiliser `10.0.2.2` au lieu de `localhost` pour le serveur hôte ;
- vérifier le certificat HTTPS ;
- vérifier le pare-feu et l’écoute du serveur ;
- confirmer que la valeur contient bien `/api/v1/mobile`.

### La session revient à la connexion

- contrôler l’heure du téléphone ;
- vérifier l’expiration et la rotation des jetons côté serveur ;
- confirmer que le compte et sa flotte sont actifs ;
- vérifier si la même identité d’appareil a été reconnectée ailleurs.

### Un ancien utilisateur reste affiché après réinstallation

`flutter run` et l’installation d’un nouvel APK sur le même package mettent l’application à jour sans effacer le stockage sécurisé. La session précédente est donc restaurée et `/bootstrap` retourne le propriétaire de ce jeton.

Pour changer de compte, utiliser « Se déconnecter » puis saisir les identifiants attendus. Sur un émulateur de développement uniquement, un effacement des données Android force également une nouvelle connexion, mais détruit toute la session locale.

### La géolocalisation du téléphone ne fonctionne pas

- activer le service de localisation ;
- autoriser la localisation pendant l’utilisation ;
- après un refus permanent, ouvrir les paramètres de l’application ;
- définir une position simulée dans l’émulateur.
