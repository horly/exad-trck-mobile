# Intégration avec l’API mobile

## Base et version

L’application consomme exclusivement l’API privée :

```text
https://exadtracking.app/api/v1/mobile
```

La valeur par défaut est définie dans `lib/core/config/app_config.dart`. Elle peut être remplacée à la compilation avec `--dart-define=API_BASE_URL=...`.

Le préfixe `/api/v1/mobile` fait partie de la base. Les chemins utilisés par `ApiClient` commencent donc directement par `/auth`, `/vehicles`, `/map`, etc.

## Endpoints consommés

| Méthode | Chemin | Utilisation mobile |
| --- | --- | --- |
| `POST` | `/auth/login` | Connexion et création d’une session appareil |
| `POST` | `/auth/two-factor` | Validation TOTP ou code de récupération |
| `POST` | `/auth/refresh` | Rotation des jetons |
| `POST` | `/auth/logout` | Révocation de la session courante |
| `GET` | `/bootstrap` | Profil, permissions et personnalisation |
| `GET` | `/dashboard` | Indicateurs, activité et alertes récentes |
| `GET` | `/vehicles?per_page=50` | Liste des véhicules visibles |
| `GET` | `/drivers?per_page=50` | Chauffeurs visibles en lecture seule, sans identifiant RFID/iButton |
| `GET` | `/departments?per_page=100` | Départements visibles et capacités de gestion |
| `POST` | `/departments` | Création pour admin client ou superadmin |
| `PUT` | `/departments/{id}` | Modification ou désactivation autorisée |
| `DELETE` | `/departments/{id}` | Suppression réservée au superadmin si aucun chauffeur n’est affecté |
| `GET` | `/vehicles/{id}/details` | Détail opérationnel d’un véhicule |
| `POST` | `/vehicles/{id}/engine-commands` | Activation ou désactivation sécurisée d’une sortie du traceur |
| `GET` | `/vehicles/{id}/trips?period=...` | Trajets et traces GeoJSON |
| `GET` | `/events?vehicle_id={id}&per_page=50` | Événements du véhicule |
| `GET` | `/alerts?per_page=50` | Alertes visibles |
| `GET` | `/map/vehicles` | Snapshot GeoJSON de la carte |

Le serveur reste la source de vérité pour les permissions, les véhicules visibles et le cloisonnement des flottes.

## En-têtes

Toutes les requêtes utilisent :

```http
Accept: application/json
Content-Type: application/json
```

Les routes protégées ajoutent :

```http
Authorization: Bearer <access_token>
```

La rotation utilise le jeton de rafraîchissement dans le même en-tête sur `/auth/refresh`.

## Connexion

La charge envoyée par le mobile contient :

```json
{
  "email": "utilisateur@entreprise.com",
  "password": "mot-de-passe",
  "device_identifier": "identifiant-stable-local",
  "device_name": "Android EXAD",
  "platform": "android",
  "app_version": "1.0.0+16"
}
```

`device_identifier` est généré avec une source aléatoire sécurisée, puis conservé dans `flutter_secure_storage`. Une réinstallation ou un effacement des données peut produire un nouvel identifiant.

`app_version` provient de `AppConfig.fullVersion`. Le script de génération APK synchronise sa valeur avec `pubspec.yaml` et incrémente le numéro de build après chaque génération réussie.

## Authentification à deux facteurs

Quand `two_factor_required` vaut `true`, la réponse ne contient pas encore de jetons utilisables. L’application conserve uniquement le `challenge_token` en mémoire et affiche l’écran de validation.

Le mobile transmet soit :

```json
{"challenge_token": "...", "code": "123456"}
```

soit :

```json
{"challenge_token": "...", "recovery_code": "code-de-recuperation"}
```

Le challenge n’est pas enregistré durablement.

## Rotation et expiration

`ApiClient` effectue au maximum une tentative de rafraîchissement après une réponse non autorisée. Les requêtes concurrentes partagent la même rotation (`single-flight`) et rejouent fidèlement leur méthode, leur corps et leurs paramètres :

1. lecture de la paire courante dans le stockage sécurisé ;
2. appel de `/auth/refresh` avec le refresh token ;
3. écriture de la nouvelle paire ;
4. répétition de la requête initiale avec le nouvel access token.

Si la rotation échoue, les jetons locaux sont supprimés. L’interface revient à la connexion lors de la prochaine mise à jour de session.

