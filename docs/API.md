# API du Time Manager

L'API REST du Time Manager gère les **utilisateurs** et leurs **rôles**, les **équipes**, les **pointages** (arrivées et départs) et les **temps de travail** (périodes avec un début et une fin). Elle est écrite en Elixir avec Phoenix, et stocke ses données dans PostgreSQL.

Toutes les routes, sauf la connexion et l'inscription, exigent une session : un JWT dans un cookie `HttpOnly` et un token CSRF dans l'en-tête `X-CSRF-Token`. Chaque route vérifie ensuite le rôle de l'appelant et le périmètre des données demandées.

## Sommaire

1. [Accéder à l'API](#1-acceder-a-lapi)
2. [Authentification](#2-authentification)
3. [Rôles et permissions](#3-roles-et-permissions)
4. [Conventions communes](#4-conventions-communes)
5. [Modèle de données](#5-modele-de-donnees)
6. [Utilisateurs — `/api/users`](#6-utilisateurs-apiusers)
7. [Équipes et rôles — `/api/teams`, `/api/roles`](#7-equipes-et-roles-apiteams-apiroles)
8. [Pointages — `/api/clocks`](#8-pointages-apiclocks)
9. [Temps de travail — `/api/workingtime`](#9-temps-de-travail-apiworkingtime)
10. [Scénario complet avec curl](#10-scenario-complet-avec-curl)
11. [Limites connues](#11-limites-connues)

---

## 1. Accéder à l'API

| Contexte | URL de base |
|---|---|
| Développement local (`mix phx.server` ou `docker compose up`) | `http://localhost:4000/api` |
| Frontend en développement (`npm run dev`) | `http://localhost:5173/api`, relayé par Vite vers le port 4000 |
| Serveur, via le frontend | `http://IP:8080/api` |
| Serveur, accès direct au backend | `http://IP:4000/api` |

Le frontend n'appelle pas le port 4000 : son Nginx (ou Vite en développement) relaie toutes les requêtes `/api/...` vers Phoenix. Pour le navigateur, l'API a donc la même origine que l'application. Le cookie de session part avec chaque appel, et aucune configuration CORS n'est nécessaire.

**Documentation interactive.** Le backend génère lui-même sa spécification OpenAPI à partir des contrôleurs, avec la bibliothèque OpenApiSpex :

| URL | Contenu |
|---|---|
| `/swaggerui` | Swagger UI : la liste des routes, avec un bouton *Try it out*. Appelez d'abord `POST /api/auth/login` (le navigateur garde le cookie), puis collez le `csrf_token` reçu dans *Authorize → csrfToken*. |
| `/api/openapi` | La spécification OpenAPI au format JSON, à importer dans Postman, Insomnia ou un générateur de client. |

**Premier administrateur.** Au démarrage, le conteneur `phoenix` lance `priv/repo/seeds.exs`, qui crée les trois rôles puis un administrateur à partir de `ADMIN_EMAIL` et `ADMIN_PASSWORD`, s'ils sont définis. En local :

```bash
ADMIN_EMAIL=admin@gotham.gov ADMIN_PASSWORD='un mot de passe' mix run priv/repo/seeds.exs
```

---

## 2. Authentification

Le mécanisme suit le sujet : un **JWT signé avec Joken**, envoyé dans un **cookie `HttpOnly`**, qui embarque un **token CSRF** renvoyé au front à la connexion.

```text
1. CONNEXION
   Navigateur ── POST /api/auth/login {email, password} ──▶ API
                                                          vérifie le hash Argon2id
                                                          génère un token CSRF aléatoire (32 octets)
                                                          signe le JWT {user_id, role, xsrf, jti, exp}
   Navigateur ◀── Set-Cookie: jwt=… (HttpOnly, SameSite=Strict, 8 h)
                  + {"data": {"csrf_token": "…", "role": "…", "user": {…}, "organization": {…}}}
   Le front garde csrf_token (mémoire + sessionStorage). Il ne voit jamais le JWT.

2. CHAQUE REQUÊTE
   Navigateur ── cookie jwt (envoyé par le navigateur) + en-tête X-CSRF-Token ──▶ API
                                                          signature et expiration du JWT valides ?
                                                          xsrf du JWT == X-CSRF-Token ? (temps constant)
                                                          jti absent de la liste des sessions révoquées ?
                                                          relit l'utilisateur et son rôle en base
                                                          contrôle le rôle et le périmètre
   Navigateur ◀── 200 · 401 non authentifié · 403 interdit
```

**Pourquoi ces trois pièces.**

| Pièce | Protège contre |
|---|---|
| Cookie `HttpOnly` | Le vol du JWT par un script injecté dans la page (XSS) : le JavaScript ne peut pas lire ce cookie. |
| Token CSRF dans un en-tête | Les requêtes forgées depuis un autre site (CSRF) : le navigateur y joint le cookie, mais le site tiers ne connaît pas le token. |
| Token CSRF *dans* le JWT | Le serveur n'a pas à stocker le token CSRF : il compare l'en-tête au `xsrf` du JWT, qu'il est seul à pouvoir signer. Seules les sessions fermées par une déconnexion sont notées en base (`revoked_tokens`). |

**Le rôle est relu en base à chaque requête.** Le JWT contient le rôle du moment de la connexion, mais le plug d'authentification ne s'y fie pas : il recharge l'utilisateur. Une rétrogradation ou une suppression de compte prend effet dès la requête suivante, sans attendre l'expiration du jeton.

**Mots de passe.** Ils sont hachés avec Argon2id (`argon2_elixir`) et ne sont jamais renvoyés. De 8 à 128 caractères, conservés tels que saisis (ni coupés ni tronqués), jamais composés uniquement d'espaces. Les hashs bcrypt créés avant le passage à Argon2id restent acceptés et sont remplacés à la connexion suivante. Un e-mail inconnu et un mauvais mot de passe donnent la même réponse, en un temps comparable, pour ne pas révéler quels comptes existent.

**Déconnexion réelle.** `POST /api/auth/logout` inscrit l'identifiant du JWT (`jti`) dans `revoked_tokens` jusqu'à son expiration : rejoué après la déconnexion, le même cookie donne `401`.

**Origine des requêtes.** Toute requête `POST`, `PUT`, `PATCH` ou `DELETE` dont l'en-tête `Origin` (ou, à défaut, `Referer`) désigne un autre hôte que celui de l'API est refusée en `403`, y compris sur les routes publiques. Une requête sans ces en-têtes (curl) passe.

**Limitation des tentatives.** Les routes publiques répondent `429` avec `Retry-After` au-delà d'un seuil par minute : connexion (10 par e-mail, 100 par adresse IP), inscription (20), création d'organisation (10), recherche d'organisation (60), demande d'adhésion (10), suivi (30).

### Routes d'authentification

| Méthode | Route | Accès | Rôle |
|---|---|---|---|
| `POST` | `/api/auth/login` | Public | Vérifie e-mail et mot de passe, pose le cookie, renvoie `csrf_token` et la session (`role`, `user`, `organization`). |
| `POST` | `/api/auth/register` | Public | Crée un compte **employé** hors organisation et envoie un code OTP par e-mail. La session n'est ouverte qu'après vérification. |
| `POST` | `/api/auth/verify-email` | Public | Vérifie `{email, code}`. Le code expire après 10 minutes et est limité à 5 tentatives ; ouvre ensuite la session. |
| `POST` | `/api/auth/resend-verification` | Public | Renvoie un code OTP à `{email}` pour un compte non vérifié. |
| `GET` | `/api/auth/me` | Connecté | L'utilisateur courant. Le front l'appelle au chargement. |
| `GET` | `/api/auth/session` | Connecté | La session relue en base : `role`, `user`, `organization` (`null` pour un compte sans organisation). |
| `POST` | `/api/auth/logout` | Connecté | Révoque le JWT côté serveur et supprime le cookie. |

```bash
curl -i -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@gotham.gov", "password": "un mot de passe"}'
```

```http
HTTP/1.1 200 OK
set-cookie: jwt=eyJhbGciOiJIUzI1NiIs…; path=/; max-age=28800; HttpOnly; SameSite=Strict

{"data": {"csrf_token": "6KeGXn3aCMbz…", "role": "administrator", "user": {"id": 1, "username": "admin", "email": "admin@gotham.gov", "first_name": null, "last_name": null, "organization_id": null, "role": "administrator", "gender": null, "birth_date": null, "birth_place": null, "inserted_at": "…", "created_at": "…"}, "organization": null}}
```

| Réponse | Cause |
|---|---|
| `401` `{"errors": {"detail": "Invalid credentials"}}` | E-mail ou mot de passe incorrect, quel que soit le cas. |
| `401` `{"errors": {"detail": "Unauthorized"}}` | Sur une route protégée : cookie absent, JWT invalide, expiré ou révoqué, en-tête `X-CSRF-Token` absent ou différent, compte supprimé. |
| `403` `{"errors": {"detail": "Origine de la requête refusée."}}` | Requête d'écriture envoyée depuis un autre site. |
| `429` | Trop de tentatives ; réessayer après `Retry-After` secondes. |

### Côté navigateur

Le client HTTP du front (`src/services/http.js`) ajoute `X-CSRF-Token` à chaque appel et envoie le cookie (`credentials: 'same-origin'`). Sur un `401`, il efface la session locale et renvoie vers `/connexion`. La garde `router.beforeEach()` (`src/router/index.js`) appelle `GET /api/auth/me` au premier chargement, puis vérifie avant chaque page que l'utilisateur est connecté et que son rôle figure dans `meta.roles`.

!!! note "La garde de route n'est que du confort"
    N'importe qui peut appeler l'API avec curl ou Postman. Masquer une page ou un bouton ne protège rien : chaque route de l'API refait le contrôle.

**Cookie `Secure`.** Le cookie ne porte l'option `Secure` que si `COOKIE_SECURE=true`. Le serveur étant aujourd'hui servi en HTTP, l'option est désactivée par défaut : un navigateur refuse un cookie `Secure` sur HTTP. Activez-la dès que le site passe en HTTPS.

---

## 3. Rôles et permissions

Une permission combine un **rôle** (quel type d'action) et un **périmètre** (sur quelles données). Les rôles sont prédéfinis et en lecture seule : aucune route ne les crée ni ne les modifie.

| Rôle | Périmètre | En résumé |
|---|---|---|
| `employee` | Soi | Pointe, consulte ses heures et son profil. |
| `manager` | Soi + les membres des équipes qu'il **dirige** | Consulte et corrige les heures de son équipe. Pour ses propres heures, c'est un employé. |
| `administrator` | Son organisation | Comptes, rôles, équipes, heures, demandes d'adhésion de son organisation. |

**Les organisations sont étanches.** Aucun rôle n'atteint les données d'une autre organisation, quel que soit l'identifiant mis dans l'URL. Les comptes sans organisation (créés avant les organisations, ou par `/api/auth/register`) forment leur propre espace, lui aussi isolé. Un identifiant d'utilisateur hors de l'organisation, qu'il existe ailleurs ou non, donne la même réponse `403` : on ne peut pas sonder quels identifiants existent.

**Données personnelles.** Genre, date et lieu de naissance ne sont renvoyés qu'à l'utilisateur lui-même et aux administrateurs de son organisation, jamais à un manager.

Être manager suppose deux conditions : avoir le rôle `manager` **et** être désigné manager d'une équipe (`teams.manager_id`). Être simple membre d'une équipe ne donne aucun droit sur les autres membres.

### Matrice par route

| Route | Employé | Manager | Administrateur |
|---|---|---|---|
Dans ce tableau, « Organisation » désigne l'organisation de l'administrateur.

| Route | Employé | Manager | Administrateur |
|---|---|---|---|
| `GET /api/users` | `403` | Soi + équipe | Organisation |
| `GET /api/users/:id` | Soi | Soi + équipe | Organisation |
| `POST /api/users` | `403` | `403` | Oui, dans son organisation |
| `PUT /api/users/:id` | Soi | Soi | Organisation |
| `PUT /api/users/:id/role` | `403` | `403` | Organisation, sauf soi-même |
| `DELETE /api/users/:id` | `403` | `403` | Organisation, sauf le dernier administrateur |
| `GET /api/roles` | Oui | Oui | Oui |
| `GET /api/teams` | Ses équipes (noms seuls) | Ses équipes, avec membres | Celles de l'organisation |
| `POST/PUT/DELETE /api/teams…` | `403` | `403` | Organisation |
| `GET /api/clocks/:userID` | Soi | Soi + équipe | Organisation |
| `POST /api/clocks/:userID` | Soi | Soi | Soi |
| `GET /api/workingtime/:userID[/:id]` | Soi | Soi + équipe | Organisation |
| `POST /api/workingtime/:userID` | `403` | Équipe, pas soi | Organisation |
| `PUT/DELETE /api/workingtime/:id` | `403` | Équipe, pas soi | Organisation |

### Organisations et demandes d'adhésion

Ces routes suivent le contrat [CONTRAT_BACKEND_ORGANISATIONS.md](CONTRAT_BACKEND_ORGANISATIONS.md) (corps et réponses détaillés en section 5). Les erreurs `404`, `403` et `409` portent un message affichable dans `errors.detail` ; un `409` nomme aussi le champ en cause (`name`, `email`).

| Méthode | Route | Accès | Effet |
|---|---|---|---|
| `POST` | `/api/organizations` | Public | Crée l'organisation et son administrateur, ouvre sa session (`201` + cookie + `csrf_token`). `409` si le nom (casse, accents et espaces ignorés) ou l'e-mail est déjà pris. |
| `GET` | `/api/organizations/lookup?name=…` | Public | `{id, name}` du nom exact normalisé, sinon `404`. |
| `POST` | `/api/join-requests` | Public | Demande en attente, sans compte ni mot de passe ; renvoie une référence privée. `409` si l'e-mail a déjà un compte ou une demande en attente. |
| `POST` | `/api/join-requests/status` | Public | Statut et motif de refus à partir de la référence, jamais le profil. |
| `GET` | `/api/organizations/:org_id/join-requests` | Admin de `:org_id` | Les demandes, sans leur référence. |
| `POST` | `/api/organizations/:org_id/join-requests/:id/approve` | Admin de `:org_id` | Crée l'employé avec le mot de passe choisi par l'admin, en une transaction. `409` si déjà traitée. |
| `POST` | `/api/organizations/:org_id/join-requests/:id/reject` | Admin de `:org_id` | Refus avec un motif de 1 à 500 caractères. `409` si déjà traitée. |
| `GET` | `/api/organizations/:org_id/members` | Admin de `:org_id` | Les membres, avec leurs données personnelles. |
| `PATCH` | `/api/organizations/:org_id/members/:id` | Admin de `:org_id` | `employee` ou `manager` uniquement ; jamais sur un administrateur (`403`). |

Le `:org_id` de l'URL n'est jamais cru sur parole : s'il n'est pas l'organisation de l'administrateur connecté, la réponse est `403`, que l'organisation existe ou non.

**Nom du rôle administrateur.** L'API renvoie `administrator` partout, y compris dans la session. La maquette front du contrat attend `admin` dans `session.role` (`organizationService.js`, `sessionResult`) : ce test doit accepter `administrator` au raccordement.

### Règles de sécurité appliquées

| Règle | Ce qu'elle empêche |
|---|---|
| Le `:userID` de l'URL est toujours comparé à l'utilisateur connecté et à son périmètre. | Lire les heures d'un collègue en changeant un chiffre dans l'URL (IDOR). |
| `PUT` et `DELETE /api/workingtime/:id` chargent d'abord la période pour connaître son propriétaire. | Contourner le contrôle avec une route qui ne nomme que la ressource. |
| `GET /api/workingtime/:userID/:id` vérifie que la période appartient à `:userID`. | Lire la période d'un autre en mettant son propre identifiant dans l'URL. |
| `PUT /api/users/:id` ne lit que `username`, `email` et `password`. Le rôle a sa propre route. | Se promouvoir en ajoutant `"role": "administrator"` au formulaire de profil (*mass assignment*). |
| Changer son propre mot de passe exige `current_password`. | Prendre le contrôle d'un compte avec une session volée. |
| Personne ne change son propre rôle ; le dernier administrateur d'une organisation ne peut être ni rétrogradé ni supprimé (`409`). | L'auto-promotion, et le blocage définitif de l'administration. |
| Le manager et les membres d'une équipe appartiennent à l'organisation de l'équipe. | Rattacher un inconnu à son équipe pour lire ses heures. |
| La référence de suivi d'une demande est aléatoire (32 octets), envoyée dans le corps et stockée hachée (SHA-256). | La deviner, la retrouver dans des logs d'URL ou dans une fuite de la base. |
| Un manager ne crée ni ne corrige ses propres heures. | Valider soi-même ses heures. |
| Seul l'administrateur compose les équipes et nomme les managers. | Qu'un manager s'ouvre l'accès aux heures de quelqu'un en l'ajoutant à son équipe. |
| Chacun pointe pour soi uniquement. | Les pointages fictifs pour le compte d'un autre. |

---

## 4. Conventions communes

**Format.** Les requêtes et les réponses sont en JSON. Les requêtes avec un corps doivent envoyer l'en-tête `Content-Type: application/json`.

**Corps de requête enveloppé.** Les attributs d'une ressource sont placés sous une clé qui porte son nom :

| Ressource | Clé | Exemple |
|---|---|---|
| Utilisateur | `user` | `{"user": {"username": "alice", "email": "alice@gotham.gov"}}` |
| Équipe | `team` | `{"team": {"name": "Voirie nuit", "manager_id": 2}}` |
| Pointage | `clock` | `{"clock": {"time": "2026-09-23T08:00:00Z", "status": true}}` |
| Temps de travail | `workingtime` | `{"workingtime": {"start": "...", "end": "..."}}` |

Exceptions : la connexion (`{"email", "password"}`), le changement de rôle (`{"role": "manager"}`) et l'ajout de membre (`{"user_id": 3}`). Pour les temps de travail, l'enveloppe est facultative.

**Réponses enveloppées.** Une réponse réussie place toujours son contenu sous `data` : un objet pour une ressource, un tableau pour une liste. Un utilisateur est toujours rendu ainsi, sans jamais son mot de passe ni son hash :

```json
{ "data": { "id": 1, "username": "alice", "email": "alice@gotham.gov", "role": "employee", "inserted_at": "2026-09-23T07:55:12Z" } }
```

**Identifiants.** Les identifiants (`id`, `userID`) sont des entiers positifs. Un identifiant non numérique (`/api/users/abc`) est traité comme un identifiant inexistant : la réponse est `404`.

**E-mails.** Format `X@X.X`, uniques sans tenir compte de la casse, et enregistrés en minuscules.

**Dates.** Toutes les dates sont en UTC, à la seconde près.

- *En entrée*, elles suivent le format ISO 8601 : `2026-09-23T08:00:00Z`. Une date avec décalage horaire (`2026-09-23T10:00:00+02:00`) est convertie en UTC.
- *En sortie*, le format dépend de la ressource : ISO 8601 avec `Z` pour les utilisateurs et les pointages (`2026-09-23T08:00:00Z`), mais `AAAA-MM-JJ HH:MM:SS`, sans fuseau, pour les temps de travail (`2026-09-23 08:00:00`). Les deux sont en UTC.

**Codes de statut.**

| Code | Signification | Corps |
|---|---|---|
| `200 OK` | Lecture ou modification réussie | `{"data": ...}` |
| `201 Created` | Ressource créée | `{"data": ...}` |
| `204 No Content` | Suppression ou déconnexion réussie | vide |
| `400 Bad Request` | Corps sans la clé attendue, ou filtre de date illisible | `{"errors": {"detail": "..."}}` |
| `401 Unauthorized` | Pas de session valide : le front renvoie vers la connexion | `{"errors": {"detail": "Unauthorized"}}` |
| `403 Forbidden` | Session valide, mais hors des droits de l'appelant | `{"errors": {"detail": "Forbidden"}}` |
| `404 Not Found` | Ressource ou utilisateur inexistant | `{"errors": {"detail": "Not Found"}}` |
| `409 Conflict` | Rétrograder ou supprimer le dernier administrateur | `{"errors": {"detail": "..."}}` |
| `422 Unprocessable Entity` | Données refusées par la validation | `{"errors": {"champ": ["message", ...]}}` |

---

## 5. Modèle de données

```text
┌───────────┐ 1   n ┌─────────────────┐ 1   n ┌──────────────┐
│ roles     │──────▶│ users           │──────▶│ clocks       │
│───────────│       │─────────────────│       │──────────────│
│ id        │       │ id              │       │ time, status │
│ name      │       │ username        │       │ user_id      │
└───────────┘       │ email (unique)  │       └──────────────┘
                    │ password_hash   │ 1   n ┌──────────────┐
                    │ role_id         │──────▶│ workingtime  │
                    └─────────────────┘       │──────────────│
                       │ 1          │ n       │ start, end   │
                 dirige│            │membre   │ user_id      │
                       ▼ n          ▼ n       └──────────────┘
                    ┌──────────────┐  ┌──────────────────┐
                    │ teams        │◀─│ team_members     │
                    │──────────────│  │──────────────────│
                    │ name         │  │ team_id, user_id │
                    │ manager_id   │  └──────────────────┘
                    └──────────────┘
```

| Table | Rôle | Règles |
|---|---|---|
| `roles` | Les trois rôles prédéfinis. | Insérés par les migrations et le seed ; lecture seule. |
| `users` | Un compte. | `username`, `email` et mot de passe obligatoires à la création. Le mot de passe n'est stocké que haché. |
| `teams` | Une équipe. | Nom unique ; `manager_id` doit désigner un utilisateur `manager` ou `administrator`. |
| `team_members` | L'appartenance. | Un employé peut appartenir à plusieurs équipes. |
| `clocks` | Un pointage : `status: true` pour une arrivée, `false` pour un départ. | Arrivées et départs alternent. Supprimés avec leur utilisateur. |
| `workingtime` | Une période de travail. | `end` strictement après `start`. Supprimée avec son utilisateur. |

**Lien entre pointages et temps de travail.** Un départ ferme l'arrivée précédente : l'API crée alors, dans la même transaction, un temps de travail qui va de l'heure d'arrivée à l'heure de départ.

---

## 6. Utilisateurs — `/api/users`

| Méthode | Route | Action |
|---|---|---|
| `GET` | `/api/users` | Lister les utilisateurs visibles, avec filtres `email` et `username` facultatifs |
| `POST` | `/api/users` | Créer un compte (administrateur) |
| `GET` | `/api/users/:id` | Lire un utilisateur |
| `PUT` / `PATCH` | `/api/users/:id` | Modifier un profil ou un mot de passe |
| `PUT` | `/api/users/:id/role` | Promouvoir ou rétrograder (administrateur) |
| `DELETE` | `/api/users/:id` | Supprimer un compte (administrateur) |

**Lister.** Le résultat est limité au périmètre : tout le monde pour un administrateur, le manager et les membres de ses équipes pour un manager. Un employé reçoit `403`. Les filtres `?email=` et `?username=` s'appliquent à l'intérieur de ce périmètre.

**Créer (administrateur).** Le corps accepte `username`, `email`, `password` et `role` (par défaut `employee`).

```json
{ "user": { "username": "lucie", "email": "lucie@gotham.gov", "password": "mot de passe provisoire", "role": "manager" } }
```

**Modifier.** Soi-même, ou n'importe qui pour un administrateur. Seuls `username`, `email` et `password` sont lus ; un champ omis garde sa valeur.

| Cas | Corps |
|---|---|
| Profil | `{"user": {"username": "alice.martin"}}` |
| Son propre mot de passe | `{"user": {"password": "nouveau mot de passe", "current_password": "ancien"}}` ; `422` `{"errors": {"current_password": ["is not valid"]}}` si l'ancien est faux. |
| Réinitialisation par un administrateur | `{"user": {"password": "mot de passe provisoire"}}`, sans `current_password`. |

Profil et mot de passe sont enregistrés dans une même transaction : si l'un est refusé, rien n'est modifié.

**Changer le rôle (administrateur).** `PUT /api/users/:id/role` avec `{"role": "manager"}`. L'effet est immédiat, puisque le rôle est relu à chaque requête. Erreurs : `403` sur soi-même, `422` pour un rôle inconnu, `409` pour le dernier administrateur.

**Supprimer (administrateur).** `DELETE /api/users/:id` renvoie `204`. Les pointages et temps de travail de la personne sont supprimés avec elle. Le dernier administrateur ne peut pas être supprimé (`409`).

---

## 7. Équipes et rôles — `/api/teams`, `/api/roles`

| Méthode | Route | Accès | Action |
|---|---|---|---|
| `GET` | `/api/roles` | Connecté | Les rôles, en lecture seule. |
| `GET` | `/api/teams` | Connecté | Les équipes visibles (voir la [matrice](#matrice-par-route)). |
| `GET` | `/api/teams/:id` | Manager de l'équipe, administrateur | Une équipe, son manager et ses membres. |
| `POST` | `/api/teams` | Administrateur | `{"team": {"name": "...", "manager_id": 2}}` |
| `PUT` | `/api/teams/:id` | Administrateur | Renommer, changer ou retirer le manager (`"manager_id": null`). |
| `DELETE` | `/api/teams/:id` | Administrateur | Supprimer l'équipe (pas ses membres). |
| `POST` | `/api/teams/:id/members` | Administrateur | `{"user_id": 3}` |
| `DELETE` | `/api/teams/:id/members/:user_id` | Administrateur | Retirer un membre. |

```json
{
  "data": {
    "id": 1,
    "name": "Voirie nuit",
    "manager": { "id": 2, "username": "lucie", "role": "manager", "...": "..." },
    "members": [ { "id": 3, "username": "emma", "role": "employee", "...": "..." } ]
  }
}
```

Un `manager_id` qui ne désigne pas un manager ou un administrateur est refusé : `422` `{"errors": {"manager_id": ["must have the manager role"]}}`.

---

## 8. Pointages — `/api/clocks`

| Méthode | Route | Accès | Action |
|---|---|---|---|
| `GET` | `/api/clocks/:userID` | Soi, son manager, administrateur | Les pointages, du plus ancien au plus récent. |
| `POST` | `/api/clocks/:userID` | **Soi uniquement** | Enregistrer une arrivée ou un départ. |

```json
{ "clock": { "time": "2026-09-23T08:00:00Z", "status": true } }
```

Le dernier pointage donne l'état actuel : `status: true`, la personne est arrivée ; `status: false` ou liste vide, elle n'est pas pointée.

**Règles de validation.**

| Situation | Réponse |
|---|---|
| `:userID` n'est pas l'utilisateur connecté | `403` |
| Premier pointage, et c'est une arrivée | `201` |
| Premier pointage, et c'est un départ | `422` `{"errors": {"status": ["must record an arrival before a departure"]}}` |
| Même statut que le pointage précédent | `422` `{"errors": {"status": ["must alternate arrivals and departures"]}}` |
| Heure antérieure au pointage précédent | `422` `{"errors": {"time": ["must not precede the latest clock event"]}}` |
| Départ à la même heure exacte que l'arrivée | `422` `{"errors": {"end": ["must be after start"]}}` |
| Clé `clock` absente | `400` |

Un départ et le temps de travail qu'il crée sont écrits dans une même transaction, et la ligne de l'utilisateur est verrouillée (`SELECT ... FOR UPDATE`) : deux clics simultanés ne créent pas deux arrivées de suite.

---

## 9. Temps de travail — `/api/workingtime`

| Méthode | Route | Accès | Action |
|---|---|---|---|
| `GET` | `/api/workingtime/:userID` | Soi, son manager, administrateur | Lister, avec filtres `start` et `end` facultatifs. |
| `GET` | `/api/workingtime/:userID/:id` | Idem | Lire une période ; elle doit appartenir à `:userID`, sinon `404`. |
| `POST` | `/api/workingtime/:userID` | Manager (son équipe, pas soi), administrateur | Créer une période. |
| `PUT` | `/api/workingtime/:id` | Idem, d'après le propriétaire de la période | Corriger `start`, `end` ou les deux. |
| `DELETE` | `/api/workingtime/:id` | Idem | Supprimer. |

Un employé ne modifie pas ses heures : les périodes viennent de ses pointages, et une erreur est corrigée par son manager. C'est ce qui rend le contrôle de présence fiable.

| Paramètre de requête | Effet |
|---|---|
| `start` | Ne garde que les périodes qui commencent à cette date ou après. |
| `end` | Ne garde que les périodes qui finissent à cette date ou avant. |

```json
{ "data": [ { "id": 1, "start": "2026-09-23 08:00:00", "end": "2026-09-23 12:00:00", "user_id": 3 } ] }
```

Erreurs : `422` `{"errors": {"end": ["must be after start"]}}`, `400` pour un filtre de date illisible, `404` pour une période ou un utilisateur inexistant.

---

## 10. Scénario complet avec curl

Une journée de travail de bout en bout. `-c`/`-b` gardent le cookie dans un fichier, comme le ferait le navigateur, et `jq` extrait les valeurs.

```bash
API=http://localhost:4000/api
JAR=$(mktemp)

# 1. Se connecter : le cookie jwt va dans $JAR, le token CSRF dans $CSRF
CSRF=$(curl -s -c $JAR -X POST $API/auth/login -H "Content-Type: application/json" \
  -d '{"email": "emma@gotham.gov", "password": "son mot de passe"}' | jq -r '.data.csrf_token')
ME=$(curl -s -b $JAR -H "X-CSRF-Token: $CSRF" $API/auth/me | jq '.data.id')

# 2. Arrivée à 8 h, départ à 12 h
curl -s -b $JAR -H "X-CSRF-Token: $CSRF" -H "Content-Type: application/json" \
  -X POST $API/clocks/$ME -d '{"clock": {"time": "2026-09-23T08:00:00Z", "status": true}}'
curl -s -b $JAR -H "X-CSRF-Token: $CSRF" -H "Content-Type: application/json" \
  -X POST $API/clocks/$ME -d '{"clock": {"time": "2026-09-23T12:00:00Z", "status": false}}'

# 3. Le départ a créé la période 08:00 → 12:00
curl -s -b $JAR -H "X-CSRF-Token: $CSRF" $API/workingtime/$ME | jq

# 4. Sans le token CSRF, le cookie seul ne suffit pas : 401
curl -s -b $JAR $API/auth/me

# 5. Les heures d'un collègue : 403
curl -s -b $JAR -H "X-CSRF-Token: $CSRF" $API/workingtime/1

# 6. Se déconnecter
curl -s -b $JAR -c $JAR -H "X-CSRF-Token: $CSRF" -X POST $API/auth/logout
```

---

## 11. Limites connues

| Limite | Conséquence | Piste |
|---|---|---|
| Les compteurs de tentatives (`429`) sont en mémoire et propres au serveur. | Ils repartent de zéro au redémarrage et ne sont pas partagés entre plusieurs instances. | Stockage partagé (Redis, ou PostgreSQL) si l'API passe à plusieurs instances. |
| Derrière Nginx, toutes les requêtes ont l'adresse IP du proxy. | Les seuils « par IP » s'appliquent à tous les clients ensemble ; ils sont donc larges. Le seuil par e-mail de la connexion, lui, reste efficace. | Lire `X-Real-IP` posé par Nginx, à condition que le port 4000 ne soit plus exposé directement. |
| `/api/auth/register` crée encore un compte actif hors organisation. | On peut ouvrir un compte sans validation, isolé de toute organisation. | Le supprimer une fois le front passé au circuit organisations. |
| `COOKIE_SECURE` désactivé tant que le site est en HTTP. | Le cookie peut circuler en clair sur le réseau. | Passer en HTTPS (reverse proxy) puis `COOKIE_SECURE=true`. |
| `time` du pointage fourni par le client. | Un client peut pointer à une heure arbitraire. | Utiliser l'heure du serveur, ou borner l'écart accepté. |
| Pas de validation mensuelle ni de journal d'audit. | Une période corrigée par un manager ne garde pas la trace de l'auteur. | Champs `created_by`/`validated_by` et table d'audit. |
| Formats de date différents en sortie. | Les temps de travail sont renvoyés sans `T` ni `Z`. | Renvoyer partout de l'ISO 8601. |
| Temps de travail qui se chevauchent acceptés. | Les totaux d'heures peuvent compter deux fois la même plage. | Contrainte d'exclusion PostgreSQL. |
