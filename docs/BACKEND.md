# Backend — architecture, code métier et endpoints

Documentation du code de `Theme_5_authentification_security/time_manager`, revue le **13 octobre 2026**. Elle décrit le dépôt ; la version d'un serveur dépend du code effectivement déployé. Les chemins de fichiers ci-dessous sont relatifs à `time_manager/`.

API HTTP en **Elixir/Phoenix**, servie par **Bandit**, avec **Ecto/PostgreSQL** pour la persistance : admission Gotham City, comptes, équipes, pointages, heures, corrections, validations, plannings, échanges, absences, paie, préférences et notifications.

## 1. Architecture du backend

### 1.1 Pattern utilisé

Le backend suit l'architecture Phoenix **par contextes métier**, dans un monolithe modulaire. La couche web ressemble à MVC : routeur, contrôleurs, schémas et modules de présentation `*JSON`. Les réponses JSON remplacent les vues HTML pour le métier.

Ce n'est pas une Clean Architecture stricte : les contextes utilisent directement Ecto et `Repo`, sans interfaces de repository indépendantes.

| Couche | Emplacement | Responsabilité |
|---|---|---|
| Entrée HTTP | `lib/time_manager_web/endpoint.ex`, `router.ex`, `plugs/` | Décoder la requête, vérifier origine/session, sélectionner l'action. |
| Contrôleurs et présentation | `lib/time_manager_web/controllers/` | Lire les paramètres, contrôler l'accès, appeler le métier, produire statut et JSON. |
| Contextes métier | `lib/time_manager/*.ex`, `workforce/` | Règles, transitions, périmètres, transactions et calculs. |
| Données | Schémas Ecto des sous-dossiers métier, `repo.ex` | Décrire les tables, valider les modifications et exécuter les requêtes. |
| Infrastructure | `config/`, `application.ex`, `priv/repo/` | Configuration, supervision OTP, migrations et données de référence. |

Un **changeset** décrit et valide des modifications ; il ne persiste rien à lui seul. `Repo.insert/update/delete` effectue l'écriture. Un contexte regroupe les opérations du domaine, par exemple `Clocks.create_clock/2` ou `Workforce.Planning.publish/3`.

### 1.2 Flux du client à la base

```text
Client Vue / client HTTP
  → proxy Vite ou Nginx pour /api
  → Bandit → Endpoint : parsing JSON, identifiant de requête, télémétrie
  → Router : pipelines :api puis :auth pour les routes protégées
  → CheckOrigin → Authenticate → conn.assigns.current_user
  → Controller → Authorization / Workforce → contexte métier
  → Ecto.Query / Changeset → Repo → PostgreSQL
  → *JSON ou json(conn, %{data: résultat}) → réponse HTTP
```

Le proxy n'est pas obligatoire pour un client serveur. Il permet au navigateur d'appeler l'API sur l'hôte du frontend et de transmettre le cookie.

Extrait réel de `controllers/clock_controller.ex` :

```elixir
def create(conn, %{"clock" => attrs}) when is_map(attrs) do
  with {:ok, user_id} <- cast_id(conn.path_params["userID"]),
       :ok <- authorize(Authorization.can_clock?(current_user(conn), user_id)),
       {:ok, user} <- Accounts.fetch_user(user_id),
       {:ok, clock} <- Clocks.create_clock(user, attrs) do
    conn
    |> put_status(:created)
    |> render(:show, clock: clock)
  end
end
```

Le contrôleur vérifie l'appelant ; `Clocks` verrouille le salarié, vérifie la transition, insère le pointage et ferme éventuellement une période travaillée dans la même transaction. `ClockJSON` choisit les champs retournés. Une erreur du `with` est traduite par `FallbackController`.

### 1.3 Sécurité et cohérence

- `Token` signe un JWT **HS256**, valable huit heures, contenant notamment `user_id`, `role`, `xsrf`, `jti`. Il est signé, pas chiffré.
- `AuthController` place le JWT dans le cookie `jwt`, `HttpOnly`, `SameSite=Strict`, chemin `/`. `COOKIE_SECURE=true` active `Secure`.
- `Authenticate` exige cookie et `X-CSRF-Token`, **même sur les GET protégés**. Il vérifie signature, expiration, révocation et correspondance CSRF, puis recharge utilisateur et rôle en base.
- `Authorization` définit rôle et périmètre. `Workforce` ajoute les permissions `correct`, `validate`, `publish` des équipes.
- Le manager intervient sur les membres des équipes qu'il dirige actuellement ; l'administrateur dans son organisation. Aucun responsable ne corrige directement ses propres périodes ni ne valide sa propre feuille, correction ou absence.
- `Repo.transact` et les verrous de lignes protègent les mutations concurrentes. Les validations groupées verrouillent les salariés par ID croissant. Le planning vérifie `revision` ; publication et modification des règles partagent un verrou d'organisation.

La déconnexion inscrit le `jti` dans `revoked_tokens`. Un rôle modifié ou un compte supprimé est pris en compte dès la requête suivante. Les comptes historiques sans organisation restent dans un espace distinct ; ils ne sont pas automatiquement rattachés à Gotham City.

## 2. Organisation des fichiers