Le bootstrap est rechargé lors d’une actualisation de l’espace afin que les changements de permissions prennent effet sans nouvelle connexion. Une réponse `403 ACCOUNT_UNAVAILABLE` ferme également la session locale.

## Départements et sorties du traceur

Tous les comptes rattachés à une flotte consultent ses départements. L’admin client peut créer, modifier et désactiver ceux de sa flotte ; un `fleet_id` forgé est remplacé côté serveur. Le superadmin peut gérer toutes les flottes et supprimer uniquement un département sans chauffeur.

Le détail véhicule retourne `engine_control.outputs` avec deux états indépendants, indexés `1` et `2`. Chaque sortie fournit `number`, `active`, `busy` et `next_action`. La section est masquée quand le traceur est incompatible ou l’utilisateur non autorisé.

La commande mobile transmet explicitement la sortie ciblée :

```json
{
  "action": "immobilize",
  "output": 1,
  "confirmation": true
}
```

`immobilize` active uniquement la sortie indiquée après validation complète de l’arrêt. `release` désactive uniquement cette même sortie. Le serveur encode l’autre sortie avec `?` afin de ne modifier ni son état ni sa temporisation.

## Carte et positions

`/map/vehicles` retourne un objet GeoJSON. Chaque `feature` est convertie par `VehicleData.fromMapFeature`.

Les champs utilisés incluent notamment :

- identifiant, nom et immatriculation du véhicule ;
- latitude et longitude ;
- vitesse, cap et contact ;
- statut de communication ;
- états `is_moving`, `is_parking` et `is_stationary_running` ;
- statut GPS, pourcentage du signal réseau et pourcentage de batterie ;
- date du dernier signal ;
- trace récente pour l’animation du marqueur.

Le bandeau considère le GPS disponible lorsqu’une position valide accompagne un
traceur en ligne, même si le nombre de satellites est absent. Les niveaux réseau
et batterie restent explicitement indisponibles tant que l’API ne fournit pas de
pourcentage réel.

Lorsque le GPS du véhicule sélectionné est actif, le détail de télémétrie du
bandeau est rechargé toutes les 60 secondes. Une puissance réseau absente est
présentée comme `Connecté` si le traceur reste en ligne. Pour la batterie, le
pourcentage natif est prioritaire ; à défaut, un niveau indicatif est calculé
depuis la tension interne comprise entre 3,3 V et 4,2 V. En stationnement, la
quatrième mesure affiche la durée écoulée depuis `parking_started_at` plutôt que
la vitesse nulle, avec un `P` encerclé et un format compact tel que `2h30min`.

L’adresse affichée dans le détail doit correspondre aux coordonnées et au temps GPS sélectionnés par le serveur. Le client ne fabrique pas d’adresse et ne doit pas réutiliser l’adresse d’un autre véhicule.

## Trajets

Le client utilise actuellement :

- `today` ;
- `yesterday` ;
- `week` ;
- `current_month`.

Le serveur peut aussi accepter d’autres périodes, notamment personnalisées. Toute nouvelle valeur exposée dans l’interface doit être prise en charge simultanément par le serveur et les traductions mobiles.

## Format d’erreur

`ApiClient` accepte les deux formes principales :

```json
{
  "error": {
    "code": "MOBILE_SESSION_EXPIRED",
    "message": "La session a expiré."
  }
}
```

```json
{
  "message": "Les données sont invalides.",
  "errors": {
    "email": ["L’adresse e-mail est invalide."]
  }
}
```

Les erreurs de champ sont transformées en `fieldErrors`. Les délais réseau sont limités à 18 secondes.

Codes métier importants :

- `ACCOUNT_UNAVAILABLE` ;
- `INVALID_ACCESS_TOKEN` ;
- `MOBILE_SESSION_EXPIRED` ;
- `INVALID_REFRESH_TOKEN` ;
- `REFRESH_SESSION_EXPIRED`.

## Évolution du contrat

Pour toute évolution API :

1. documenter le changement dans le projet web ;
2. conserver la compatibilité de la version `/v1` ou versionner la rupture ;
3. mettre à jour les modèles Dart et leurs tests ;
4. vérifier les comptes client et superadmin ;
5. tester les réponses sans données optionnelles ;
6. ne jamais exposer l’IMEI ou des secrets techniques si l’écran n’en a pas besoin.
