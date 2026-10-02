# API du Time Manager

L'API REST du Time Manager gère trois ressources : les **utilisateurs**, leurs **pointages** (arrivées et départs) et leurs **temps de travail** (périodes avec un début et une fin). Elle est écrite en Elixir avec Phoenix, et stocke ses données dans PostgreSQL.

## Sommaire

1. [Accéder à l'API](#1-acceder-a-lapi)
2. [Conventions communes](#2-conventions-communes)
3. [Modèle de données](#3-modele-de-donnees)
4. [Utilisateurs — `/api/users`](#4-utilisateurs-apiusers)
5. [Pointages — `/api/clocks`](#5-pointages-apiclocks)
6. [Temps de travail — `/api/workingtime`](#6-temps-de-travail-apiworkingtime)
7. [Scénario complet avec curl](#7-scenario-complet-avec-curl)
8. [Limites connues](#8-limites-connues)

---

## 1. Accéder à l'API

| Contexte | URL de base |
|---|---|
| Développement local (`mix phx.server` ou `docker compose up`) | `http://localhost:4000/api` |
| Serveur, accès direct au backend | `http://IP:4000/api` |
| Serveur, via le frontend | `http://IP:8080/api` |

Le frontend n'appelle pas le port 4000 : son Nginx relaie toutes les requêtes `/api/...` vers le conteneur `phoenix` (`proxy_pass http://phoenix:4000/api/`). Pour le navigateur, l'API a donc la même origine que l'application, et aucune configuration CORS n'est nécessaire.

**Documentation interactive.** Le backend génère lui-même sa spécification OpenAPI à partir des contrôleurs, avec la bibliothèque OpenApiSpex :

| URL | Contenu |
|---|---|
| `/swaggerui` | Swagger UI : la liste des routes, avec un bouton *Try it out* pour envoyer de vraies requêtes. |
| `/api/openapi` | La spécification OpenAPI au format JSON, à importer dans Postman, Insomnia ou un générateur de client. |

!!! warning "Pas d'authentification"
    Aucune route n'est protégée : n'importe qui peut lire, créer, modifier ou supprimer n'importe quelle donnée. L'identifiant de l'utilisateur est passé dans l'URL, et l'API ne vérifie pas que l'appelant est bien cet utilisateur. Voir [Limites connues](#8-limites-connues).

---

## 2. Conventions communes

**Format.** Les requêtes et les réponses sont en JSON. Les requêtes avec un corps doivent envoyer l'en-tête `Content-Type: application/json`.

**Corps de requête enveloppé.** Les attributs d'une ressource sont placés sous une clé qui porte son nom :

| Ressource | Clé | Exemple |
|---|---|---|
| Utilisateur | `user` | `{"user": {"username": "alice", "email": "alice@example.com"}}` |
| Pointage | `clock` | `{"clock": {"time": "2026-09-23T08:00:00Z", "status": true}}` |
| Temps de travail | `workingtime` | `{"workingtime": {"start": "...", "end": "..."}}` |

Pour les temps de travail seulement, l'enveloppe est facultative : `{"start": "...", "end": "..."}` est aussi accepté.

**Réponses enveloppées.** Une réponse réussie place toujours son contenu sous `data` : un objet pour une ressource, un tableau pour une liste.

```json
{ "data": { "id": 1, "username": "alice", "email": "alice@example.com" } }
```

**Identifiants.** Les identifiants (`id`, `userID`) sont des entiers positifs. Un identifiant non numérique (`/api/users/abc`) est traité comme un identifiant inexistant : la réponse est `404`.

**Dates.** Toutes les dates sont en UTC, à la seconde près.

- *En entrée*, elles suivent le format ISO 8601 : `2026-09-23T08:00:00Z`. Une date avec décalage horaire (`2026-09-23T10:00:00+02:00`) est convertie en UTC.
- *En sortie*, le format dépend de la ressource : ISO 8601 avec `Z` pour les utilisateurs et les pointages (`2026-09-23T08:00:00Z`), mais `AAAA-MM-JJ HH:MM:SS`, sans fuseau, pour les temps de travail (`2026-09-23 08:00:00`). Les deux sont en UTC.

**Codes de statut.**

| Code | Signification | Corps |
|---|---|---|
| `200 OK` | Lecture ou modification réussie | `{"data": ...}` |
| `201 Created` | Ressource créée. Pour un utilisateur et un temps de travail, l'en-tête `Location` donne son URL. | `{"data": ...}` |
| `204 No Content` | Suppression réussie | vide |
| `400 Bad Request` | Corps sans la clé attendue, ou filtre de date illisible | `{"errors": {"detail": "..."}}` |
| `404 Not Found` | Ressource ou utilisateur inexistant | voir ci-dessous |
| `422 Unprocessable Entity` | Données refusées par la validation | `{"errors": {"champ": ["message", ...]}}` |

**Formats d'erreur.** Deux formats coexistent :

```jsonc
// Erreurs de validation (422) : un tableau de messages par champ
{ "errors": { "email": ["can't be blank"], "end": ["must be after start"] } }

// Autres erreurs (400, 404) sur les pointages et les temps de travail
{ "errors": { "detail": "Not Found" } }
```

Les routes `GET`, `PUT` et `DELETE /api/users/:id` renvoient leur `404` dans un troisième format : `{"error": "User not found"}` pour `GET`, `{"error": "Utilisateur non trouvé"}` pour `PUT` et `DELETE`. Un client robuste doit se fier au **code de statut**, pas au corps.

---

## 3. Modèle de données

```text
┌──────────────────┐          ┌────────────────────┐
│ users            │ 1      n │ clocks             │
│──────────────────│─────────▶│────────────────────│
│ id               │          │ id                 │
│ username         │          │ time      (UTC)    │
│ email            │          │ status    (bool)   │
│ inserted_at      │          │ user_id            │
│ updated_at       │          └────────────────────┘
│                  │ 1      n ┌────────────────────┐
│                  │─────────▶│ workingtime        │
└──────────────────┘          │────────────────────│
                              │ id                 │
                              │ start     (UTC)    │
                              │ end       (UTC)    │
                              │ user_id            │
                              └────────────────────┘
```

| Table | Rôle | Règles |
|---|---|---|
| `users` | Un employé. | `username` et `email` obligatoires. Aucune contrainte d'unicité, aucun contrôle du format de l'email. |
| `clocks` | Un pointage : `status: true` pour une arrivée, `false` pour un départ. | Arrivées et départs doivent alterner, et ne peuvent pas remonter avant le dernier pointage. |
| `workingtime` | Une période de travail. | `end` strictement après `start`, vérifié par l'application et par une contrainte `CHECK` de la base. Supprimée automatiquement avec son utilisateur. |

**Lien entre pointages et temps de travail.** Un départ ferme l'arrivée précédente : l'API crée alors, dans la même transaction, un temps de travail qui va de l'heure d'arrivée à l'heure de départ. Les temps de travail peuvent aussi être créés directement, sans pointage.

```text
POST clock {status: true,  time: 08:00}  → pointage enregistré
POST clock {status: false, time: 12:00}  → pointage enregistré
                                         + temps de travail 08:00 → 12:00
```

---

## 4. Utilisateurs — `/api/users`

| Méthode | Route | Action |
|---|---|---|
| `GET` | `/api/users` | Lister les utilisateurs, avec filtres facultatifs |
| `POST` | `/api/users` | Créer un utilisateur |
| `GET` | `/api/users/:id` | Lire un utilisateur |
| `PUT` / `PATCH` | `/api/users/:id` | Modifier un utilisateur |
| `DELETE` | `/api/users/:id` | Supprimer un utilisateur |

### Lister les utilisateurs

`GET /api/users`

| Paramètre de requête | Effet |
|---|---|
| `email` | Ne garde que l'utilisateur dont l'email est exactement cette valeur. |
| `username` | Ne garde que l'utilisateur dont le nom est exactement cette valeur. |

Les deux filtres se combinent. Sans filtre, la route renvoie tous les utilisateurs.

```bash
curl "http://localhost:4000/api/users?email=alice@example.com"
```

```json
{
  "data": [
    { "id": 1, "username": "alice", "email": "alice@example.com", "inserted_at": "2026-09-23T07:55:12Z" }
  ]
}
```

Même filtrée, la réponse est une liste, éventuellement vide, jamais un `404`.

### Créer un utilisateur

`POST /api/users`

```bash
curl -X POST http://localhost:4000/api/users \
  -H "Content-Type: application/json" \
  -d '{"user": {"username": "alice", "email": "alice@example.com"}}'
```

Réponse `201 Created`, avec l'en-tête `Location: /api/users/1` :

```json
{ "data": { "id": 1, "username": "alice", "email": "alice@example.com" } }
```

La réponse de création ne contient pas `inserted_at`, contrairement aux autres routes.

| Erreur | Cause |
|---|---|
| `422` `{"errors": {"username": ["can't be blank"]}}` | `username` ou `email` absent ou vide |
| `400` `{"errors": {"detail": "Bad Request"}}` | Clé `user` absente du corps |

### Lire un utilisateur

`GET /api/users/:id`

```json
{ "data": { "id": 1, "username": "alice", "email": "alice@example.com", "inserted_at": "2026-09-23T07:55:12Z" } }
```

Erreur : `404` `{"error": "User not found"}`.

### Modifier un utilisateur

`PUT /api/users/:id` ou `PATCH /api/users/:id`, avec un corps `{"user": {...}}`. Un champ omis garde sa valeur ; les deux routes se comportent de la même façon.

```bash
curl -X PUT http://localhost:4000/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"user": {"username": "alice.martin"}}'
```

Réponse `200 OK` avec l'utilisateur modifié. Erreurs : `404` `{"error": "Utilisateur non trouvé"}`, `422` si un champ est vidé, `400` si la clé `user` manque.

### Supprimer un utilisateur

`DELETE /api/users/:id` renvoie `204 No Content`. Ses temps de travail sont supprimés avec lui.

!!! danger "Utilisateur avec des pointages"
    La clé étrangère `clocks.user_id` est déclarée `on_delete: :nothing` : la base refuse de supprimer un utilisateur qui a des pointages, et l'API ne traite pas ce refus. La requête aboutit alors à une erreur `500`, au lieu d'une suppression ou d'un message clair.

---

## 5. Pointages — `/api/clocks`

| Méthode | Route | Action |
|---|---|---|
| `GET` | `/api/clocks/:userID` | Lister les pointages d'un utilisateur |
| `POST` | `/api/clocks/:userID` | Enregistrer une arrivée ou un départ |

### Lister les pointages

`GET /api/clocks/:userID` renvoie les pointages de l'utilisateur, du plus ancien au plus récent.

```json
{
  "data": [
    { "id": 1, "time": "2026-09-23T08:00:00Z", "status": true,  "user_id": 1 },
    { "id": 2, "time": "2026-09-23T12:00:00Z", "status": false, "user_id": 1 }
  ]
}
```

Le dernier élément donne l'état actuel : `status: true`, l'utilisateur est arrivé ; `status: false` ou liste vide, il n'est pas pointé.

Erreur : `404` `{"errors": {"detail": "Not Found"}}` si l'utilisateur n'existe pas.

### Enregistrer un pointage

`POST /api/clocks/:userID`

| Champ | Type | Rôle |
|---|---|---|
| `time` | date ISO 8601 | Heure du pointage. Le client l'envoie : le serveur n'utilise pas sa propre horloge. |
| `status` | booléen | `true` pour une arrivée, `false` pour un départ. |

```bash
curl -X POST http://localhost:4000/api/clocks/1 \
  -H "Content-Type: application/json" \
  -d '{"clock": {"time": "2026-09-23T08:00:00Z", "status": true}}'
```

Réponse `201 Created` :

```json
{ "data": { "id": 1, "time": "2026-09-23T08:00:00Z", "status": true, "user_id": 1 } }
```

**Règles de validation.** L'API compare le nouveau pointage au dernier pointage de l'utilisateur :

| Situation | Réponse |
|---|---|
| Premier pointage, et c'est une arrivée | `201` |
| Premier pointage, et c'est un départ | `422` `{"errors": {"status": ["must record an arrival before a departure"]}}` |
| Même statut que le pointage précédent (deux arrivées de suite) | `422` `{"errors": {"status": ["must alternate arrivals and departures"]}}` |
| Heure antérieure au pointage précédent | `422` `{"errors": {"time": ["must not precede the latest clock event"]}}` |
| Départ à la même heure exacte que l'arrivée | `422` `{"errors": {"end": ["must be after start"]}}`, car la période créée aurait une durée nulle |
| `time` ou `status` absent ou illisible | `422` `{"errors": {"time": ["can't be blank"]}}` ou `["is invalid"]` |
| Clé `clock` absente | `400` `{"errors": {"detail": "Expected a JSON object under the clock key"}}` |
| Utilisateur inexistant | `404` `{"errors": {"detail": "Not Found"}}` |

**Départ et temps de travail.** Un départ valide crée aussi le temps de travail correspondant (voir [3](#3-modele-de-donnees)). Les deux enregistrements sont écrits dans une même transaction : si l'un échoue, aucun n'est gardé. La ligne de l'utilisateur est verrouillée pendant la transaction (`SELECT ... FOR UPDATE`) : deux clics simultanés sont traités l'un après l'autre et ne peuvent pas créer deux arrivées de suite.

---

## 6. Temps de travail — `/api/workingtime`

| Méthode | Route | Action |
|---|---|---|
| `GET` | `/api/workingtime/:userID` | Lister les temps de travail d'un utilisateur |
| `GET` | `/api/workingtime/:userID/:id` | Lire un temps de travail de cet utilisateur |
| `POST` | `/api/workingtime/:userID` | Créer un temps de travail |
| `PUT` | `/api/workingtime/:id` | Modifier un temps de travail |
| `DELETE` | `/api/workingtime/:id` | Supprimer un temps de travail |

Les routes de lecture et de création prennent l'identifiant de l'utilisateur ; la modification et la suppression ne prennent que l'identifiant du temps de travail.

### Lister les temps de travail

`GET /api/workingtime/:userID`, trié par heure de début croissante.

| Paramètre de requête | Effet |
|---|---|
| `start` | Ne garde que les périodes qui commencent à cette date ou après. |
| `end` | Ne garde que les périodes qui finissent à cette date ou avant. |

```bash
curl "http://localhost:4000/api/workingtime/1?start=2026-09-21T00:00:00Z&end=2026-09-28T00:00:00Z"
```

```json
{
  "data": [
    { "id": 1, "start": "2026-09-23 08:00:00", "end": "2026-09-23 12:00:00", "user_id": 1 }
  ]
}
```

Erreurs : `404` si l'utilisateur n'existe pas, `400` `{"errors": {"detail": "Bad Request"}}` si `start` ou `end` n'est pas une date lisible.

### Lire un temps de travail

`GET /api/workingtime/:userID/:id` renvoie `{"data": {...}}`. Le temps de travail doit appartenir à cet utilisateur, sinon la réponse est `404`.

### Créer un temps de travail

`POST /api/workingtime/:userID`

```bash
curl -X POST http://localhost:4000/api/workingtime/1 \
  -H "Content-Type: application/json" \
  -d '{"workingtime": {"start": "2026-09-22T08:00:00Z", "end": "2026-09-22T17:00:00Z"}}'
```

Réponse `201 Created`, avec l'en-tête `Location: /api/workingtime/1/2`.

| Erreur | Cause |
|---|---|
| `422` `{"errors": {"end": ["must be after start"]}}` | `end` égal ou antérieur à `start` |
| `422` `{"errors": {"start": ["can't be blank"]}}` | Champ absent ou illisible |
| `404` | Utilisateur inexistant |

L'API n'empêche pas deux périodes qui se chevauchent.

### Modifier un temps de travail

`PUT /api/workingtime/:id`, avec `start`, `end`, ou les deux. Un champ omis garde sa valeur, et la règle `end > start` est vérifiée sur le résultat. Réponse `200 OK`. Erreurs : `404`, `422`.

### Supprimer un temps de travail

`DELETE /api/workingtime/:id` renvoie `204 No Content`, ou `404`.

---

## 7. Scénario complet avec curl

Une journée de travail de bout en bout, à lancer sur une base locale. `jq` sert à extraire les valeurs des réponses.

```bash
API=http://localhost:4000/api

# 1. Créer l'utilisateur et récupérer son id
USER_ID=$(curl -s -X POST $API/users -H "Content-Type: application/json" \
  -d '{"user": {"username": "alice", "email": "alice@example.com"}}' | jq '.data.id')

# 2. Arrivée à 8 h, départ à 12 h
curl -s -X POST $API/clocks/$USER_ID -H "Content-Type: application/json" \
  -d '{"clock": {"time": "2026-09-23T08:00:00Z", "status": true}}'
curl -s -X POST $API/clocks/$USER_ID -H "Content-Type: application/json" \
  -d '{"clock": {"time": "2026-09-23T12:00:00Z", "status": false}}'

# 3. Le départ a créé la période 08:00 → 12:00
curl -s "$API/workingtime/$USER_ID" | jq

# 4. Un second départ est refusé (422)
curl -s -X POST $API/clocks/$USER_ID -H "Content-Type: application/json" \
  -d '{"clock": {"time": "2026-09-23T13:00:00Z", "status": false}}'
```

---

## 8. Limites connues

Ces points viennent de la lecture du code. Ils sont à corriger avant une mise en production.

| Limite | Conséquence | Piste |
|---|---|---|
| Aucune authentification ni autorisation | N'importe quel client peut lire, modifier ou supprimer les données de tous les utilisateurs, et pointer à leur place. | Authentification par token (JWT ou session Phoenix), puis vérifier que l'utilisateur du token correspond au `userID` de l'URL. |
| `time` du pointage fourni par le client | Un client peut pointer à une heure arbitraire, dans le futur par exemple. | Utiliser l'heure du serveur, ou borner l'écart accepté. |
| Suppression d'un utilisateur qui a des pointages | Erreur `500` (voir [4](#supprimer-un-utilisateur)). | Passer la clé étrangère de `clocks` en `on_delete: :delete_all`, ou renvoyer un `409` explicite. |
| Pas d'unicité ni de format pour l'email | Doublons possibles ; le filtre `?email=` peut renvoyer plusieurs utilisateurs. | `validate_format`, index unique et `unique_constraint`. |
| Formats d'erreur `404` différents selon les routes | Le client ne peut pas lire le message de façon uniforme, et la spécification OpenAPI annonce un format que `/api/users/:id` ne respecte pas. | Passer les routes utilisateur par le `FallbackController`. |
| Formats de date différents en sortie | Les temps de travail sont renvoyés sans `T` ni `Z`, contrairement aux pointages. | Renvoyer partout de l'ISO 8601. |
| Temps de travail qui se chevauchent acceptés | Les totaux d'heures peuvent compter deux fois la même plage. | Contrainte d'exclusion PostgreSQL, ou vérification dans `WorkingTimes`. |
