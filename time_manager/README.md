# TimeManager

API Phoenix (Elixir) pour la gestion des utilisateurs, de leurs pointages (clocks) et de leurs temps de travail (working times).

## Modèle de données

- **User** `has_many` **WorkingTime** et **Clock** (relations one-to-many, clé étrangère `user_id`).
- `workingtime.user_id` est en `ON DELETE CASCADE` : supprimer un user supprime ses working times.
- `clocks.user_id` est en `ON DELETE CASCADE` depuis la migration `20261004090200` : supprimer un user supprime aussi ses clocks. Il n'existe pas de route `DELETE` pour un clock individuel.

## Prérequis

- Elixir/Erlang (voir `mix.exs`, Elixir `~> 1.17`)
- PostgreSQL en local, accessible avec les identifiants par défaut (`postgres`/`postgres` sur `localhost`, voir `config/dev.exs` et `config/test.exs`). Surchargeable avec les variables d'env `DB_USER` / `DB_PASSWORD` en dev.
- `curl` et `jq` (pour les scripts de test manuels dans `scripts/`)

## Installation

```bash
mix setup
```

Ceci installe les dépendances, crée la base, joue les migrations et exécute `priv/repo/seeds.exs` (actuellement vide).

Pour repartir d'une base vide à tout moment :

```bash
mix ecto.reset
```

## Lancer le serveur

```bash
mix phx.server
# ou, dans une session IEx interactive :
iex -S mix phx.server
```

L'API est servie sur [http://localhost:4000](http://localhost:4000).

## Documentation de l'API (Swagger / OpenAPI)

La spec OpenAPI est générée automatiquement à partir des annotations `operation` de chaque contrôleur (voir `lib/time_manager_web/api_spec.ex`, `lib/time_manager_web/schemas/`, et `use OpenApiSpex.ControllerSpecs` dans les contrôleurs).

Une fois le serveur lancé :

- **Swagger UI** (interface interactive, testable directement dans le navigateur) : [http://localhost:4000/swaggerui](http://localhost:4000/swaggerui)
- **Spec brute (JSON)** : [http://localhost:4000/api/openapi](http://localhost:4000/api/openapi)

## Tester le projet

Il y a trois niveaux de tests, du plus rapide au plus complet.

### 1. Tests automatisés (ExUnit)

```bash
mix test
```

Crée/migre automatiquement la base de test (`time_manager_test`) avant de lancer la suite. Pour rejouer uniquement les tests en échec : `mix test --failed`.

Avant de livrer une modification, lancer aussi :

```bash
mix precommit
```

(compile avec `--warnings-as-errors`, nettoie les deps inutilisées, formatte, puis lance `mix test`).

### 2. Vérification manuelle des associations Ecto (sans serveur HTTP)

Pour vérifier que les relations `User -> WorkingTime` / `User -> Clock` fonctionnent au niveau base de données, sans polluer la base (tout est annulé via `Repo.rollback`) :

```bash
mix run -e '
alias TimeManager.Repo

Repo.transaction(fn ->
  {:ok, user} = TimeManager.Accounts.create_user(%{"username" => "assoc_test", "email" => "assoc_test@example.com"})
  {:ok, _wt} = TimeManager.WorkingTimes.create_working_time(user.id, %{"start" => "2026-09-23T08:00:00Z", "end" => "2026-09-23T17:00:00Z"})
  {:ok, _clock} = TimeManager.Clocks.create_clock(user, %{"time" => "2026-09-23T08:00:00Z", "status" => true})

  user = Repo.preload(user, [:working_times, :clocks])
  IO.inspect(user.working_times, label: "working_times")
  IO.inspect(user.clocks, label: "clocks")

  Repo.rollback(:discard_test_data)
end)
'
```

### 3. Tests HTTP de bout en bout (curl)

Démarrer le serveur dans un terminal :

```bash
mix phx.server
```

Puis, dans un autre terminal, lancer le script couvrant les **12 routes** de l'API avec leurs différents scénarios (cas valides, invalides, introuvables) :

```bash
./scripts/test_all_routes.sh
```

Ce script teste :

| Ressource     | Routes                                                                                    | Cas couverts                                                                                                                                                    |
| ------------- | ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Users         | `GET/POST /api/users`, `GET/PUT/DELETE /api/users/:id`                                     | création valide/invalide, liste avec/sans filtre, show existant/inexistant/id non numérique, update valide/invalide/inexistant, delete existant/déjà supprimé |
| Clocks        | `GET/POST /api/clocks/:userID`                                                              | création valide, clé `"clock"` manquante (400), attrs invalides (422), user inexistant/non numérique, liste existante/inexistante                              |
| Working Time  | `GET/POST /api/workingtime/:userID`, `GET/PUT/DELETE /api/workingtime/:id` (et `GET .../:userID/:id`) | création valide/`end<start`/attrs manquants/user inexistant, liste avec/sans filtre, show existant/inexistant, update valide/invalide/inexistant, delete existant/déjà supprimé |

À la fin, le script affiche un résumé `X réussi(s), Y échoué(s)`. Ces scripts historiques sont à vérifier avant utilisation avec l'authentification actuelle ; leurs anciennes notes sur l'impossibilité de supprimer un utilisateur ayant des clocks ne correspondent plus aux migrations.

D'autres scripts existent pour des tests ciblés :

- `./scripts/test_api.sh` — smoke test users + working time.
- `./test_users_api.sh` — CRUD users uniquement.

Optionnellement, on peut aussi explorer et exécuter les requêtes manuellement depuis [Swagger UI](http://localhost:4000/swaggerui) une fois le serveur démarré.

## Ready to run in production?

Voir le [guide de déploiement Phoenix](https://phoenix.hexdocs.pm/deployment.html).

## Pour aller plus loin

- Site officiel : [phoenixframework.org](https://www.phoenixframework.org/)
- Guides : [phoenix.hexdocs.pm/overview.html](https://phoenix.hexdocs.pm/overview.html)
- Docs : [phoenix.hexdocs.pm](https://phoenix.hexdocs.pm)
- Forum : [elixirforum.com/c/phoenix-forum](https://elixirforum.com/c/phoenix-forum)
- Source : [github.com/phoenixframework/phoenix](https://github.com/phoenixframework/phoenix)