```text
time_manager/
├── mix.exs / mix.lock                 Projet, dépendances et alias Mix
├── Dockerfile / entrypoint.sh         Construction et démarrage du conteneur
├── config/
│   ├── config.exs                     Configuration commune
│   ├── dev.exs / test.exs / prod.exs   Configuration selon MIX_ENV
│   └── runtime.exs                    Variables et secrets lus au démarrage
├── lib/
│   ├── time_manager.ex               Module d'entrée du domaine
│   ├── time_manager_web.ex           Macros partagées : controller, router, etc.
│   ├── time_manager/
│   │   ├── application.ex / repo.ex  Supervision OTP et dépôt Ecto
│   │   ├── accounts.ex               Comptes, mots de passe, sessions et vérification email
│   │   ├── accounts/                 User, Role, Profile, RevokedToken, EmailVerification
│   │   ├── organizations.ex          Provisionnement interne et demandes d'adhésion
│   │   ├── organizations/            Organization et JoinRequest
│   │   ├── authorization.ex          Droits généraux et isolation des organisations
│   │   ├── token.ex                  Signature JWT et génération CSRF
│   │   ├── teams.ex / teams/         Gestion et schéma des équipes
│   │   ├── clocks.ex / clocks/       Machine à états et schéma des pointages
│   │   ├── working_times.ex          Écriture et lecture des périodes
│   │   ├── working_times/            Schéma WorkingTime et validations
│   │   ├── workforce.ex             Règles, permissions, verrouillage, audit, préférences
│   │   ├── workforce/
│   │   │   ├── time_sheets.ex        Notes, validation/clôture et corrections
│   │   │   ├── planning.ex           Plannings, gardes, publication et échanges
│   │   │   ├── absences.ex           Demandes, décisions et heures rémunérables
│   │   │   ├── payroll.ex            Calcul mensuel, taux et CSV
│   │   │   └── autres *.ex           Schémas Ecto : Sheet, Plan, Shift, Swap, etc.
│   │   └── email*.ex / mailer.ex / resend.ex  Construction et transport des emails
│   └── time_manager_web/
│       ├── endpoint.ex / router.ex   Chaîne HTTP, routes et pipelines
│       ├── api_spec.ex               Spécification OpenAPI issue du routeur
│       ├── plugs/                    Authenticate, CheckOrigin et RateLimit
│       ├── rate_limiter.ex           Compteurs de limitation, en mémoire sur ce nœud
│       ├── controllers/              Actions HTTP, *JSON, Authz et FallbackController
│       ├── schemas/                  Descriptions OpenAPI, distinctes des schémas Ecto
│       └── telemetry.ex / gettext.ex Mesures et infrastructure Phoenix
├── priv/
│   ├── repo/migrations/              Évolution versionnée du schéma PostgreSQL
│   ├── repo/seeds.exs                Rôles et premier compte administrateur
│   └── static/                       Ressources statiques du backend
└── test/
    ├── support/                      DataCase, ConnCase et fixtures
    ├── time_manager/                 Tests métier et concurrence PostgreSQL
    └── time_manager_web/             Tests HTTP, autorisations, plugs et OpenAPI
```

`workforce/planning.ex` est un contexte ; `workforce/plan.ex` est un schéma. Les **middlewares** sont les plugs. Les fonctions habituellement appelées « services » résident dans les contextes et modules d'infrastructure ; il n'existe pas de dossier backend `services/`.

| Domaine | Tables principales | Relations |
|---|---|---|
| Identité | roles, users, organizations | Utilisateur → rôle/organisation ; organisation identifiée par UUID. |
| Admission/session | join_requests, email_verifications, revoked_tokens | Demandes, codes email et sessions révoquées. |
| Équipes | teams, team_members, team_permissions | Manager, membres et permissions d'équipe. |
| Temps | clocks, workingtime, weekly_sheets, correction_requests | Événements, intervalles, état hebdomadaire et corrections proposées. |
| Planning | workforce_plans, planned_shifts, shift_swaps | Brouillon/version publiée, affectations et échanges. |
| Absences/paie | absence_requests, payroll_profiles | Absences, heures rémunérables et taux personnel. |
| Réglages/suivi | workforce_settings, account_preferences, workforce_events, workforce_notifications | Règles, préférences, historique et notifications. |

Les migrations portent clés étrangères, index uniques et contraintes. La suppression d'un compte supprime ses données opérationnelles selon ces relations ; certaines références d'acteurs/relecteurs conservées deviennent `null`. Consulter les migrations pour les cascades exactes.

## 3. Fichiers clés et implémentation des fonctionnalités

