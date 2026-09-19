# Architecture de l’application

## Principes

Le projet suit une architecture Flutter volontairement simple : les écrans sont regroupés par fonctionnalité, tandis que l’accès réseau, la session, les modèles et le stockage sécurisé sont centralisés dans `lib/core`.

L’application n’accède jamais directement à la base de données ni au listener GPS. Toutes les données transitent par l’API privée versionnée sous `/api/v1/mobile`.

## Flux principal

```mermaid
flowchart LR
    UI[Écrans et widgets] --> Session[SessionController]
    Session --> API[ApiClient]
    Session --> Store[TokenStore]
    API --> Store
    API --> Backend[API Laravel /api/v1/mobile]
    Backend --> API
    Session --> Models[Modèles Dart]
    Models --> UI
```

| Couche | Responsabilité |
| --- | --- |
| `features` | Affichage, interactions et états propres à chaque écran |
| `SessionController` | Cycle d’authentification et données partagées de l’espace connecté |
| `ApiClient` | Requêtes HTTP, sérialisation, erreurs et renouvellement des jetons |
| `TokenStore` | Stockage sécurisé des jetons, de la session et de l’identifiant appareil |
| `models` | Conversion des réponses JSON en objets utilisés par l’interface |
| `localization` | Traductions FR/EN et préférence de langue |
| `theme` | Identité visuelle et personnalisation retournée par le serveur |

## Cycle de session

`SessionController` expose quatre étapes :

```mermaid
stateDiagram-v2
    [*] --> booting
    booting --> signedOut: aucune session ou session invalide
    booting --> signedIn: jetons valides et bootstrap chargé
    signedOut --> twoFactor: compte protégé par 2FA
    signedOut --> signedIn: connexion sans 2FA
    twoFactor --> signedIn: code validé
    twoFactor --> signedOut: annulation ou expiration
    signedIn --> signedOut: déconnexion ou session expirée
```

Au démarrage, les jetons sont lus depuis le stockage sécurisé. Si une session existe, l’application charge d’abord `/bootstrap`, puis le dashboard, les véhicules, les alertes et, si l’utilisateur possède `map_view`, les véhicules cartographiques.

## Authentification et renouvellement

1. La connexion transmet l’e-mail, le mot de passe, la plateforme et l’identifiant stable de l’appareil.
2. Si la 2FA est requise, aucun jeton d’accès n’est enregistré avant validation du challenge.
3. Après authentification, les jetons d’accès et de rafraîchissement sont stockés avec `flutter_secure_storage`.
4. Lorsqu’une ou plusieurs requêtes authentifiées reçoivent une erreur non autorisée, `ApiClient` partage une rotation unique avec le jeton de rafraîchissement.
5. La nouvelle paire remplace l’ancienne. Si la rotation échoue, les jetons locaux sont supprimés.

## Navigation et permissions

`HomeShell` construit dynamiquement la barre de navigation :

- dashboard client ou supervision superadmin ;
- carte, seulement avec la permission `map_view` ;
- profil et préférences.

La barre inférieure ne contient donc que « Carte », « Accueil » et « Plus » pour
un client autorisé à consulter la carte. Les véhicules et les alertes s’ouvrent
comme des pages secondaires depuis les indicateurs du dashboard, avec une action
de retour explicite.

Depuis les listes « Activité de la flotte », « Activité du parc » et « Véhicules », un appui ne charge pas une seconde liste ni une fiche de détails intermédiaire. `HomeShell` crée une demande de focus unique, active l’onglet Carte, puis `MapScreen` retrouve le véhicule dans le snapshot live, centre la caméra sur son marqueur et affiche sa fiche d’actions. Les détails, trajets et événements restent accessibles depuis cette fiche cartographique.

Les indicateurs des dashboards sont également des points de navigation : « Flottes » rejoint la répartition, « Véhicules » ouvre le parc complet, « En ligne » ouvre le parc avec son filtre actif, « À vérifier » ouvre les alertes et, sur le dashboard client, « En déplacement » ouvre la carte en vue générale.

La page « Alertes » conserve la valeur réelle des nouvelles alertes, permet de
les filtrer et les distingue par un badge « Nouveau », une bordure teintée et la
couleur de sévérité.

La visibilité d’un écran n’est pas une mesure de sécurité suffisante. Le serveur reste responsable de l’autorisation et du cloisonnement par flotte sur chaque endpoint.

L’espace Plus donne accès aux chauffeurs en lecture seule et aux départements. La gestion des départements est activée pour l’admin client et le superadmin, tandis que l’utilisateur normal conserve une vue sans action. Dans le détail d’un véhicule, les sorties du traceur n’apparaissent que lorsque le serveur confirme simultanément sa compatibilité et l’autorisation du compte. DOUT1 et DOUT2 sont affichées et commandées séparément ; une commande ne doit jamais modifier la sortie voisine.

