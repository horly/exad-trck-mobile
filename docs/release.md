# Build et livraison

## État actuel

Le build Android **1.0.0+43** du 8 octobre 2026 place l'historique en haut de la carte, y compris lorsqu'il est réduit, et adapte le cadrage à l'espace visible en bas. Artefact signé : `build/app/outputs/bundle/release/EXAD-Tracking-1.0.0+43.aab`. Notes françaises fournies à côté du bundle. Vérifié sur l'émulateur ; prêt à importer dans Google Play, aucune publication effectuée.

La configuration `release` utilise `android/key.properties`. L’option explicite `EXAD_ANDROID_LEGACY_SIGNING=1` est réservée aux APK internes compatibles avec les anciennes installations ; elle doit être absente ou à `0` pour Google Play. Ne jamais publier un AAB signé avec le certificat de développement.

La clé privée et ses mots de passe sont exclus des artefacts de livraison et de Git. Le certificat de signature de l’application distribué par Google Play peut être différent du certificat d’importation local ; utiliser le certificat indiqué dans Play Console pour les restrictions Google Maps.

Les étapes Apple restent distinctes : initialisation Maps iOS, identifiants, certificats et profils de distribution Apple.

## Versionnement

La version se trouve dans `pubspec.yaml` :

```yaml
version: 1.0.0+39
```

- `1.0.0` devient `versionName` Android et `CFBundleShortVersionString` iOS.
- `39` devient `versionCode` Android et `CFBundleVersion` iOS.

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


## 2026-10-05 — Historique sur la carte, build 40

Panneau TripHistoryPanel intégré à MapScreen : résumé de période, chronologie par date, trajets/parkings, sélection exclusive ou multiple, repères départ (lecture) et arrivée (drapeau damier) dessinés localement, repère P et lecture du tracé avec pause/vitesse/progression. Le panneau reste visible pendant la sélection, peut être réduit et se ferme sans laisser de tracé. L’actualisation des véhicules continue mais le centrage automatique est suspendu pendant la consultation. Les dates personnalisées passent par SessionController et ApiClient. Modèles additifs VehicleHistoryItem et coordonnées exactes, compatibles avec un serveur ne renvoyant pas encore history. Les coupures de transmission sont distinctes des stationnements ; aucun prolongement artificiel du parking jusqu’à minuit.

API de production mise à jour : GET /api/v1/mobile/vehicles/{vehicle}/trips contient désormais history.items, parking_count, parking_seconds et elapsed_seconds ; start_coordinates/end_coordinates sont les extrémités GPS, indépendantes du tracé éventuellement ajusté sur la route. Les droits de flotte et le masquage des identifiants du traceur restent appliqués. Déploiement : 2026-10-05T12:56:46.627123+00:00, sauvegarde /var/backups/api-history-20261005-125645.tar.gz, GPS non redémarré. Le correctif de géocodage séparé en attente d’autorisation n’a pas été inclus.

Validation du lot : 39 tests Flutter réussis, dont 4 nouveaux tests de modèles et interactions (chronologie, parking seul, panneau étroit, réponse obsolète, arrêt de la lecture lors de la fermeture). Flutter analyze : aucune erreur ni avertissement. 10 tests PHP API/historique réussis, 43 assertions. Les tests d’interfaces utilisent des données synthétiques ; pas de recette sur téléphone réel ni de validation visuelle du fond Google Maps pour ce build.

Bundle signé : build/app/outputs/bundle/release/EXAD-Tracking-1.0.0+40.aab
Version : 1.0.0+40 ; package : com.exad.exad_tracking_mobile.
SHA-256 : 7616ba2a79edd8f2f22ba336652690da44d4fad0b63aeb50f00360e3313a1826
Taille : 47243050 octets. Bundletool valide le bundle et le versionCode 40. Certificat d’importation identique au build 39 ; huit bibliothèques 64 bits et configuration du bundle compatibles avec les pages 16 Ko. Clé Maps et signatures existantes conservées. Le bundle est prêt à importer dans Google Play ; aucune publication sur le store effectuée.


## 6 octobre 2026 — Design du panneau et build 41

TripHistoryPanel reprend le thème de l’application : en-tête à couleur primaire, nom du véhicule, surfaces arrondies, contrôles plus lisibles et cartes distinctes pour trajets/parkings. MapScreen place le panneau à 34 % de la hauteur disponible sur téléphone (138–280 px), à 16 px du haut sur grand écran, avec marges Google Maps adaptées à la réduction/expansion. Les données de session et les clés de signature/Maps sont conservées.