| Fichier critique | Logique à rechercher |
|---|---|
| accounts.ex, accounts/user.ex, accounts/profile.ex | Identité, Argon2id, compatibilité bcrypt, changement de mot de passe et dernier administrateur. |
| organizations.ex | Création interne d'organisation/admin, nom normalisé, référence privée, approbation atomique et employé par défaut. |
| authorization.ex, workforce.ex | Périmètres, flags des managers, règles, préférences, audit, notifications et semaines verrouillées. |
| teams.ex | Composition, manager, appartenance et équipes gérées. |
| clocks.ex | Transitions arrival/pause/resume/departure, départ oublié sur sept jours et création atomique des périodes. |
| working_times.ex, working_times/working_time.ex | Durées positives, fin non future, chevauchements et catégories work/oncall/recup. |
| workforce/time_sheets.ex | Notes ; open → validated → closed ; réouverture ; corrections avec vérification des horaires d'origine. |
| workforce/planning.ex | Revision, copie publiée, quotas, délai, absences/chevauchements et consentement avant échange. |
| workforce/absences.ex | pending/approved/rejected/cancelled et confirmation de payable_hours. |
| workforce/payroll.ex | Découpage UTC, majorations exclusives, rémunération d'absence, Decimal et CSV. |
| controllers/workforce_controller.ex | Adaptateur HTTP commun des workflows ; délégation aux contextes. |
| controllers/*_json.ex, fallback_controller.ex | Forme publique des objets, confidentialité et erreurs HTTP. |

Mots de passe : **8 à 128 caractères**, nouveaux hashes Argon2id. Les anciens bcrypt sont migrés à la connexion réussie. Aucun hash/mot de passe n'est retourné.

Une semaine validated/closed bloque les périodes, pointages concernés, notes et régularisations d'absence. La réouverture motivée exige un responsable autorisé autre que le salarié.

Le planning conserve un snapshot interne : l'employé lit les gardes publiées pendant que le responsable modifie le brouillon. La réponse peut inclure les métadonnées d'un brouillon sans affectations publiées ; elle ne lui expose pas les gardes non publiées. `published` indique si la révision courante correspond à la révision publiée.

### Routage : déclaration et enregistrement

Les routes sont définies dans **lib/time_manager_web/router.ex**. L'endpoint termine sa chaîne par `plug TimeManagerWeb.Router`. Phoenix compile ces déclarations : aucune inscription manuelle supplémentaire n'est nécessaire.

Extrait réel :

```elixir
pipeline :api do
  plug :accepts, ["json"]
  plug TimeManagerWeb.Plugs.CheckOrigin
  plug OpenApiSpex.Plug.PutApiSpec, module: TimeManagerWeb.ApiSpec
end

pipeline :auth do
  plug TimeManagerWeb.Plugs.Authenticate
end
```

Les scopes publics utilisent `pipe_through :api`, les protégés `pipe_through [:api, :auth]`. `scope "/api", TimeManagerWeb` ajoute préfixe d'URL et namespace des contrôleurs. `resources "/teams", TeamController, except: [:new, :edit]` génère les actions REST ; **update accepte PUT et PATCH**. Les routes workingtime sont déclarées explicitement et ont des chemins différents selon l'action.

`AdmissionPolicyController` traite actuellement les POST /auth/register, /organizations, /users. Les anciennes actions create/register présentes dans d'autres contrôleurs ne sont pas celles enregistrées pour ces chemins.

`mix phx.routes` liste les routes ; `/api/openapi` expose la spécification et `/swaggerui` son interface. Les schémas WorkflowRequest/WorkflowResponse restent génériques : les tableaux ci-dessous précisent leurs champs. Aucun plug global CastAndValidate n'est installé ; contrôleurs et contextes effectuent la validation réelle.

## 4. Contrats des endpoints backend

### 4.1 Conventions communes

**Tous les chemins des tableaux sont préfixés par `/api`.** Identifiants de comptes, équipes, périodes et workflows : entiers. org_id et ID de demande d'adhésion : UUID.

```http
Accept: application/json
Content-Type: application/json
Cookie: jwt=<cookie obtenu à la connexion>
X-CSRF-Token: <csrf_token obtenu à la connexion>
```

Content-Type concerne les requêtes avec corps. Cookie et CSRF sont obligatoires sur les routes protégées ; `Authorization: Bearer` n'est pas utilisé. Pour l'export CSV, conserver les en-têtes d'authentification et l'acceptation JSON du pipeline ; la **réponse** sera text/csv.

CheckOrigin contrôle POST/PUT/PATCH/DELETE, routes publiques incluses : il compare le **nom d'hôte** d'Origin ou, à défaut, Referer à conn.host, sans comparer port et schéma. Sans ces en-têtes, ce contrôle passe. Il ne remplace pas les autorisations.

Succès JSON : `{"data": objet}` ou `{"data": [objets]}`. La notation **data: User** signifie `{"data": {...champs de User...}}`. Liste vide : `{"data": []}`. Un 204 a un corps vide. Les créations de workflows de WorkforceController répondent actuellement **200**, pas 201.

Erreurs réelles :

```json
{"errors":{"detail":"Cette période chevauche des heures déjà enregistrées."}}
```

```json
{"errors":{"email":["has already been taken"]}}
```

| Code | Signification |
|---|---|
| 200 | Lecture, modification ou création de workflow réussie. |
| 201 | Demande d'adhésion, équipe, pointage ou période créée. |
| 204 | Déconnexion/suppression classique réussie, sans corps. |
| 400 | Corps attendu absent, paramètre/date/filtre malformé, action inconnue. |
| 401 | Identifiants incorrects ou session/CSRF absent, invalide, expiré ou révoqué. |
| 403 | Origine, rôle ou périmètre refusé, auto-validation ou création directe interdite. |
| 404 | Ressource introuvable ; certains contrôleurs masquent aussi une ressource hors périmètre. |
| 409 | Version/état périmé, semaine verrouillée, chevauchement, doublon d'admission ou dernier admin. |
| 422 | Valeurs métier/changeset invalides : durée, type, motif, quota/délai de publication, etc. |
| 429 | Limite de requêtes/tentatives ; le plug RateLimit ajoute Retry-After en secondes. |
| 503 | Envoi d'email indisponible sur le parcours de vérification. |

Les colonnes **Erreurs** indiquent les erreurs métier principales. Ajouter 401 aux routes protégées et 403 de contrôle d'origine aux écritures. Un 500 est une panne inattendue, pas un état métier à utiliser côté client.

Dates : stockage/calcul **UTC**. week = lundi YYYY-MM-DD, month = YYYY-MM. Envoyer les instants en ISO 8601 avec Z. ClockJSON/WorkingTimeJSON retournent toutefois **YYYY-MM-DD HH:mm:ss sans suffixe**, toujours en UTC ; les workflows utilisent ISO 8601. Les Decimal sont des chaînes ; les durées calculées sont des nombres.

### 4.2 Authentification et créations désactivées

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| POST | `/auth/login` | Public ; `{"email":"agent@example.test","password":"<mot de passe>"}`. | 200 data: Session + csrf_token et cookie JWT. | 401 identifiants/compte non vérifié ; 429. |
| GET | `/auth/me` | Connecté ; aucun paramètre. | 200 data: User courant, détails personnels inclus. | Authentification commune. |
| GET | `/auth/session` | Connecté ; aucun paramètre. | 200 data: Session, sans nouveau csrf_token. | Authentification commune. |
| POST | `/auth/logout` | Connecté ; aucun corps requis. | 204, révocation et suppression du cookie. | Authentification commune. |
| POST | `/auth/verify-email` | Public ; `{"email":"agent@example.test","code":"123456"}` ; compte non vérifié existant. | 200 data: Session + csrf_token et cookie. | 400, 422 code invalide/expiré, 429. |
| POST | `/auth/resend-verification` | Public ; `{"email":"agent@example.test"}`. | 200 data: {verification_required:true}, réponse neutre si aucun compte concerné. | 400, 429, 503. |
| POST | `/auth/register` | Public ; corps sans effet, création directe désactivée. | **Aucun succès : 403.** | Politique d'admission. |
| POST | `/organizations` | Public ; création d'organisation désactivée. | **Aucun succès : 403.** | Provisionnement manuel requis. |
| POST | `/users` | Protégé ; création directe désactivée. | **Aucun succès : 403.** | Utiliser l'admission. |

Session = `{role,user:User,organization:{id,name,created_at}|null}`. Seule une ouverture de session ajoute csrf_token. Les rôles API sont employee/manager/administrator, pas admin.

Exemple de connexion réussie :

```json
{
  "data": {
    "role": "employee",
    "user": {
      "id": 14,
      "username": "sara.martin",
      "email": "sara@example.test",
      "first_name": "Sara",
      "last_name": "Martin",
      "organization_id": "d28a4c42-84f6-490a-9743-5fb5ac48ef89",
      "role": "employee",
      "gender": "female",
      "birth_date": "1999-03-12",
      "birth_place": "Paris",
      "inserted_at": "2026-10-13T08:00:00Z",
      "created_at": "2026-10-13T08:00:00Z"
    },
    "organization": {
      "id": "d28a4c42-84f6-490a-9743-5fb5ac48ef89",
      "name": "Gotham City",
      "created_at": "2026-10-01T08:00:00Z"
    },
    "csrf_token": "<jeton généré>"
  }
}
```

Limites par minute : login 10/email et 100/IP ; verify/resend 20/IP dans un compteur partagé ; lookup 60 ; dépôt d'adhésion 10 ; suivi 30. Les créations désactivées ne passent pas par les anciens limiteurs de création. L'OTP historique a six chiffres, expire après dix minutes et admet cinq essais ; les admissions approuvées ne nécessitent pas ce parcours OTP.

### 4.3 Organisation et admission

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/organizations/lookup` | Public ; query name=Gotham City obligatoire, comparaison normalisée. | 200 data: {id,name}. | 404, 429. |
| POST | `/join-requests` | Public ; organization_id UUID et profile ci-dessous. | 201 data: {id,reference,organization_name,status}. | 400, 404, 409 email/demande pending, 422, 429. |
| POST | `/join-requests/status` | Public ; `{"reference":"<référence privée>"}` dans le corps. | 200 data: {id,reference,organization_name,status,rejection_reason}. | 400, 404, 429. |
| GET | `/organizations/:org_id/join-requests` | Admin de cette organisation ; aucun filtre. | 200 data: [JoinRequest]. | 403. |
| POST | `/organizations/:org_id/join-requests/:id/approve` | Même admin ; `{"password":"<mot de passe choisi>"}`. | 200 data: {request:JoinRequest,user:User}. | 400, 403, 404, 409, 422. |
| POST | `/organizations/:org_id/join-requests/:id/reject` | Même admin ; `{"reason":"Motif du refus"}`. | 200 data: JoinRequest. | 400, 403, 404, 409, 422. |
| GET | `/organizations/:org_id/members` | Admin de cette organisation. | 200 data: [User], détails personnels inclus. | 403. |
| PATCH | `/organizations/:org_id/members/:id` | Même admin ; `{"role":"manager"}` ou employee. | 200 data: User. | 400, 403 compte admin, 404, 422. |

```json
{
  "organization_id": "d28a4c42-84f6-490a-9743-5fb5ac48ef89",
  "profile": {
    "first_name": "Sara",
    "last_name": "Martin",
    "email": "sara@example.test",
    "gender": "female",
    "birth_date": "1999-03-12",
    "birth_place": "Paris"
  }
}
```

Les six champs de profil sont requis. Genre : female/male/non_binary/unspecified. Prénom/nom/lieu ≤100 caractères, email ≤254 ; naissance entre 1900-01-01 et aujourd'hui. La référence n'est placée ni dans l'URL ni dans la réponse admin. L'approbation crée un employé et ne retourne **jamais le mot de passe** ; le frontend présente temporairement celui que l'admin vient de saisir.

JoinRequest = `{id,organization_id,organization_name,profile,status,created_at,reviewed_at,reviewed_by,rejection_reason}`. reviewed_by est un ID ; status = pending/approved/rejected.

### 4.4 Comptes et rôles

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/users` | Admin/manager ; query email/username facultative, égalité exacte. | 200 data: [User] autorisés. | 403 employé. |
| GET | `/users/:id` | Soi ou responsable autorisé. | 200 data: User. | 403, 404. |
| PUT, PATCH | `/users/:id` | Soi/admin ; `{"user":{...}}`, champs ci-dessous. | 200 data: User. | 400, 403, 404, 422. |
| DELETE | `/users/:id` | Soi : `{"current_password":"<mot de passe>"}` ; admin sur autre compte de son organisation : aucun corps requis. | 204 ; suppression du cookie si auto-suppression. | 403, 404, 409 dernier admin, 422 mot de passe personnel. |
| PUT | `/users/:id/role` | Admin ; `{"role":"employee"}` ou manager, jamais sur soi. | 200 data: User. | 400, 403, 404, 409, 422. |
| GET | `/roles` | Connecté. | 200 data: [{id,name}]. | Authentification commune. |

Profil modifiable : username/email/first_name/last_name. Pour son mot de passe : password et current_password sous user. L'admin réinitialisant le mot de passe d'un autre compte fournit seulement password. Rôle/organisation ne sont pas modifiables via ce payload.

User contient les champs de l'exemple de session ; gender/birth_date/birth_place ne sont présents que pour soi ou un admin de l'organisation. Les listes de comptes n'ont pas de pagination.

### 4.5 Équipes et membres

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/teams` | Connecté ; admin : organisation ; autres : équipes gérées/appartenances. | 200 data: [Team]. | Authentification commune. |
| GET | `/teams/:id` | Admin de l'équipe ou manager actuel. | 200 data: Team. | 403, 404. |
| POST | `/teams` | Admin ; `{"team":{"name":"Voirie","manager_id":15}}`, manager facultatif. | 201 data: Team. | 400, 403, 422. |
| PUT, PATCH | `/teams/:id` | Admin ; `{"team":{"name":"Voirie nuit","manager_id":15}}`, null retire le manager. | 200 data: Team. | 400, 403, 404, 422. |
| DELETE | `/teams/:id` | Admin ; aucun corps. | 204. | 403, 404. |
| POST | `/teams/:id/members` | Admin ; `{"user_id":14}`. | 200 data: Team mis à jour. | 400, 403, 404, 422. |
| DELETE | `/teams/:id/members/:user_id` | Admin ; paramètres du chemin. | 200 data: Team mis à jour. | 403, 404. |

Team = `{id,name,manager:User|null,members:[User]}`. À l'index, un simple membre voit members=[] pour ses équipes non gérées. Manager et membres sont contrôlés dans l'espace de l'équipe ; le nom est validé avec contrainte d'unicité.

### 4.6 Pointages

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/clocks/:userID` | Soi/responsable ; aucun filtre. | 200 data: [Clock], ordre chronologique. | 403, 404. |
| POST | `/clocks/:userID` | Soi uniquement ; `{"clock":{"time":"2026-10-13T09:00:00Z","status":true,"kind":"arrival"}}`. | 201 data: Clock. | 400, 403, 404, 409, 422. |
| POST | `/clocks/:userID/:clockID/complete` | Soi ; dernier pointage attendu ; `{"clock":{"time":"2026-10-13T17:00:00Z"}}`. | 201 data: Clock de départ. | 400, 403, 404, 409, 422 temps invalide/pointage périmé. |

Clock = `{id,user_id,time,status,kind}`. status=true pour arrival/resume, false pour pause/departure. Sans kind, true implique arrival et false departure. time obligatoire, non futur et non antérieur au dernier pointage.

Transitions : hors service → arrival ; arrival/resume → pause/departure ; pause → resume/departure ; departure → arrival. Pause/départ ferme le segment ; un départ pendant une pause ne crée pas de période supplémentaire. Le départ oublié exige une heure dans les sept derniers jours et le dernier pointage toujours identique.

### 4.7 Périodes de travail

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/workingtime/:userID` | Soi/responsable ; query start/end facultative, instants UTC. | 200 data: [WorkingTime], tri par début. | 400 filtre/plage, 403, 404. |
| GET | `/workingtime/:userID/:id` | Même accès ; période appartenant à userID. | 200 data: WorkingTime. | 403, 404. |
| POST | `/workingtime/:userID` | Autre salarié de son périmètre, permission correct ; `{"workingtime":{"start":"...","end":"...","kind":"work"}}`. | 201 data: WorkingTime + Location. | 403, 404, 409, 422. |
| PUT | `/workingtime/:id` | Même permission ; mêmes champs, modification partielle possible. | 200 data: WorkingTime. | 403, 404, 409, 422. |
| DELETE | `/workingtime/:id` | Même permission ; aucun corps. | 204. | 403, 404, 409. |

WorkingTime = `{id,user_id,start,end,kind}` ; kind=work/oncall/recup, défaut work. Le contrôleur accepte aussi les champs sans enveloppe workingtime. Durée positive, fin non future, absence de chevauchement avec les autres périodes du salarié.

Les filtres sélectionnent les **chevauchements** : période.end > start et période.start <= end. L'objet est retourné complet, sans découpage aux limites de la fenêtre.

### 4.8 Contexte, règles, permissions et préférences

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/workforce/context` | Connecté ; aucun paramètre. | 200 data: {rules,preferences,permissions:[...]}. | Authentification commune. |
| GET | `/organizations/:org_id/rules` | Compte de cette organisation. | 200 data: Rules. | 403. |
| PATCH | `/organizations/:org_id/rules` | Admin ; `{"rules":{...}}`, champs partiels. | 200 data: Rules fusionnées. | 400, 403, 422. |
| GET | `/teams/:id/permissions` | Admin/manager/membre de l'équipe. | 200 data: {validate,correct,publish}. | 403, 404. |
| PATCH | `/teams/:id/permissions` | Admin ; `{"permissions":{"publish":true}}`. | 200 data: {validate,correct,publish}. | 400, 403, 404, 422. |
| GET | `/auth/preferences` | Compte courant. | 200 data: Preferences. | Authentification commune. |
| PATCH | `/auth/preferences` | Compte courant ; champs à la racine. | 200 data: Preferences fusionnées. | 400, 422. |

Les permissions du contexte couvrent les équipes gérées pour le manager, toutes celles de l'organisation pour l'admin, aucune pour l'employé. Entrée : `{team_id,manager_id,team,member_ids,validate,correct,publish}`. Défauts : validate/correct true, publish false.

| Champ Rules | Type / bornes | Défaut |
|---|---|---|
| maxConsecutiveNights | entier 1–31 | 3 |
| maxNightsPerWeek / maxNightsPerMonth | entiers 0–7 / 0–31 ; zéro désactive le quota | 0 / 0 |
| overtimeThreshold | entier 1–168, heures/semaine | 40 |
| publishDaysAhead | entier 0–365, jours | 14 |
| nightStart / nightEnd | entiers UTC 0–23, différents | 22 / 6 |
| nightMultiplier / overtimeMultiplier | nombres 1–10 | 1.5 / 2 |
| paidAbsenceKinds | liste leave/sick, au plus deux éléments | [] |
| timezone | valeur unique Etc/UTC | Etc/UTC |

Preferences : theme=light/night/contrast ; strong_text/tour_seen/speech_enabled booléens ; speech_rate nombre 0.5–2 ; speech_voice texte ≤200 caractères. Les champs inconnus sont refusés pour Rules/Permissions/Preferences. La synthèse vocale s'exécute dans le navigateur : le backend ne génère pas d'audio.

### 4.9 Notes, feuilles hebdomadaires et corrections

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/users/:user_id/week-notes/:week` | Soi/responsable ; week = lundi. | 200 data: Sheet. | 400, 403, 404, 422. |
| PUT | `/users/:user_id/week-notes/:week` | Soi uniquement ; `{"note":"Commentaire"}`, ≤2000 caractères. | 200 data: Sheet. | 400, 403, 404, 409 verrouillage, 422. |
| GET | `/weekly-sheets` | Query week obligatoire ; comptes accessibles. | 200 data: [Sheet]. | 400, 422 date non lundi. |
| POST | `/weekly-sheets/validate` | Autre salarié, permission validate ; `{"week":"2026-10-05","user_ids":[14,15]}`. | 200 data: [Sheet], lot atomique. | 400, 403, 404, 409, 422. |
| POST | `/weekly-sheets/:user_id/:week/:action` | Même permission ; action close/reopen ; `{"reason":"Motif"}`. | 200 data: Sheet. | 400, 403, 404, 409, 422. |
| GET | `/correction-requests` | Périmètre accessible ; query user_id facultative. | 200 data: [Correction]. | 400, 403. |
| POST | `/workingtime/:id/correction-requests` | id = **période** du compte courant ; payload ci-dessous. | 200 data: Correction pending. | 400, 403, 404, 409, 422. |
| PATCH | `/correction-requests/:id` | Autre salarié, permission correct ; `{"status":"approved","reason":""}` ou rejected avec motif. | 200 data: Correction. | 400, 403, 404, 409, 422. |

```json
{
  "correction": {
    "start": "2026-10-05T09:00:00Z",
    "end": "2026-10-05T17:00:00Z",
    "reason": "Départ enregistré trop tôt"
  }
}
```

Sheet = `{id,user_id,week,note,status,reviewer_id,reviewed_at,reason,inserted_at,updated_at}`. Sans ligne enregistrée, la lecture représente une feuille open avec ID/timestamps null. Validation : 1–100 IDs entiers positifs, doublons dédupliqués ; semaine terminée, sans départ bloquant ni correction pending. Si un membre échoue, aucun n'est validé. Close/reopen : motif de 1–500 caractères.

Correction = `{id,user_id,period_id,username,before:{start,end},proposal:{start,end},reason,status,created_at,reviewed_at,reviewed_by,review_reason}` ; reviewed_by est le username du responsable. Motif de proposition 1–500 caractères, départ après arrivée et non futur. Une seule demande pending par période ; acceptation seulement si les horaires d'origine sont toujours actuels.

Il n'y a pas de délai général de sept jours pour proposer une correction dans ce workflow : le verrouillage de semaine s'applique ; les sept jours concernent le **départ oublié**.

### 4.10 Plannings et affectations

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/plans` | Équipes accessibles ; query from/to facultative ; défaut aujourd'hui à +42 jours, écart 1–366 jours. | 200 data: [Plan]. | 400, 422. |
| GET | `/plans/:id` | Équipe accessible ; gardes brouillon seulement pour responsable/admin. | 200 data: Plan. | 403, 404. |
| POST | `/teams/:id/plans` | Manager actuel/admin ; `{"plan":{"start":"2026-11-02","days":14}}`, days 1–31, défaut 14. | 200 data: Plan, revision initiale 1. | 400, 403, 404, 422. |
| PATCH | `/plans/:id` | Même accès ; `{"revision":1,"start":"2026-11-03","days":14}` ; brouillon vide jamais publié. | 200 data: Plan, revision incrémentée. | 403, 404, 409, 422. |
| DELETE | `/plans/:id` | Même accès + publish si publié ; `{"revision":2,"reason":"Retrait motivé"}` ; plan non commencé. | 200 data: {id}. | 403, 404, 409, 422. |
| POST | `/plans/:plan_id/shifts` | Manager actuel/admin ; `{"shift":{...}}` ci-dessous. | 200 data: Plan complet mis à jour. | 400, 403, 404, 409, 422. |
| PUT | `/plans/:plan_id/shifts/:id` | Même accès/payload ; garde modifiable. | 200 data: Plan mis à jour. | 400, 403, 404, 409, 422. |
| DELETE | `/plans/:plan_id/shifts/:id` | Même accès ; `{"revision":3}`. | 200 data: Plan mis à jour. | 403, 404, 409, 422. |
| POST | `/plans/:id/publish` | Permission publish ; `{"revision":4}`. | 200 data: Plan publié. | 403, 404, 409, 422. |

```json
{
  "shift": {
    "user_id": 14,
    "start": "2026-11-03T22:00:00Z",
    "end": "2026-11-04T06:00:00Z",
    "kind": "night",
    "place": "Centre municipal",
    "revision": 1
  }
}
```

Plan = `{id,team_id,team_name,start,days,revision,published_revision,published_at,published,can_manage,can_publish,shifts,members,inserted_at,updated_at}`. members contient `{id,username,name}` ; shifts contient `{id,plan_id,user_id,start,end,kind,place,inserted_at,updated_at}`. Le snapshot brut n'est pas retourné.

Types : day/night/oncall/leave/rest. Durée positive ≤24 h, début dans la période du plan, salarié membre et garde non passée ; lieu ≤200 caractères. La **revision est obligatoire** pour chaque modification/publication après création. Une revision absente/ancienne produit 409 : relire avant de réessayer.

La publication vérifie gardes présentes, délai, composition, quotas, chevauchements et absences approuvées, y compris les autres publications aux frontières de semaine/mois. La recherche from/to filtre le début des plans avec une marge de 31 jours ; elle ne découpe pas les plans.

### 4.11 Échanges de gardes

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/shift-swaps` | Demandes personnelles/périmètre responsable. | 200 data: [Swap]. | Authentification commune. |
| POST | `/shift-swaps` | Propriétaire de la première garde ; `{"shift_id":1,"target_shift_id":2,"reason":"Motif"}`. | 200 data: Swap pending. | 400, 403, 404, 409, 422. |
| PATCH | `/shift-swaps/:id/consent` | Collègue destinataire ; `{"accepted":true}` ou false. | 200 data: Swap consented/rejected. | 400, 403, 404, 409. |
| PATCH | `/shift-swaps/:id` | Responsable des deux salariés ; `{"status":"approved","reason":""}` ou rejected avec motif. | 200 data: Swap. | 403, 404, 409, 422. |

Swap = `{id,user_id,target_user_id,shift_id,target_shift_id,proposal:{source,target},reason,status,reviewer_id,review_reason,reviewed_at,inserted_at,updated_at}`. proposal conserve les gardes proposées. États : pending → consented → approved/rejected ; refus du collègue = rejected.

Gardes futures, du même planning publié à jour, salariés différents, hors congé/repos ; motif obligatoire ≤500 caractères. La décision exige validate pour les deux salariés ; l'approbation exige aussi publish et revalide snapshots/membres/contraintes. Modifier/supprimer une garde rejette ses propositions actives. L'échange approuvé et la publication sont modifiés atomiquement.

### 4.12 Congés et absences

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/absence-requests` | Périmètre accessible ; aucun filtre. | 200 data: [Absence]. | Authentification commune. |
| POST | `/absence-requests` | Compte courant ; `{"start":"2026-11-05T09:00:00Z","end":"2026-11-05T17:00:00Z","kind":"leave","reason":"Congé"}`. | 200 data: Absence pending. | 400, 409, 422. |
| PATCH | `/absence-requests/:id` | Autre salarié, permission validate ; `{"status":"approved","reason":"","payable_hours":"8"}` ou rejected avec motif. | 200 data: Absence. | 403, 404, 409, 422. |
| POST | `/absence-requests/:id/cancel` | Propriétaire si pending, ou responsable validate ; `{"reason":"Annulation motivée"}`. | 200 data: Absence cancelled. | 403, 404, 409, 422. |
| PATCH | `/absence-requests/:id/payment` | Autre salarié, permission validate ; absence approuvée ; `{"payable_hours":"8"}`. | 200 data: Absence mise à jour. | 403, 404, 409, 422. |

Absence = `{id,user_id,start,end,kind,reason,status,payable_hours,reviewer_id,review_reason,reviewed_at,inserted_at,updated_at}`. Types leave/sick/recup ; états pending/approved/rejected/cancelled. Durée 1 seconde à 366 jours, commentaire facultatif ≤500 caractères. Pas de chevauchement d'absences actives ; l'approbation refuse le travail déjà enregistré sur cette plage.

payable_hours facultatif à l'acceptation, non négatif, fini, ≤durée de la plage, arrondi à quatre décimales ; interdit pour recup. Sans quantité confirmée pour une catégorie rémunérée, le montant reste indisponible. Refus/annulation exigent un motif ; les régularisations vérifient le verrouillage hebdomadaire.

### 4.13 Paie et export

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/payroll` | Admin ; query month=YYYY-MM obligatoire. | 200 data: PayrollReport. | 400, 403. |
| GET | `/payroll/export` | Même accès/query/calcul. | 200 text/csv, UTF-8 avec BOM, séparateur ; et Content-Disposition attachment. | 400, 403. |
| GET | `/users/:id/payroll-profile` | Soi/admin de l'organisation. | 200 data: PayProfile. | 403, 404. |
| PUT | `/users/:id/payroll-profile` | Admin ; `{"hourly_rate":"15.50","currency":"EUR"}`. | 200 data: PayProfile. | 400, 403, 404, 422. |

PayProfile = `{id,user_id,hourly_rate,currency,inserted_at,updated_at}`, valeurs par défaut si non enregistré. Taux 0–100000, fini, au plus deux décimales ; null retire le taux. Devises EUR/USD/GBP.

PayrollReport = `{month,timezone,rules,rows,total,currency_totals}` ; total est une durée travaillée, currency_totals regroupe les montants par devise. Exemple complet d'une ligne :

```json
{
  "id": 14,
  "name": "Sara Martin",
  "email": "sara@example.test",
  "day": 8.0,
  "night": 0.0,
  "sup": 0.0,
  "recup": 0.0,
  "oncall": 0.0,
  "leave": 0.0,
  "sick": 0.0,
  "recup_taken": 0.0,
  "paid_absence_hours": 0.0,
  "total": 8.0,
  "hourly_rate": "15.50",
  "currency": "EUR",
  "amount": "124.00",
  "absence_payment_incomplete": false,
  "absence_conflict": false,
  "absence_payment": [],
  "confirmed": false
}
```

Le calcul découpe aux frontières UTC et récupère aussi le début de la semaine contenant le premier jour du mois. Catégories exclusives : les heures sup. ne cumulent pas le coefficient nuit ; seules les périodes work consomment le seuil hebdomadaire. Oncall est au taux normal ; recup n'entre pas dans le montant.

Leave/sick/recup_taken sont des durées d'absence séparées du total travaillé. Leur rémunération utilise les catégories activées et les **heures confirmées**, réparties au prorata si la plage traverse un mois. Le travail en chevauchement est déduit et signalé. amount=null sans taux/quantité requise ; confirmed exige toutes les semaines du mois validées/clôturées et aucune anomalie d'absence.

Les montants utilisent Decimal, arrondi final à deux décimales, sans additionner des devises différentes. Le CSV protège les cellules susceptibles d'être interprétées comme formules. Ce relevé ne calcule ni salaire net, ni charges, ni déclaration externe. Il utilise les **règles/taux actuels**, sans figer une paie historique.

### 4.14 Journal, notifications et documentation interactive

| Méthode | Route | Entrée / accès | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/audit-events` | Admin ; aucun filtre/pagination. | 200 data: [Event], 200 derniers de son organisation. | 403. |
| GET | `/notifications` | Compte courant. | 200 data: [Notification], 100 dernières personnelles. | Authentification commune. |
| PATCH | `/notifications/:id/read` | Destinataire ; aucun corps requis. | 200 data: Notification, read_at renseigné. | 403, 404. |
| GET | `/openapi` | Public ; aucun paramètre. | 200 spécification JSON, **sans enveloppe data**. | Échec de génération = erreur serveur. |

Event = `{id,organization_id,actor_id,action,details,inserted_at}` ; Notification = `{id,user_id,title,body,read_at,inserted_at}`. Les notifications de décisions sont persistées dans l'application ; pas d'email/SMS automatique ou de rappel programmé pour ces workflows.

Hors préfixe /api, GET `/swaggerui` sert du HTML. `/dev/dashboard` et `/dev/mailbox` sont conditionnels au mode développement ; `/live` est le socket Phoenix de l'endpoint, pas une API métier du frontend.

## 5. Configuration, migrations et vérification

| Fichier / réglage | Fonction |
|---|---|
| mix.exs | Elixir ~> 1.17, Phoenix ~> 1.8.14 et dépendances ; versions résolues dans mix.lock. |
| config/dev.exs | PostgreSQL via PGUSER/PGPASSWORD/PGHOST/PGDATABASE/PGPORT ; port HTTP 4000 par défaut. |
| config/test.exs | Base isolée time_manager_test, SQL Sandbox, hash moins coûteux, limiteurs désactivés pour la suite ordinaire. |
| config/runtime.exs | PORT, JWT_SECRET, COOKIE_SECURE, EMAIL_DELIVERY ; en prod DATABASE_URL, POOL_SIZE, SECRET_KEY_BASE et endpoint. |
| application.ex | Supervise Repo, PubSub, télémétrie, DNSCluster, RateLimiter et Endpoint avec stratégie one_for_one. |
| entrypoint.sh | Attend PostgreSQL, lance ecto.create, ecto.migrate, seeds, puis phx.server. |

Le Dockerfile actuel utilise **MIX_ENV=dev**, même dans le déploiement par images. La configuration de développement et ses routes dev sont donc actives ; ce n'est pas une release prod. Fournir un JWT_SECRET réel : le repli de développement ne convient pas au serveur déployé.

seeds.exs insère les rôles et, si ADMIN_EMAIL/ADMIN_PASSWORD sont présents, un admin **sans organisation**. Il ne modifie pas un compte existant et ne crée pas Gotham City. Le provisionnement/rattachement Gotham est décrit dans le [contrat d'organisation](CONTRAT_BACKEND_ORGANISATIONS.md#10-provisionnement-manuel-et-verrouillage-de-gotham-city) et le script racine scripts/recreate_gotham_admin.sh.

Les trois migrations workforce du 12 octobre ajoutent les tables métier, l'audit des comptes historiques et payable_hours. Ecto suit les versions appliquées et ne les rejoue pas. Voir le [guide de déploiement](DEPLOIEMENT_WORKFLOWS.md) pour la base cible.

Depuis time_manager/, avec PostgreSQL disponible :

```bash
mix phx.routes
mix precommit
```

precommit utilise l'environnement test : compilation avec warnings-as-errors, contrôle des dépendances inutilisées, formatage et tests. Les tests métier couvrent transitions/validations/concurrence ; les tests HTTP couvrent authentification, isolation, payloads, erreurs et OpenAPI. Les tests concurrents utilisent des connexions PostgreSQL distinctes pour vérifier les verrous réels.

Pour ajouter une route : déclarer le chemin dans router.ex, écrire contrôleur et description OpenAPI, placer les règles dans le contexte, définir schéma/changeset/migration si nécessaires, tester autorisations, erreurs et concurrence pertinente. Actualiser ce document et le [contrat backend/frontend](CONTRAT_BACKEND_ORGANISATIONS.md) si le contrat public change.
