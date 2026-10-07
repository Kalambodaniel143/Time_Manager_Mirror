# Backend du Time Manager — architecture et fonctionnement

*Oct 5, 2026 · @KALAMBO DANIEL*

Le backend du Time Manager est une API REST écrite en **Elixir** avec le framework **Phoenix**. Il stocke ses données dans **PostgreSQL** via **Ecto**. Il gère les comptes et leurs rôles, les équipes, les pointages (arrivée, pause, reprise, départ) et les temps de travail qui en découlent.

Ce document explique comment le code est organisé, ce que contient chaque fichier important, et ce qui se passe réellement quand une requête arrive. Le détail de chaque route (paramètres, réponses, exemples `curl`) est dans la [documentation de l'API](API.md) ; le déploiement est dans la [documentation DevOps](DEVOPS.md).

## Sommaire

1. [Vue d'ensemble](#1-vue-densemble)
2. [Les technologies et pourquoi](#2-les-technologies-et-pourquoi)
3. [L'arborescence du projet](#3-larborescence-du-projet)
4. [Le trajet d'une requête](#4-le-trajet-dune-requete)
5. [Le modèle de données](#5-le-modele-de-donnees)
6. [Les contextes métier, fichier par fichier](#6-les-contextes-metier-fichier-par-fichier)
7. [La couche web, fichier par fichier](#7-la-couche-web-fichier-par-fichier)
8. [L'authentification en détail](#8-lauthentification-en-detail)
9. [Les autorisations : rôle et périmètre](#9-les-autorisations-role-et-perimetre)
10. [Les pointages : la machine à états](#10-les-pointages-la-machine-a-etats)
11. [La gestion des erreurs](#11-la-gestion-des-erreurs)
12. [Configuration et variables d'environnement](#12-configuration-et-variables-denvironnement)
13. [Migrations et données de référence](#13-migrations-et-donnees-de-reference)
14. [Les tests](#14-les-tests)
15. [Lancer le backend](#15-lancer-le-backend)
16. [Ajouter une fonctionnalité : la marche à suivre](#16-ajouter-une-fonctionnalite-la-marche-a-suivre)
17. [Limites connues et pistes](#17-limites-connues-et-pistes)

---

## 1. Vue d'ensemble

Le backend ne sert aucune page HTML : il reçoit du JSON et renvoie du JSON. Le tableau de bord Vue.js (`time-manager-dashboard/`) est son unique client.

```
 Navigateur (Vue.js)                  Backend Phoenix                         PostgreSQL
 ───────────────────                  ───────────────                         ──────────
  cookie jwt (HttpOnly)  ───────▶  Endpoint ─▶ Router ─▶ Plug Authenticate
  en-tête X-CSRF-Token                                     │
                                                           ▼
                                              Contrôleur (couche web)
                                                │  1. lit les paramètres
                                                │  2. demande à Authorization
                                                │  3. appelle un contexte
                                                ▼
                                              Contexte (couche métier)  ───▶  Ecto ─▶ tables
                                                │
                                                ▼
                                              Vue JSON  ───▶  réponse { "data": ... }
```

Le code est découpé en **deux couches** qui ne se mélangent pas :

| Couche | Dossier | Rôle | Connaît HTTP ? |
|---|---|---|---|
| **Métier** | `lib/time_manager/` | Les règles : qui est un utilisateur, ce qu'est un pointage valide, quand créer une période de travail. Parle à la base. | Non |
| **Web** | `lib/time_manager_web/` | Traduire HTTP en appels métier : routes, authentification, contrôle d'accès, format JSON, codes HTTP. | Oui |

Cette séparation est la convention de Phoenix. Elle a une conséquence pratique : les règles métier se testent sans serveur HTTP (voir les tests de `test/time_manager/`), et un contrôleur ne contient jamais de requête SQL.

**Les quatre domaines** gérés par l'API :

- **Comptes** — utilisateurs, mot de passe, rôle (`employee`, `manager`, `administrator`).
- **Équipes** — un manager, des membres. Elles définissent ce qu'un manager a le droit de voir.
- **Pointages** (`clocks`) — les événements bruts : arrivée, pause, reprise, départ.
- **Temps de travail** (`workingtime`) — les périodes travaillées, avec un début et une fin. Elles sont créées automatiquement par les pointages, ou saisies et corrigées par un manager.

---

## 2. Les technologies et pourquoi

| Outil | Version | Rôle dans le projet |
|---|---|---|
| Elixir / OTP | 1.17 / 27 | Le langage. Fonctionnel, immuable : une fonction ne modifie jamais ses arguments, ce qui rend le flux des données facile à suivre. |
| Phoenix | 1.8 | Le framework web : endpoint, routeur, contrôleurs, vues JSON. |
| Bandit | 1.5+ | Le serveur HTTP qui exécute Phoenix. |
| Ecto / ecto_sql | 3.13+ | L'accès à la base : schémas, *changesets* (validation), requêtes, transactions, migrations. |
| Postgrex | — | Le pilote PostgreSQL utilisé par Ecto. |
| PostgreSQL | 16 | La base de données. Elle porte aussi des contraintes (clés étrangères, `CHECK`, index uniques) qui protègent les données même si le code se trompe. |
| Joken | 2.6+ | Signature et vérification des JWT de session (HS256). |
| bcrypt_elixir | 3.3+ | Hachage des mots de passe. |
| OpenApiSpex | 3.21+ | Description OpenAPI de chaque route, servie en JSON et dans Swagger UI. |
| Jason | 1.2+ | Encodage et décodage JSON. |

Swoosh, LiveDashboard, Gettext et DNSCluster viennent du générateur Phoenix ; ils sont présents mais ne jouent pas de rôle dans le métier.

---

## 3. L'arborescence du projet

Seuls les fichiers qui comptent sont listés. Tout se trouve dans `time_manager/`.

```
time_manager/
├── mix.exs                         Projet, dépendances, alias (setup, test, precommit)
├── Dockerfile, entrypoint.sh       Image Docker et script de démarrage du conteneur
├── config/
│   ├── config.exs                  Configuration commune (endpoint, JSON, logger)
│   ├── dev.exs / test.exs / prod.exs   Réglages par environnement
│   └── runtime.exs                 Lu au démarrage : secrets et variables d'environnement
├── lib/
│   ├── time_manager/               ── COUCHE MÉTIER ──
│   │   ├── application.ex          Arbre de supervision : ce qui démarre avec l'application
│   │   ├── repo.ex                 Le dépôt Ecto (la connexion à PostgreSQL)
│   │   ├── accounts.ex             Contexte Comptes : utilisateurs, mot de passe, rôles
│   │   ├── accounts/user.ex        Schéma users + validations
│   │   ├── accounts/role.ex        Schéma roles (lecture seule)
│   │   ├── authorization.ex        La matrice des permissions (rôle × périmètre)
│   │   ├── token.ex                Création du JWT de session et du token CSRF
│   │   ├── teams.ex                Contexte Équipes
│   │   ├── teams/team.ex           Schéma teams
│   │   ├── clocks.ex               Contexte Pointages : machine à états, transaction, verrou
│   │   ├── clocks/clock.ex         Schéma clocks
│   │   ├── working_times.ex        Contexte Temps de travail
│   │   └── working_times/working_time.ex   Schéma workingtime
│   └── time_manager_web/           ── COUCHE WEB ──
│       ├── endpoint.ex             Premier point d'entrée HTTP : chaîne de plugs
│       ├── router.ex               Table des routes et pipelines
│       ├── plugs/authenticate.ex   Vérifie cookie + CSRF, charge l'utilisateur
│       ├── api_spec.ex             Racine de la spécification OpenAPI
│       ├── controllers/
│       │   ├── authz.ex            Petites aides partagées : current_user, authorize, cast_id
│       │   ├── auth_controller.ex  Connexion, inscription, session, déconnexion
│       │   ├── user_controller.ex, team_controller.ex, role_controller.ex
│       │   ├── clock_controller.ex, working_time_controller.ex
│       │   ├── *_json.ex           Vues : transforment les structures en JSON
│       │   ├── fallback_controller.ex  Transforme {:error, ...} en réponse HTTP
│       │   └── changeset_json.ex, error_json.ex   Format des erreurs
│       └── schemas/                Schémas OpenAPI des requêtes et réponses
├── priv/repo/
│   ├── migrations/                 Historique des changements de structure de la base
│   └── seeds.exs                   Rôles + premier administrateur
└── test/
    ├── support/                    ConnCase, DataCase, fixtures (utilisateurs, équipes)
    ├── time_manager/               Tests de la couche métier
    └── time_manager_web/           Tests HTTP des contrôleurs
```

**Le vocabulaire Phoenix utilisé dans ce document :**

- **Plug** — une fonction qui reçoit la connexion (`conn`) et la renvoie modifiée. Une requête traverse une chaîne de plugs. Un plug peut l'arrêter (`halt`), par exemple pour répondre 401.
- **Contexte** — un module métier qui regroupe tout ce qui concerne un domaine (`Accounts`, `Clocks`…). C'est la seule porte d'entrée vers ses tables.
- **Schéma** — la correspondance entre une table et une structure Elixir (`%User{}`).
- **Changeset** — la description d'une modification : quels champs changent, sont-ils valides, quelles erreurs. Rien n'est écrit en base tant qu'un changeset n'est pas valide.
- **`with`** — la forme Elixir pour enchaîner des étapes qui peuvent échouer. Dès qu'une étape ne renvoie pas le motif attendu (`{:ok, ...}` ou `:ok`), le `with` s'arrête et renvoie l'erreur telle quelle.

---

## 4. Le trajet d'une requête

Prenons une vraie requête : un employé connecté pointe son arrivée.

```
POST /api/clocks/42
Cookie: jwt=eyJhbGciOi...
X-CSRF-Token: 3vQb9...
Content-Type: application/json

{ "clock": { "time": "2026-10-05 09:00:00", "status": true } }
```

**Étape 1 — `TimeManagerWeb.Endpoint`** (`endpoint.ex`). Chaque requête traverse dans l'ordre : `Plug.RequestId` (un identifiant pour les logs), `Plug.Telemetry` (mesures), `Plug.Parsers` (le corps JSON devient une map Elixir), `Plug.MethodOverride`, `Plug.Head`, `Plug.Session`, puis le routeur.

**Étape 2 — `TimeManagerWeb.Router`** (`router.ex`). Le chemin `/api/clocks/:userID` est déclaré dans le scope `/api` qui traverse deux pipelines :

- `:api` — n'accepte que le JSON et attache la spec OpenAPI à la connexion ;
- `:auth` — exécute le plug `Authenticate`.

**Étape 3 — `TimeManagerWeb.Plugs.Authenticate`**. Il lit le cookie `jwt` et l'en-tête `X-CSRF-Token`, vérifie la signature et l'expiration du JWT, compare le token CSRF à celui gravé dans le JWT, puis **recharge l'utilisateur depuis la base**. Si une seule étape échoue, la requête s'arrête ici avec **401**. Sinon, l'utilisateur est rangé dans `conn.assigns.current_user`. Le détail est en [section 8](#8-lauthentification-en-detail).

**Étape 4 — `ClockController.create/2`**.

```elixir
def create(conn, %{"clock" => attrs}) when is_map(attrs) do
  with {:ok, user_id} <- cast_id(conn.path_params["userID"]),                     # "42" -> 42
       :ok <- authorize(Authorization.can_clock?(current_user(conn), user_id)),   # 403 sinon
       {:ok, user} <- fetch_user(user_id),                                        # 404 sinon
       {:ok, clock} <- Clocks.create_clock(user, attrs) do                        # 422 sinon
    conn |> put_status(:created) |> render(:show, clock: clock)
  end
end
```

Chaque ligne du `with` correspond à un code d'erreur possible. L'ordre compte : le droit d'accès est vérifié **avant** de charger l'utilisateur ciblé, pour ne pas révéler par un 404 si un compte existe.

**Étape 5 — `Clocks.create_clock/2`** (couche métier). Elle valide le pointage, ouvre une transaction, verrouille la ligne de l'utilisateur, vérifie que l'arrivée est permise après le dernier pointage, l'insère, et crée une période de travail s'il s'agit d'une fin de segment. Voir la [section 10](#10-les-pointages-la-machine-a-etats).

**Étape 6 — `ClockJSON.show/1`**. La structure `%Clock{}` devient :

```json
{ "data": { "id": 7, "time": "2026-10-05T09:00:00Z", "status": true, "kind": "arrival", "user_id": 42 } }
```

**Étape 7 — en cas d'erreur.** Si une étape du `with` renvoie `{:error, quelque_chose}`, Phoenix passe ce résultat au `FallbackController` déclaré par `action_fallback`, qui choisit le code HTTP (voir la [section 11](#11-la-gestion-des-erreurs)).

---

## 5. Le modèle de données

```
┌──────────────┐        ┌───────────────────────┐        ┌───────────────────────┐
│    roles     │        │         users         │        │        clocks         │
├──────────────┤        ├───────────────────────┤        ├───────────────────────┤
│ id           │◀──┐    │ id                    │◀──┬────│ user_id  (CASCADE)    │
│ name UNIQUE  │   └────│ role_id  (RESTRICT)   │   │    │ time      utc         │
└──────────────┘        │ username              │   │    │ status    bool        │
                        │ email    UNIQUE lower │   │    │ kind      arrival|... │
                        │ password_hash         │   │    └───────────────────────┘
                        └───────────────────────┘   │
                          ▲          ▲              │    ┌───────────────────────┐
                          │          │              │    │      workingtime      │
           manager_id     │          │ user_id      │    ├───────────────────────┤
           (NULLIFY)      │          │ (CASCADE)    └────│ user_id  (CASCADE)    │
┌──────────────────┐      │   ┌──────────────────┐       │ start     utc         │
│      teams       │──────┘   │   team_members   │       │ end       utc         │
├──────────────────┤          ├──────────────────┤       │ CHECK end > start     │
│ id               │◀─────────│ team_id (CASCADE)│       └───────────────────────┘
│ name UNIQUE      │          │ user_id (CASCADE)│
└──────────────────┘          │ UNIQUE(team,user)│
                              └──────────────────┘
```

### Les tables

| Table | Contenu | Contraintes importantes |
|---|---|---|
| `roles` | Les trois rôles : `employee`, `manager`, `administrator`. | `name` unique. Insérés par la migration et par les seeds ; aucune route ne les modifie. |
| `users` | Le compte : `username`, `email`, `password_hash`, `role_id`. | Index unique sur `lower(email)` : un e-mail = un compte, sans tenir compte de la casse. `role_id` obligatoire, `ON DELETE RESTRICT` (impossible de supprimer un rôle utilisé). Le mot de passe en clair n'est **jamais** stocké. |
| `teams` | Une équipe et son manager. | `name` unique. `manager_id` passe à `NULL` si le manager est supprimé : l'équipe survit. |
| `team_members` | Table de jointure équipe ↔ membre. | Couple `(team_id, user_id)` unique. Suppression en cascade des deux côtés. |
| `clocks` | Les événements de pointage bruts. | `kind` obligatoire ; contrainte `clocks_kind_matches_status` : `status = true` ⇔ `kind ∈ {arrival, resume}`. Supprimés avec l'utilisateur. |
| `workingtime` | Les périodes travaillées. | `CHECK ("end" > start)` : une période a toujours une durée positive. Supprimées avec l'utilisateur. |

### Pourquoi deux tables pour le temps ?

`clocks` et `workingtime` ne stockent pas la même chose :

- un **pointage** est un *instant* : « Alice est arrivée à 9 h ». Il n'a pas de durée ;
- une **période** est un *intervalle* : « Alice a travaillé de 9 h à 12 h ». C'est ce qu'on additionne pour les totaux et les graphiques.

Le backend fabrique les périodes à partir des pointages : quand un segment de travail se ferme (pause ou départ), il crée la période correspondante **dans la même transaction**. Les deux tables restent ainsi toujours cohérentes. Un manager peut aussi créer ou corriger une période à la main, sans pointage (oubli, erreur de saisie).

### Les dates

Toutes les dates sont en **UTC** (`:utc_datetime`, précision à la seconde). L'API accepte `"2026-10-05 09:00:00"` ou le format ISO 8601 (`"2026-10-05T11:00:00+02:00"`, converti en UTC) et renvoie de l'ISO 8601 en UTC. La conversion vers l'heure locale est l'affaire du front-end. Stocker en UTC évite les erreurs aux changements d'heure : une journée du 29 mars dure bien 8 h, pas 7.

---

## 6. Les contextes métier, fichier par fichier

### 6.1 `application.ex` — ce qui démarre

Au lancement, l'application démarre un **superviseur** qui lance, dans l'ordre : la télémétrie, le dépôt Ecto (`Repo`, le pool de connexions à PostgreSQL), DNSCluster, PubSub, puis l'`Endpoint` HTTP. La stratégie `:one_for_one` signifie que si un de ces processus plante, seul celui-là est redémarré. C'est le principe OTP « *let it crash* » : on ne protège pas chaque ligne contre les pannes, un superviseur remet le système dans un état sain.

### 6.2 `accounts.ex`, `accounts/user.ex`, `accounts/role.ex` — les comptes

**`User`** définit **quatre changesets** distincts, et c'est un choix de sécurité :

| Changeset | Champs acceptés | Utilisé pour |
|---|---|---|
| `changeset/2` | `username`, `email` | Modifier son profil |
| `registration_changeset/3` | profil + `password` ; le rôle est imposé par le code | Créer un compte |
| `password_changeset/2` | `password` | Changer ou réinitialiser le mot de passe |
| `role_changeset/2` | `role_id` | Promouvoir ou rétrograder |

Comme le formulaire de profil ne passe que par `changeset/2`, un client qui ajoute `"role": "administrator"` à sa requête ne change rien : le champ n'est même pas lu. C'est la protection contre l'**assignation de masse** (*mass assignment*).

Validations appliquées :

- e-mail mis en minuscules, au format `x@x.x`, 160 caractères au plus, unique ;
- mot de passe de 8 à 72 caractères. 72 est la limite de bcrypt : au-delà, les octets sont ignorés ;
- le mot de passe est remplacé par son hachage bcrypt (`hash_password/1`) puis **retiré** du changeset. Les champs `password` et `password_hash` sont marqués `redact: true` : ils n'apparaissent jamais dans les logs ni dans `inspect`.

`valid_password?/2` compare un mot de passe au hachage en **temps constant**. Si l'utilisateur n'existe pas, elle appelle quand même `Bcrypt.no_user_verify()`, qui prend le même temps : un attaquant ne peut pas deviner quels e-mails existent en mesurant le temps de réponse.

**`Accounts`** expose les opérations sur les comptes :

| Fonction | Ce qu'elle fait |
|---|---|
| `list_users/2` | Liste filtrable par `email` et `username`, restreinte à une liste d'ids (le périmètre de l'appelant) ou `:all`. |
| `fetch_user/1` | Renvoie `{:ok, user}` ou `{:error, :not_found}`, y compris pour un id mal formé. Le rôle est toujours préchargé. |
| `authenticate/2` | Vérifie le couple e-mail / mot de passe. Même réponse et même durée pour « e-mail inconnu » et « mauvais mot de passe ». |
| `create_user/2` | Crée un compte avec un rôle (`employee` par défaut). |
| `update_account/3` | Met à jour le profil **et** le mot de passe dans une seule transaction : les deux réussissent ou aucun. |
| `change_password/3` | Changement par l'utilisateur lui-même : exige le mot de passe actuel. Une session volée ne suffit pas à prendre le compte. |
| `reset_password/2` | Réinitialisation par un administrateur, sans l'ancien mot de passe. |
| `change_role/2`, `delete_user/1` | Refusent de rétrograder ou de supprimer le **dernier administrateur** (`{:error, :last_administrator}` → 409). L'application garde toujours quelqu'un capable de l'administrer. |

**`Role`** est en lecture seule. `Role.names/0` donne l'ordre du moins au plus privilégié ; `list_roles/0` l'utilise pour trier.

### 6.3 `authorization.ex` — qui peut faire quoi

C'est **le seul endroit** où sont écrites les règles d'accès. Chaque contrôleur l'interroge avant d'agir. Détail en [section 9](#9-les-autorisations-role-et-perimetre).

### 6.4 `token.ex` — le JWT de session

Utilise `Joken.Config`. Le token contient :

| Claim | Valeur |
|---|---|
| `user_id` | L'id de l'utilisateur |
| `role` | Son rôle au moment de la connexion (informatif : le serveur ne s'en sert pas pour décider) |
| `xsrf` | Le token CSRF de cette session |
| `exp` | Expiration : 8 heures |
| `iss`, `aud` | `"time_manager"` : un JWT émis pour une autre application est refusé |

`generate_csrf_token/0` produit 32 octets aléatoires cryptographiquement sûrs (`:crypto.strong_rand_bytes`), encodés en Base64 URL.

Un JWT est **signé, pas chiffré** : n'importe qui peut lire son contenu en le décodant. Il ne contient donc rien de confidentiel. La signature garantit seulement qu'il n'a pas été modifié.

### 6.5 `teams.ex`, `teams/team.ex` — les équipes

Une équipe a **au plus un manager** (`manager_id`) et **des membres** (`team_members`). Un employé peut appartenir à plusieurs équipes.

| Fonction | Rôle |
|---|---|
| `list_teams/0`, `list_managed_teams/1`, `list_member_teams/1` | Lister toutes les équipes, celles que l'on manage, celles dont on est membre. |
| `create_team/1`, `update_team/2` | Vérifient que le manager désigné existe et a le rôle `manager` ou `administrator`. |
| `add_member/2` | Idempotent (`on_conflict: :nothing`) : ajouter deux fois le même membre ne provoque pas d'erreur. |
| `manages?/2` | `true` si l'utilisateur appartient à une équipe dirigée par ce manager. C'est la base du périmètre « mes équipes ». |
| `managed_member_ids/1` | Les ids de tous les membres des équipes d'un manager. |

Composer les équipes est réservé à l'administrateur. Si un manager pouvait ajouter des personnes à son équipe, il s'ouvrirait lui-même l'accès à leurs heures.

### 6.6 `clocks.ex`, `clocks/clock.ex` — les pointages

Le module le plus subtil du backend, détaillé en [section 10](#10-les-pointages-la-machine-a-etats). En bref :

- `Clock.changeset/2` complète `kind` à partir de `status` quand le client ne l'envoie pas (`true` → `arrival`, `false` → `departure`), pour rester compatible avec les anciens clients. Il vérifie aussi que `kind` et `status` concordent ;
- `Clocks.create_clock/2` enregistre un pointage ;
- `Clocks.complete_clock/3` enregistre un départ oublié, après coup ;
- `Clocks.list_clocks/1` renvoie l'historique, du plus ancien au plus récent.

### 6.7 `working_times.ex`, `working_times/working_time.ex` — les périodes

| Fonction | Rôle |
|---|---|
| `list_working_times/2` | Périodes d'un utilisateur, filtrables par `start` (début ≥) et `end` (fin ≤). Un filtre de date mal formé renvoie `{:error, :bad_request}`. |
| `get_working_time/2` | Cherche une période **et** vérifie qu'elle appartient à l'utilisateur de l'URL. |
| `get_working_time/1` | Cherche une période par son seul id (utilisé pour la modifier ou la supprimer). |
| `create_working_time/2`, `update_working_time/2`, `delete_working_time/1` | Écriture. Le changeset refuse une fin qui ne suit pas le début ; la contrainte `CHECK` de la base le refuse aussi. |

Le propriétaire d'une période vient toujours du code (`%WorkingTime{user_id: user_id}`) et jamais du corps de la requête : `user_id` n'est pas dans la liste des champs que le changeset accepte.

### 6.8 `organizations.ex`, `organizations/*.ex` — organisations et demandes d'adhésion

Ce contexte implémente [CONTRAT_BACKEND_ORGANISATIONS.md](CONTRAT_BACKEND_ORGANISATIONS.md). Les règles de validation du profil (prénom, nom, e-mail, genre, date et lieu de naissance) sont dans `accounts/profile.ex`, partagées par `User` et `JoinRequest`.

| Fonction | Rôle |
|---|---|
| `create_organization/3` | Valide l'organisation et son administrateur ensemble (toutes les erreurs d'un coup), puis les insère dans une transaction. Nom ou e-mail déjà pris : `409`. |
| `lookup_organization/1` | Cherche le nom normalisé exact (casse, accents et espaces successifs ignorés, comme `normalizeName` côté front). |
| `submit_join_request/2` | Enregistre une demande `pending` sans compte ni mot de passe. Renvoie une référence aléatoire dont seule l'empreinte SHA-256 est stockée. |
| `approve_join_request/4` | Verrouille la demande (`FOR UPDATE`), vérifie qu'elle est `pending`, crée l'employé et marque la demande, dans une transaction : deux acceptations simultanées ne créent qu'un compte. |
| `reject_join_request/4` | Même verrou ; motif de 1 à 500 caractères, erreurs rapportées sur le champ `reason`. |
| `set_member_role/3` | `employee` ou `manager` uniquement, jamais sur un administrateur. |

Une demande en attente est unique par organisation et par e-mail grâce à un index unique partiel (`WHERE status = 'pending'`). Une demande refusée n'empêche donc pas d'en déposer une nouvelle.

---

## 7. La couche web, fichier par fichier

### 7.1 `router.ex`

```elixir
pipeline :api  do plug :accepts, ["json"]; plug OpenApiSpex.Plug.PutApiSpec, ... end
pipeline :auth do plug TimeManagerWeb.Plugs.Authenticate end

scope "/api/auth"  → pipe_through :api           # public : login, register
scope "/api"       → pipe_through [:api, :auth]  # tout le reste : session obligatoire
scope "/api"       → /openapi                    # la spec, publique
scope "/"          → /swaggerui                  # l'interface de test
```

Il n'existe que **deux** routes publiques : `POST /api/auth/login` et `POST /api/auth/register`. Toute nouvelle route ajoutée au second scope est protégée d'office : l'oubli n'est pas possible.

### 7.2 Les contrôleurs

Tous les contrôleurs suivent le même modèle :

1. `use OpenApiSpex.ControllerSpecs` et une macro `operation(...)` au-dessus de chaque action. Elle décrit la route pour Swagger et n'a aucun effet sur l'exécution.
2. `action_fallback TimeManagerWeb.FallbackController` pour convertir les erreurs.
3. Un `with` qui enchaîne : convertir l'id → vérifier le droit → charger → agir → répondre.
4. Une clause de repli `def action(_conn, _params), do: {:error, :bad_request}` quand le corps n'a pas la forme attendue (par exemple, pas de clé `"clock"`).

| Contrôleur | Actions | Particularités |
|---|---|---|
| `AuthController` | `login`, `register`, `me`, `logout` | Pose et supprime le cookie. `register` ne garde que `username`, `email` et `password` : un `role` envoyé est ignoré, et le compte est toujours `employee`. |
| `UserController` | `index`, `create`, `show`, `update`, `update_role`, `delete` | `index` renvoie le périmètre de l'appelant (403 pour un employé). `update` distingue le changement de son propre mot de passe (ancien mot de passe requis) de la réinitialisation par un administrateur. `update_role` est interdit sur soi-même. |
| `TeamController` | CRUD + `add_member`, `remove_member` | Un employé voit le nom de ses équipes mais pas la liste des autres membres. |
| `RoleController` | `index` | Lecture seule. |
| `ClockController` | `index`, `create`, `complete` | On ne pointe **que pour soi**, même un administrateur. |
| `WorkingTimeController` | `index`, `show`, `create`, `update`, `delete` | Pour `update` et `delete`, l'URL ne contient que l'id de la période : le contrôleur la charge d'abord pour savoir à qui elle appartient, puis vérifie le droit sur ce propriétaire. |

### 7.3 `authz.ex` — les aides partagées

```elixir
current_user(conn)    # l'utilisateur posé par le plug Authenticate
authorize(true)  -> :ok
authorize(false) -> {:error, :forbidden}       # devient 403
cast_id("42")    -> {:ok, 42}
cast_id("abc")   -> {:error, :not_found}       # devient 404
```

Les paramètres d'URL sont des chaînes de caractères. Sans `cast_id`, la comparaison `"42" == 42` serait fausse, et une règle comme « on peut voir son propre profil » refuserait à tort.

### 7.4 Les vues JSON (`*_json.ex`)

Elles choisissent **explicitement** les champs exposés. `UserJSON.data/1` renvoie `id`, `username`, `email`, `role` et `inserted_at`. Le hachage du mot de passe n'y figure pas, et un champ ajouté plus tard au schéma ne sera jamais exposé par accident. Toutes les réponses de succès sont enveloppées dans `{ "data": ... }`.

### 7.5 `schemas/` — la spécification OpenAPI

Un module par forme de requête ou de réponse (`ClockRequest`, `UserResponse`, `ValidationErrorResponse`…). `api_spec.ex` les rassemble, lit les routes du routeur et déclare les deux mécanismes de sécurité (`jwtCookie` et `csrfToken`). Le test `api_spec_test.exs` vérifie que la spec se construit sans erreur.

---

## 8. L'authentification en détail

### 8.1 Le principe : cookie HttpOnly + token CSRF

Le backend combine deux secrets, chacun bloquant une attaque différente :

| Secret | Où il vit | Qui l'envoie | Ce qu'il bloque |
|---|---|---|---|
| **JWT** | Cookie `jwt`, `HttpOnly`, `SameSite=Strict` | Le navigateur, automatiquement | **XSS** : un script injecté dans la page ne peut pas lire un cookie `HttpOnly`, donc ne peut pas voler la session. |
| **Token CSRF** | Mémoire du front-end, et une copie signée dans le JWT (`xsrf`) | Le front-end, dans l'en-tête `X-CSRF-Token` | **CSRF** : un site tiers peut pousser le navigateur à envoyer le cookie, mais il ne connaît pas le token et ne peut pas poser cet en-tête. |

Une requête n'est acceptée que si **les deux** sont présents et correspondent.

### 8.2 La connexion, pas à pas

```
Front-end                                   Backend
────────                                    ───────
POST /api/auth/login
{ email, password }      ─────────────▶   Accounts.authenticate/2
                                            ├─ cherche l'e-mail (en minuscules)
                                            └─ Argon2id, temps constant
                                          csrf = 32 octets aléatoires
                                          jwt  = signe { user_id, role, xsrf: csrf, jti, exp: +8 h }
                         ◀─────────────   Set-Cookie: jwt=...; HttpOnly; SameSite=Strict; Max-Age=28800
                                          200 { data: { csrf_token, role, user, organization } }
garde csrf_token en mémoire
```

L'inscription (`register`) et la création d'une organisation (`POST /api/organizations`) suivent le même chemin après avoir créé le compte, et répondent **201**. Un hash bcrypt antérieur au passage à Argon2id est vérifié avec bcrypt puis remplacé par un hash Argon2id, puisque le mot de passe est alors connu.

### 8.3 Chaque requête protégée

Le plug `Authenticate` exécute ces vérifications dans l'ordre ; la moindre erreur donne **401** :

1. le cookie `jwt` est présent ;
2. l'en-tête `X-CSRF-Token` est présent ;
3. la signature HS256 est valide, le token n'est pas expiré, `iss` et `aud` sont corrects (`Token.verify_and_validate/1`) ;
4. le claim `xsrf` est égal à l'en-tête, comparé en temps constant (`Plug.Crypto.secure_compare`) ;
5. le `jti` du JWT ne figure pas dans `revoked_tokens` (session fermée par une déconnexion) ;
6. l'utilisateur `user_id` existe **encore** en base. Il est rechargé avec son rôle.

Le point 6 est important : le rôle utilisé pour les autorisations est **celui de la base**, pas celui du token. Rétrograder un manager ou supprimer un compte prend effet dès la requête suivante, sans attendre l'expiration du JWT.

### 8.4 La déconnexion

`POST /api/auth/logout` inscrit le `jti` du JWT dans la table `revoked_tokens` jusqu'à son expiration, puis demande au navigateur de supprimer le cookie (mêmes options que lors de sa création, sinon le navigateur ne le reconnaît pas) et répond **204**. Un JWT copié avant la déconnexion est donc refusé. Les entrées expirées sont purgées à chaque déconnexion.

### 8.6 Les protections des routes publiques

Les routes publiques (connexion, inscription, organisations, demandes d'adhésion) n'ont pas encore de token CSRF. Deux plugs les protègent :

- `Plugs.CheckOrigin` (pipeline `:api`) refuse en **403** une requête d'écriture dont l'`Origin` ou le `Referer` désigne un autre hôte que celui de l'API ;
- `Plugs.RateLimit` (déclaré dans chaque contrôleur) répond **429** au-delà d'un seuil par minute, par adresse IP ou, pour la connexion, aussi par e-mail. Les compteurs vivent dans une table ETS tenue par `TimeManagerWeb.RateLimiter`. La configuration de test le désactive (`config :time_manager, :rate_limit, false`).

### 8.5 Les options du cookie

| Option | Valeur | Raison |
|---|---|---|
| `http_only` | `true` | Illisible en JavaScript. |
| `same_site` | `"Strict"` | Jamais envoyé avec une requête initiée par un autre site. |
| `secure` | `COOKIE_SECURE` | Uniquement en HTTPS quand la variable vaut `true`. À activer dès que le site est servi en HTTPS : les navigateurs ignorent un cookie `Secure` reçu en HTTP. |
| `max_age` | 8 h | Même durée que le JWT. |
| `path` | `/` | Valable pour toute l'API. |

---

## 9. Les autorisations : rôle et périmètre

Toute permission combine deux questions :

- **le rôle** — quel type d'action l'appelant peut-il faire ?
- **le périmètre** — sur les données de qui ?

| Rôle | Périmètre |
|---|---|
| `employee` | Lui-même |
| `manager` | Lui-même + les membres des équipes qu'il dirige |
| `administrator` | Son organisation |

Les organisations sont étanches : aucun rôle n'atteint les données d'une autre. Les comptes sans organisation forment un espace à part : pour toutes les vérifications, « même organisation » inclut « tous deux sans organisation ».

### Les fonctions de `Authorization`

| Fonction | Vrai quand… | Utilisée par |
|---|---|---|
| `can_view?(user, target_id)` | c'est soi-même, ou l'appelant administre l'organisation de la cible, ou il manage la cible | Lire un profil, des pointages, des périodes |
| `can_edit_hours?(user, target_id)` | administrateur de l'organisation de la cible ; ou manager de la cible **et** la cible n'est pas lui-même | Créer, corriger, supprimer une période |
| `can_clock?(user, target_id)` | c'est soi-même, quel que soit le rôle | Pointer, compléter un départ |
| `can_edit_profile?(user, target_id)` | soi-même, ou administrateur de l'organisation de la cible | Modifier un profil |
| `can_change_role?(user, target_id)` | administrateur de l'organisation de la cible, jamais sur soi-même | Changer un rôle |
| `administrator_of?(user, target_id)` | administrateur de l'organisation de la cible | Supprimer un compte |
| `administrator_of_team?(user, team)` | administrateur de l'organisation de l'équipe | Gérer une équipe |
| `organization_admin?(user, org_id)` | administrateur de l'organisation `org_id` (celle de l'URL) | Routes `/api/organizations/:org_id/…` |
| `can_see_personal_details?(viewer, user)` | soi-même, ou administrateur de l'organisation de `user` | Afficher genre, date et lieu de naissance |
| `user_scope(user)` | `{:organization, id}` (admin), liste d'ids (manager), `:forbidden` (employé) | Lister les utilisateurs |

Deux règles méritent d'être expliquées :

- **Un manager ne corrige pas ses propres heures.** Personne ne valide son propre travail : ce sont l'administrateur ou son propre manager qui le font.
- **Personne ne pointe pour quelqu'un d'autre.** Un pointage atteste qu'une personne est présente : le faire à sa place serait une fraude, même pour un administrateur. Les oublis se rattrapent par une correction de période (tracée) ou, pour un départ oublié, par l'employé lui-même via `complete`.

### Où est faite la vérification

Le front-end masque les boutons interdits, pour le confort de l'utilisateur. **La seule vraie barrière est l'API** : chaque action de contrôleur appelle `Authorization` avant d'agir. Un utilisateur qui forge ses requêtes à la main (curl, console du navigateur) se heurte au même 403.

La matrice complète route par route est dans [API.md, section 3](API.md#3-roles-et-permissions).

---

## 10. Les pointages : la machine à états

### 10.1 Les quatre événements

| `kind` | `status` | Sens |
|---|---|---|
| `arrival` | `true` | Début du service |
| `pause` | `false` | Début d'une pause : le segment de travail se ferme |
| `resume` | `true` | Fin de la pause : un nouveau segment s'ouvre |
| `departure` | `false` | Fin du service |

`status` indique « est-on en train de travailler après cet événement ? ». La contrainte `clocks_kind_matches_status` impose en base que les deux concordent.

### 10.2 Les transitions autorisées

```
                  ┌──────────────────────────────┐
                  ▼                              │
  (aucun) ──▶ arrival ──▶ pause ──▶ resume ──┐   │
                │           │         │      │   │
                │           │         └──────┘   │  (pause et resume peuvent alterner)
                │           │                    │
                ▼           ▼                    │
             departure ◀────┴────────────────────┘
                │
                └──▶ arrival (service suivant)
```

Dans le code, c'est une simple table :

```elixir
@next_kinds %{
  nil        => [:arrival],
  :arrival   => [:pause, :departure],
  :resume    => [:pause, :departure],
  :pause     => [:resume, :departure],
  :departure => [:arrival]
}
```

Tout autre enchaînement (deux arrivées de suite, une reprise sans pause…) est refusé avec **422** : `"action is not allowed after the latest clock event"`. Un pointage ne peut pas non plus être **antérieur** au précédent : `"must not precede the latest clock event"`.

### 10.3 La création automatique des périodes

Quand un événement ferme un segment de travail, `create_period/2` crée la période correspondante :

| Précédent | Nouveau | Période créée ? |
|---|---|---|
| `arrival` ou `resume` | `pause` ou `departure` | Oui : de l'heure du précédent à celle du nouveau |
| `pause` | `departure` | Non : on part pendant la pause, il n'y a pas de travail entre les deux |
| n'importe lequel | `arrival` ou `resume` | Non : la fin n'est pas encore connue |

Exemple : arrivée 9 h, pause 10 h, reprise 10 h 30, départ 12 h → **deux** périodes, 9 h–10 h et 10 h 30–12 h. La pause n'entre jamais dans le total.

### 10.4 Transaction et verrou : pourquoi c'est nécessaire

Voici `record_clock/3`, le cœur du module, résumé :

```elixir
Repo.transact(fn ->
  # 1. Verrouille la ligne users de cet utilisateur (SELECT ... FOR UPDATE)
  Repo.one(from u in User, where: u.id == ^user_id, lock: "FOR UPDATE")
  # 2. Lit le dernier pointage
  previous = latest_clock(user_id)
  # 3. Vérifie la transition, 4. insère le pointage, 5. crée la période
end)
```

**Le problème évité.** Un double clic envoie deux « départ » quasi simultanés. Sans verrou, les deux requêtes lisent le même dernier pointage (« arrivée »), jugent toutes les deux le départ valide, et insèrent deux départs et deux périodes : les heures sont comptées deux fois.

**La solution.** `FOR UPDATE` verrouille la ligne de l'utilisateur jusqu'à la fin de la transaction. La seconde requête attend que la première ait terminé, relit alors le dernier pointage (désormais « départ ») et refuse proprement avec 422. C'est la ligne `users` qui est verrouillée, et non le dernier pointage : cela fonctionne aussi pour le tout premier pointage, quand il n'existe encore aucune ligne `clocks` à verrouiller.

**L'atomicité.** Le pointage et la période sont écrits dans la même transaction. Si la création de la période échoue, le pointage est annulé aussi : on ne peut jamais avoir un départ enregistré sans sa période.

Ces deux garanties sont vérifiées par `clocks_concurrency_test.exs`, qui lance réellement deux requêtes en parallèle sur des connexions séparées.

### 10.5 Compléter un départ oublié

`POST /api/clocks/:userID/:clockID/complete` avec `{ "clock": { "time": "..." } }`.

Un employé qui a oublié de pointer son départ ne peut pas utiliser la route normale : son départ serait daté de maintenant, et la période compterait la nuit. `complete_clock/3` enregistre un départ **à l'heure réelle**, avec des garde-fous supplémentaires (`validate_completion/4`) :

| Vérification | Message si refus |
|---|---|
| `clockID` est toujours le **dernier** pointage, et ce n'est pas un départ | « Les pointages ont changé. Actualisez avant de réessayer. » |
| L'heure n'est pas dans le futur | « Le départ ne peut pas être dans le futur. » |
| L'heure date de 7 jours au plus | « Seuls les départs des 7 derniers jours peuvent être complétés. » |
| L'heure suit le dernier pointage | « Le départ doit suivre le dernier pointage enregistré. » |

Le `clockID` sert de **verrou optimiste** : si l'employé a pointé entre-temps depuis un autre onglet, le formulaire est périmé et la requête est refusée au lieu de fermer le mauvais service. Le corps ne peut imposer ni `status` ni `kind` : ils sont fixés à `false` et `departure` par le code.

---

## 11. La gestion des erreurs

Les contextes renvoient `{:ok, valeur}` ou `{:error, raison}`. Ils ne lèvent pas d'exception pour un cas attendu. Le `FallbackController` traduit chaque raison en réponse HTTP :

| Valeur renvoyée | Code | Corps |
|---|---|---|
| `{:error, %Ecto.Changeset{}}` | **422** | `{ "errors": { "champ": ["message", ...] } }` |
| `{:error, :bad_request}` | **400** | `{ "errors": { "detail": "Bad Request" } }` |
| `{:error, :unauthorized}` (et le plug) | **401** | `{ "errors": { "detail": "Unauthorized" } }` |
| `{:error, :forbidden}` | **403** | `{ "errors": { "detail": "Forbidden" } }` |
| `{:error, :not_found}` | **404** | `{ "errors": { "detail": "Not Found" } }` |
| `{:error, :last_administrator}` | **409** | `{ "errors": { "detail": "The last administrator cannot be demoted or deleted" } }` |

Une exception inattendue donne **500**, rendu en JSON par `ErrorJSON` (configuré dans `config.exs` via `render_errors`). Le front-end reçoit donc toujours le même format `{ "errors": ... }`.

---

## 12. Configuration et variables d'environnement

Elixir distingue la configuration **de compilation** (`config.exs`, `dev.exs`, `test.exs`, `prod.exs`, lus au moment de compiler) et la configuration **d'exécution** (`runtime.exs`, lu à chaque démarrage). Les secrets sont toujours dans `runtime.exs`, pour ne jamais être figés dans le code compilé.

| Variable | Environnement | Rôle | Valeur par défaut |
|---|---|---|---|
| `JWT_SECRET` | tous | Clé de signature des JWT (32 caractères minimum). | Dev et test : une clé fixe. **Prod : obligatoire**, le démarrage échoue sans elle. |
| `COOKIE_SECURE` | tous | `true` : cookie envoyé uniquement en HTTPS. | `false` |
| `PORT` | tous | Port HTTP. | `4000` |
| `PGUSER`, `PGPASSWORD`, `PGHOST`, `PGPORT`, `PGDATABASE` | dev | Connexion PostgreSQL (`dev.exs`). | `postgres` / `postgres` / `localhost` / `5432` / `time_manager_dev` |
| `DATABASE_URL` | prod | Connexion PostgreSQL. | Obligatoire |
| `SECRET_KEY_BASE` | prod | Clé Phoenix pour signer les cookies de session. | Obligatoire |
| `PHX_HOST`, `PHX_SERVER`, `POOL_SIZE` | prod | Nom d'hôte public, démarrage du serveur en release, taille du pool. | — |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `ADMIN_USERNAME` | seeds | Création du premier administrateur. | Pas d'administrateur créé si absentes |

Le script de génération d'une clé : `mix phx.gen.secret`.

En test, `config/test.exs` règle bcrypt sur `log_rounds: 1`. Un hachage réaliste prend volontairement du temps ; sans ce réglage, la suite de tests serait des dizaines de fois plus lente. Ce réglage ne concerne **que** les tests.

---

## 13. Migrations et données de référence

Les migrations (`priv/repo/migrations/`) décrivent l'évolution de la base. Elles s'exécutent dans l'ordre de leur horodatage, une seule fois chacune : Ecto note celles déjà jouées dans la table `schema_migrations`.

| Migration | Ce qu'elle change |
|---|---|
| `20260922074724_create_users` | Table `users` (username, email). |
| `20260922114802_create_workingtime` | Table `workingtime`, contrainte `end > start`, suppression en cascade avec l'utilisateur. |
| `20260922120536_create_clocks` | Table `clocks` (time, status). |
| `20261004090000_add_roles_and_passwords` | Table `roles` et ses trois lignes ; `users.password_hash` et `users.role_id`. Les comptes existants deviennent `employee`. Les e-mails en double sont suffixés, puis tous mis en minuscules, avant de créer l'index unique sur `lower(email)`. |
| `20261004090100_create_teams` | Tables `teams` et `team_members`. |
| `20261004090200_delete_clocks_with_user` | Les pointages sont désormais supprimés avec leur utilisateur. Avant, supprimer un utilisateur qui avait pointé échouait sur la clé étrangère. |
| `20261005071118_add_kind_to_clocks` | Colonne `kind` ; les anciens pointages deviennent `arrival` ou `departure` selon leur `status` ; contrainte de cohérence `kind` ↔ `status`. |

Les migrations qui touchent des données existantes (rôles, e-mails, `kind`) les **reprennent** au lieu de les effacer : une base déjà en production se met à jour sans perte.

**`seeds.exs`** est idempotent : on peut l'exécuter autant de fois qu'on veut. Il réinsère les rôles s'ils manquent (`on_conflict: :nothing`) et crée le premier administrateur à partir de `ADMIN_EMAIL` / `ADMIN_PASSWORD`, seulement s'il n'existe pas encore. Le mot de passe ne vit jamais dans le dépôt. Sans premier administrateur, personne ne pourrait créer d'équipe ni promouvoir un manager.

---

## 14. Les tests

La suite compte **107 tests**. Elle se lance avec `mix test`.

### 14.1 L'outillage (`test/support/`)

| Fichier | Rôle |
|---|---|
| `data_case.ex` | Base des tests métier. Chaque test s'exécute dans une transaction **annulée à la fin** (sandbox Ecto) : les tests ne se polluent pas et peuvent tourner en parallèle. |
| `conn_case.ex` | Base des tests HTTP. Fournit `log_in(conn, user)`, qui fabrique un vrai JWT, pose le cookie et l'en-tête CSRF. |
| `fixtures/accounts_fixtures.ex` | `user_fixture(role: "manager")`, `team_fixture(manager_id: ..., members: [...])` : créer un jeu de données en une ligne. |

### 14.2 Ce qui est couvert

| Fichier | Tests | Ce qu'il vérifie |
|---|---|---|
| `time_manager/accounts_test.exs` | 19 | Création, hachage, unicité de l'e-mail, changement et réinitialisation du mot de passe, dernier administrateur. |
| `time_manager/clocks_test.exs` | 14 | Machine à états, dates antérieures, création des périodes, pauses exclues, `kind` incohérent refusé. |
| `time_manager/clocks_completion_test.exs` | 7 | Départ oublié : futur, plus de 7 jours, formulaire périmé, ordre des dates. |
| `time_manager/clocks_concurrency_test.exs` | 4 | Deux requêtes simultanées n'insèrent qu'un pointage et qu'une période (vraies connexions parallèles). |
| `time_manager_web/.../auth_controller_test.exs` | 13 | Login, register (le rôle envoyé est ignoré), cookie, CSRF manquant ou faux, utilisateur supprimé, logout. |
| `time_manager_web/.../user_controller_test.exs` | 25 | Périmètres, assignation de masse, mots de passe, promotion, suppression. |
| `time_manager_web/.../clock_controller_test.exs` | 9 | API de pointage, `complete`, personne ne pointe pour un autre. |
| `time_manager_web/.../working_time_controller_test.exs` | 8 | Lecture et correction selon le rôle. |
| `time_manager_web/.../team_controller_test.exs` | 5 | Composition des équipes réservée à l'administrateur. |
| `error_json_test.exs`, `api_spec_test.exs` | 3 | Format des erreurs, spec OpenAPI valide. |

### 14.3 Avant chaque commit

```bash
mix precommit
```

Cet alias enchaîne : compilation avec les warnings traités comme des erreurs, suppression des dépendances inutilisées du `mix.lock`, formatage du code, puis la suite de tests.

---

## 15. Lancer le backend

### En local

Prérequis : Elixir 1.17 et un PostgreSQL accessible (par défaut `postgres` / `postgres` sur `localhost:5432`).

```bash
cd time_manager
mix setup                          # dépendances + création de la base + migrations + seeds
ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD='un-mot-de-passe-long' mix run priv/repo/seeds.exs
mix phx.server                     # http://localhost:4000
```

- Swagger UI : <http://localhost:4000/swaggerui>. Connectez-vous avec `POST /api/auth/login`, puis collez le `csrf_token` reçu dans « Authorize ».
- Spec OpenAPI brute : <http://localhost:4000/api/openapi>.
- Repartir d'une base vide : `mix ecto.reset`.

### Avec Docker

`docker compose up` à la racine du dépôt démarre PostgreSQL, le backend et le tableau de bord. L'`entrypoint.sh` du backend :

1. refuse de démarrer sans fichier `.env` ;
2. attend que PostgreSQL réponde (`pg_isready`) ;
3. exécute `ecto.create`, `ecto.migrate`, puis les seeds ;
4. lance `mix phx.server`.

Le déploiement automatique (Travis CI, Docker Hub, serveur) est décrit dans [DEVOPS.md](DEVOPS.md).

---

## 16. Ajouter une fonctionnalité : la marche à suivre

Exemple : ajouter des « demandes de congé ».

1. **Migration** — `mix ecto.gen.migration create_leave_requests`. Mettez les règles qui doivent être vraies quoi qu'il arrive dans la base : `null: false`, clés étrangères, `CHECK`.
2. **Schéma et changeset** — `lib/time_manager/leaves/leave_request.ex`. Ne castez que les champs que le client a le droit de fixer ; le propriétaire vient du code.
3. **Contexte** — `lib/time_manager/leaves.ex`. Renvoyez `{:ok, _}` ou `{:error, _}` ; utilisez `Repo.transact` dès que plusieurs écritures doivent réussir ensemble.
4. **Autorisation** — ajoutez une fonction `can_…?` dans `authorization.ex`. Ne dispersez jamais une règle d'accès dans un contrôleur.
5. **Contrôleur et vue JSON** — dans `lib/time_manager_web/controllers/`, avec le même `with` que les autres, `action_fallback` et une macro `operation(...)`.
6. **Schémas OpenAPI** — dans `lib/time_manager_web/schemas/`.
7. **Route** — dans le scope protégé de `router.ex` : l'authentification est alors automatique.
8. **Tests** — un test métier (`DataCase`), puis un test HTTP (`ConnCase`) qui vérifie au minimum le 401 sans session et le 403 hors périmètre.
9. **`mix precommit`**.

---

## 17. Limites connues et pistes

| Limite | Conséquence | Piste |
|---|---|---|
| Les compteurs de tentatives sont en mémoire (ETS). | Ils repartent de zéro au redémarrage et ne sont pas partagés entre plusieurs instances. Derrière Nginx, tous les clients partagent l'adresse IP du proxy : seuls les seuils par e-mail restent fins. | Stockage partagé, et lecture de `X-Real-IP` une fois le port 4000 fermé au public. |
| `/api/auth/register` crée un compte actif sans validation. | Le compte est isolé de toute organisation, mais il contourne le circuit des demandes d'adhésion. | Le supprimer quand le front utilise le circuit organisations. |
| `COOKIE_SECURE` vaut `false` par défaut. | Sur un site en HTTP, le cookie circule en clair. | Servir en HTTPS et définir `COOKIE_SECURE=true`. |
| L'image Docker tourne en `MIX_ENV=dev`. | Le rechargement de code et les messages d'erreur détaillés restent actifs sur le serveur. | Construire une release `MIX_ENV=prod` (`mix release`). |
| Les corrections de périodes ne sont pas historisées. | Une période modifiée par un manager ne garde pas sa valeur d'origine. | Table d'audit (qui, quand, avant, après). |
| `README.md` du backend partiellement obsolète. | Il décrit encore `clocks.user_id` en `ON DELETE NOTHING`, corrigé depuis par la migration `delete_clocks_with_user`. | Le mettre à jour ou renvoyer vers ce document. |