## Carte et suivi direct

Le panneau Véhicules présente quatre compteurs avec icônes : en ligne, hors ligne, en mouvement et en parking (P encerclé). Les quatre indicateurs sont alignés sur une seule ligne, sans cartes, bordures ni fonds individuels, avec les libellés sous les icônes et les nombres. Ils remplacent le nom et l’adresse e-mail du compte et sont calculés sur le snapshot complet de la carte, indépendamment de la recherche et du filtre. L’actualisation manuelle reste disponible à côté de l’heure de mise à jour.

Chaque en-tête de flotte permet de replier ou développer ses véhicules et conserve le nombre de véhicules visible. Les groupes et leur état sont identifiés par l’ID de flotte et restent stables pendant les actualisations. Une nouvelle recherche développe les groupes pour révéler les résultats.

Les compteurs compacts utilisent quatre pictogrammes Material homogènes placés dans des médaillons circulaires discrets de 28 pixels : connexion verte, déconnexion rouge, direction violette et P bleu. Des séparateurs verticaux fins structurent le bandeau sans encadrer individuellement les statuts. Le nombre est mis en évidence et le libellé reste secondaire. La navigation inférieure reprend la couleur principale du thème, y compris la zone de navigation Android, avec des icônes et libellés contrastés selon la luminosité de cette couleur.

La navigation des écrans authentifiés s'exécute dans un navigateur imbriqué à l'intérieur de `HomeShell`. La barre inférieure reste ainsi visible sur les écrans racines comme sur les listes et détails ouverts depuis le tableau de bord ou le menu Plus. Sélectionner une destination depuis un sous-écran ferme d'abord la pile secondaire puis affiche la destination demandée. Les écrans de connexion et de double authentification restent volontairement hors de cette navigation.

Le menu Plus présente un espace `Gestion du parc` uniquement lorsque le bootstrap fournit les trois capacités `management.fleets`, `management.vehicles` et `management.trackers`. Le superadmin peut y consulter et créer des flottes, choisir un admin responsable disponible, créer des véhicules dans une flotte, puis créer et affecter un traceur à un véhicule encore libre.

Une entrée distincte `Gestion des utilisateurs` dépend de `management.users`. Le superadmin choisit le rôle, la flotte et les permissions des utilisateurs simples. L'admin client ne voit que les utilisateurs simples de sa propre flotte ; même si l'application est modifiée, le serveur force cette flotte et le rôle `user`. Les mots de passe respectent les mêmes exigences que le web et ne sont jamais retournés par l'API. Le serveur contrôle à nouveau le rôle sur chaque endpoint de gestion et demeure la source d'autorité.

La carte charge uniquement les véhicules possédant des coordonnées valides. Quand elle est active et que le suivi direct est activé :

- un snapshot est demandé toutes les 10 secondes ;
- un déplacement valide est interpolé pendant 5 secondes ;
- les états affichés distinguent mouvement, stationnement, moteur allumé à l’arrêt, maintenance, inactivité, hors ligne et en ligne ;
- les filtres et la recherche sont appliqués localement sur le snapshot courant ;
- l’ouverture de la fiche d’un véhicule suspend la superposition de la liste afin d’éviter les panneaux concurrents.

La position du téléphone n’est demandée qu’après action sur « Ma position ». Aucun suivi en arrière-plan n’est réalisé.

## Modèles et robustesse des réponses

Les conversions JSON sont concentrées dans `lib/core/models/app_models.dart`. Les helpers de conversion tolèrent les champs optionnels et les formes numériques courantes retournées par Laravel.

Lorsqu’un champ serveur devient obligatoire pour l’interface :

1. mettre à jour le Resource ou service Laravel ;
2. mettre à jour le modèle Dart ;
3. ajouter un test de parsing dans `test/models_test.dart` ;
4. adapter les tests de widgets concernés.

## Localisation

Les traductions FR/EN sont centralisées dans `AppLocalizations`. La préférence peut suivre le téléphone ou être forcée par l’utilisateur. Elle est conservée dans le stockage sécurisé sous la clé `exad_app_locale`.

Toute nouvelle chaîne visible doit être ajoutée dans les deux dictionnaires. Éviter les textes métier codés directement dans les widgets.

## Règles d’évolution

- Garder les appels HTTP hors des widgets ; passer par `SessionController` et `ApiClient`.
- Ne jamais journaliser les mots de passe, challenges 2FA ou jetons.
- Préserver le filtrage serveur même si un filtrage local existe pour l’ergonomie.
- Ajouter les états métier dans `VehicleData` avant de dupliquer leur interprétation dans plusieurs écrans.
- Tester les formats de réponse et les écrans critiques après toute évolution du contrat API.
