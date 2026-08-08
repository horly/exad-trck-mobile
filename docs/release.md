# Build et livraison

## État actuel

Le projet peut produire et installer un APK debug. Il n’est pas encore prêt à être distribué publiquement sans finaliser :

- la signature Android avec une keystore de production ;
- les restrictions Google Maps associées au certificat de production ;
- l’initialisation sécurisée de Google Maps sur iOS ;
- les identifiants, certificats et profils Apple ;
- la politique de confidentialité et les fiches des stores.

Le bloc `release` de `android/app/build.gradle.kts` utilise actuellement la signature debug. Ne pas publier un artefact produit avec cette configuration.

## Versionnement

La version se trouve dans `pubspec.yaml` :

```yaml
version: 1.0.0+2
```

- `1.0.0` devient `versionName` Android et `CFBundleShortVersionString` iOS.
- `1` devient `versionCode` Android et `CFBundleVersion` iOS.

À chaque livraison :

1. augmenter le numéro lisible selon l’importance du changement ;
2. augmenter systématiquement le numéro de build ;
3. vérifier que la version transmise lors de la connexion mobile reste cohérente ;
4. identifier le commit Git correspondant à l’artefact.

Pour un APK, ne pas appeler directement `flutter build apk`. Utiliser le script du projet, qui calcule le prochain numéro, compile avec cette version, puis met à jour les valeurs sources uniquement si le build réussit :

```powershell
.\tools\build_apk.ps1 -Mode release
```

## Signature Android

Créer la keystore en dehors du dépôt et la conserver dans un coffre sécurisé. Ne jamais la transmettre par messagerie ni la committer.

La configuration cible doit :

- lire les chemins et mots de passe depuis `android/key.properties` ou des variables CI protégées ;
- déclarer une `signingConfig` de production ;
- associer cette configuration au build `release` ;
- conserver la keystore et ses mots de passe dans des sauvegardes contrôlées.

`android/key.properties`, `*.jks` et `*.keystore` sont déjà exclus de Git.

Après configuration, relever les empreintes SHA-1 et SHA-256 du certificat de production, puis les autoriser dans la clé Google Maps Android.

## Configuration de production

La base API peut être fixée explicitement lors du build :

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://exadtracking.app/api/v1/mobile
```

Même si cette URL correspond à la valeur par défaut, la fournir explicitement dans le pipeline rend la configuration de livraison traçable.

Ne jamais passer une clé Google Maps ou un secret serveur par `dart-define`. Une valeur `dart-define` peut être extraite du binaire.

## Builds Android

APK de contrôle interne :

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://exadtracking.app/api/v1/mobile
```

Android App Bundle pour Google Play :

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://exadtracking.app/api/v1/mobile
```

Artefacts habituels :

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

Vérifier la signature de l’APK ou de l’AAB avant transfert. Conserver avec l’artefact : version, numéro de build, commit Git, date, environnement API et empreinte SHA-256 du fichier.

## Build iOS

Le build iOS nécessite macOS, Xcode et les droits Apple appropriés :

```bash
flutter pub get
cd ios
pod install
cd ..
flutter build ipa --release --dart-define=API_BASE_URL=https://exadtracking.app/api/v1/mobile
```

Avant ce build, finaliser l’injection de la clé Google Maps iOS dans `AppDelegate.swift` et vérifier qu’aucune clé n’est suivie par Git.

## Checklist avant livraison

### Code et tests

- [ ] Arbre Git propre et commit de livraison identifié.
- [ ] Version et numéro de build augmentés.
- [ ] `dart format --output=none --set-exit-if-changed lib test` réussi.
- [ ] `flutter analyze` réussi sans avertissement.
- [ ] `flutter test` réussi.
- [ ] Test manuel Android sur une faible largeur d’écran.
- [ ] Test manuel des comptes client et superadmin.

### Authentification et sécurité

- [ ] Connexion simple validée.
- [ ] Connexion 2FA TOTP validée.
- [ ] Code de récupération validé.
- [ ] Rotation des jetons validée après expiration de l’access token.
- [ ] Déconnexion et suppression de la session locale validées.
- [ ] Aucun jeton, mot de passe, keystore ou clé privée dans l’artefact documentaire ou Git.

### Carte et GPS

- [ ] Clé Maps restreinte au package ou bundle et au certificat de livraison.
- [ ] Carte visible sur appareil réel.
- [ ] États mouvement, stationnement et hors ligne vérifiés.
- [ ] Actualisation en direct vérifiée.
- [ ] Détails, adresse, trajets et événements cohérents pour le même véhicule.
- [ ] Permission « Ma position » testée en acceptation, refus et refus permanent.

### Stores et conformité

- [ ] Icône, nom, captures et description validés.
- [ ] Politique de confidentialité publiée.
- [ ] Déclarations d’utilisation de la localisation cohérentes avec l’application.
- [ ] Questionnaire de sécurité des données complété.
- [ ] Notes de version préparées en français et en anglais.

## Livraison interne

Pour une recette hors store :

1. produire un APK signé avec une clé de recette contrôlée ;
2. calculer son SHA-256 ;
3. le déposer sur un canal interne authentifié ;
4. communiquer la version, le commit et les changements testés ;
5. ne jamais envoyer la keystore avec l’APK.

## Retour arrière

Le binaire mobile et l’API évoluent séparément. En cas d’incident :

- conserver la compatibilité de l’API `/v1` avec la version mobile déjà installée ;
- désactiver côté serveur une fonctionnalité non critique si elle rend l’ancien client instable ;
- republier un build avec un numéro supérieur, les stores ne permettant pas de réinstaller un ancien numéro de build comme nouvelle version ;
- documenter le commit, l’impact, la correction et les vérifications effectuées.