Vérifications de ce lot : analyse statique ciblée des deux écrans sans problème ; 4 tests trip_history_test.dart réussis (modèles, sélection, défilement vers un parking hors écran, largeur 300 px, réponses obsolètes et arrêt de la lecture). Le test existant utilise désormais scrollUntilVisible pour le chargement différé des lignes agrandies. Pas de nouvelle suite Flutter complète.

Build 1.0.0+41 : D:/App/Codex/exad-tracking-mobile/build/app/outputs/bundle/release/EXAD-Tracking-1.0.0+41.aab
SHA-256 : 07850f00b048af25eaac3777cd5e1c476f9373aae91802726cfcfe835fff03ab
Taille : 47264141 octets. Bundletool valide le bundle et versionCode 41 ; certificat d’importation identique au build 39, huit bibliothèques 64 bits et configuration vérifiées pour pages de 16 Ko. Build 40 conservé. Aucune publication Google Play effectuée.

APK de recette dérivé de ce bundle avec la signature debug existante, installé par adb install -r dans Pixel_9_Pro (emulator-5554), session conservée, activité principale démarrée et versionCode 41 contrôlé. Recette visuelle du résumé et du détail sur un véhicule avec parking seul, fond Google Maps visible, panneau remonté et lisible. Un premier chargement a affiché une erreur générique, puis a réussi après Réessayer (HTTP 200 observé) ; cause initiale non établie, aucun correctif réseau prétendu. Les trajets, choix de vitesse et multisélection sont couverts par les tests ciblés, sans nouvelle recette physique. Captures et reçus : DASHCAM/analysis/history-design-20261005/.


## 7 octobre 2026 — Position directe à la sélection et à la reprise

Demande : à la sélection d'un véhicule, afficher immédiatement sa dernière position connue au lieu d'animer un rattrapage depuis une ancienne session.

Web Google Maps : les rendus déclenchés par la sélection, les filtres ou la reprise sont instantanés. Seule une nouvelle réponse de suivi continu peut animer un marqueur déjà affiché. Sélection pendant une animation : annulation du mouvement en cours, placement à la dernière coordonnée et nouvelle lecture serveur sans animation. Onglet caché : requête invalidée, animations et marqueurs supprimés ; retour visible ou retour via cache navigateur : nouvelle lecture et initialisation directe. Les réponses de requêtes dépassées sont ignorées sur Google Maps et Mapbox. Mapbox, qui n'interpole pas les marqueurs, relit également les données à la sélection et à la reprise.

Web et mobile utilisent position_time, horodatage GPS last_position_at ajouté de façon compatible aux deux réponses cartographiques. L'animation exige un suivi sans interruption (moins de 30 s entre réponses), deux mesures GPS strictement croissantes séparées d'au plus 60 s, une mesure de moins de 120 s, et un déplacement de moins de 600 m. Absence d'horodatage, duplication, longue coupure ou saut important : position directe. Les tracés récents provenant du serveur restent affichables ; on ne relie plus un ancien marqueur au tracé de rattrapage lors d'une sélection. Aucun changement du stockage GPS, des listeners, du géocodage ou de la lecture de l'historique.

Mobile : arrêt du timer d'animation et remise à zéro de la continuité en sortie de carte, en arrière-plan, au redémarrage du suivi ou après erreur réseau. Première réponse après reprise sans animation, requête commencée avant la pause ignorée. La sélection efface le mouvement du véhicule, centre directement sur ses coordonnées connues, puis relit le serveur et applique la première mise à jour sans rattrapage. Un relevé inchangé ne provoque plus un recentrage systématique.

Contrôles de ce lot : 11 tests PHP ciblés / 158 assertions (carte, accès client, API mobile) sur SQLite isolé ; 14 tests Node réussis, dont nouveaux cas de sélection pendant une animation, reprise d'onglet, réponse dépassée et politique de fraîcheur. 18 tests Flutter ciblés réussis (six nouveaux cas de politique GPS/modèle, modèles existants et historique), puis six tests GPS rejoués après ajustement du recentrage et des accolades. Analyse statique Flutter des quatre fichiers concernés : aucun problème. Syntaxe JS et diff --check ciblé conformes. Pas de nouvelle recette visuelle interactive ni d'essai sur véhicule physique ; tests de déplacement exécutés avec données synthétiques et SDK cartographique simulé.

Web/API déployés le 2026-10-07T08:41:21.463576+00:00 : six fichiers, empreintes contrôlées et vues recompilées. Sauvegarde /var/backups/api-live-position-20261007-084118.tar.gz, SHA-256 4a16843c82d8775c81fcac5a3c1f89b9b34fa1a485567a323d29d297e9d399ee. Login, santé et trois ressources JavaScript HTTP 200 avec empreintes conformes. PHP-FPM rechargé ; service GPS actif et PID inchangé. Aucune migration.

Bundle signé 1.0.0+42 : build/app/outputs/bundle/release/EXAD-Tracking-1.0.0+42.aab ; 47265791 octets, SHA-256 61c9cd54a9b03dcb595900ac3bb42ca955ef7fa344ee744a85330e575bd3e998. Validation bundletool, versionCode 42, certificat identique au build 39 et huit bibliothèques 64 bits compatibles avec les pages 16 Ko. API de production et clés Maps/signature existantes conservées. Aucune publication Google Play ni installation sur téléphone effectuée pour ce lot.

Fichiers web/API : MapController, MobileMapController, google-map.js, map.js, nouveau live-map-motion.js et vue map/index (versions live-position-20261007). Mobile : map_screen.dart, nouveau live_position_motion.dart, app_models.dart (champ optionnel positionTime), version/config du build 42. Tests : live-map-motion.test.cjs, live-map-position.test.cjs, adaptation du faux navigateur trip-history-map.test.cjs, live_position_motion_test.dart.

Sources avant/après, reçus, logs du bundle et vérifications : DASHCAM/analysis/live-position-20261007/. Le correctif de géocodage préparé lors d'un autre lot reste hors de ce déploiement.

## 8 octobre 2026 — Historique ancré en haut, build 43

Demande : supprimer l'espace cartographique laissé au-dessus du panneau Historique mobile ; garder l'en-tête réduit en haut, sous les informations du véhicule, et dégager la carte en bas.

MapScreen : origine verticale mobile à 136 px (58 px de barre + 70 px de télémétrie + 8 px d'écart), indépendante de l'état réduit et de la hauteur du téléphone, au lieu de 34 % de l'écran. En portrait, hauteur maximale du panneau limitée à 65 % de la zone restante (plancher de 280 px dans la limite disponible), liste défilante ; espace conservé sous le panneau. Sur écran large, présentation latérale conservée. Boutons de recentrage et de position du téléphone déplacés en bas à droite pendant la consultation en portrait.

La marge Google Maps réserve désormais la partie supérieure occupée, mesurée après mise en page. Le trajet est recadré après mise à jour de cette marge (délai de 180 ms pour l'application native, génération invalidée à la fermeture ou lors d'une autre sélection). Réduction/expansion : en-tête immobile et nouveau cadrage dans l'espace dégagé ; marge de 48 px autour des trajets pour les icônes. Les requêtes GPS, le contenu de l'historique et la lecture sont conservés.

Validation : analyse Flutter ciblée sans problème ; 10 tests existants d'historique et de politique GPS réussis, rejoués après l'ajustement du cadrage. Aucun nouveau test miroir de la disposition. Build release compilé, validation bundletool et versionCode 43, certificat d'importation identique au build 39 ; huit bibliothèques 64 bits et configuration du bundle vérifiées pour les pages 16 Ko. Version de contrôle dérivée du bundle avec la signature debug de l'émulateur, mise à jour par adb install -r avec session conservée. Recette visuelle portrait sur Pixel_9_Pro / emulator-5554, véhicule Suzuki Horly : panneau ouvert sous la télémétrie, barre réduite à la même hauteur, fond Google Maps et icônes départ/arrivée visibles dans la zone inférieure. Pas d'essai sur téléphone physique ni de publication Google Play.

Bundle signé : D:/App/Codex/exad-tracking-mobile/build/app/outputs/bundle/release/EXAD-Tracking-1.0.0+43.aab
Taille : 47267963 octets ; SHA-256 : cb747df744dcc1be55d5db789f196cd97bfb21815f12e222e6942364811dbef6.
Notes françaises : build/app/outputs/bundle/release/EXAD-Tracking-1.0.0+43-notes-fr.txt.
Sources avant/après, journaux, reçu et captures : DASHCAM/analysis/mobile-history-top-20261008/. EXAD Tracking web/API et EXADCAM non modifiés ; aucun déploiement serveur dans ce lot.
