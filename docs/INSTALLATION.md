# Installation et environnement de développement

À la fin de ce guide, l'interface doit répondre sur `http://127.0.0.1:8080`, Phoenix sur `http://127.0.0.1:4000` et Mailpit sur `http://127.0.0.1:8025`.

Les étapes partent d'une copie neuve du dépôt et utilisent uniquement des valeurs locales. Ne placez jamais de secret réel dans un fichier versionné.

## Prérequis

=== "Avec Docker"

    - Git ;
    - Docker avec le plugin Compose ;
    - OpenSSL pour générer une clé locale.

=== "Sans Docker"

    - Elixir `~> 1.17` et Erlang/OTP compatible ;
    - PostgreSQL ;
    - Node `^22.18.0` ou `>=24.12.0` ;
    - npm ;
    - Python 3 pour MkDocs et les scripts de déploiement.

## Cloner et vérifier

```bash
git clone <URL_DU_DEPOT>
cd Theme_5_authentification_security
git status
```

`<URL_DU_DEPOT>` est volontairement un placeholder : l'URL canonique à communiquer à l'équipe doit être confirmée dans l'organisation GitHub.

## Lancement complet avec Docker

Docker est le chemin le plus proche de l'environnement partagé par l'équipe. Il lance le frontend, Phoenix, PostgreSQL et Mailpit avec une seule commande.

### 1. Préparer les variables locales

```bash
cp .env.example .env
umask 077
JWT_VALUE="$(openssl rand -base64 48 | tr -d '\n')"
python3 - "$JWT_VALUE" <<'PY'
from pathlib import Path
import sys

path = Path('.env')
lines = path.read_text().splitlines()
value = sys.argv[1]
updated = [f'JWT_SECRET={value}' if line.startswith('JWT_SECRET=') else line for line in lines]
path.write_text('\n'.join(updated) + '\n')
PY
unset JWT_VALUE
chmod 600 .env
```

La commande remplit seulement `JWT_SECRET`. Les paramètres PostgreSQL locaux du modèle peuvent rester ceux prévus pour le développement. `SECRET_KEY_BASE`, `DATABASE_URL` et `PHX_HOST` sont obligatoires en production, pas pour cette composition locale.

!!! tip "Contrôle rapide"
    Ouvrez `.env` et vérifiez seulement que la ligne `JWT_SECRET=` n'est plus vide. N'affichez pas sa valeur dans une capture d'écran ou dans un message d'équipe.

Pour créer un premier administrateur local, renseigner dans `.env` :

```env
ADMIN_EMAIL=<EMAIL_LOCAL_DE_TEST>
ADMIN_PASSWORD=<MOT_DE_PASSE_LOCAL_FORT>
```

!!! warning
    Le seed crée cet administrateur sans organisation. Le rattachement à une organisation dépend du scénario de test choisi. Ne présentez pas ce compte comme une configuration de production.

### 2. Construire et démarrer

```bash
docker compose up -d --build
docker compose ps
docker compose logs --tail=100 phoenix
```

L'entrypoint Phoenix attend PostgreSQL, crée la base si nécessaire, applique les migrations, exécute les seeds idempotents puis lance le serveur.

Si `docker compose ps` montre les quatre services en cours d'exécution et que les logs Phoenix contiennent l'écoute sur le port 4000, le démarrage est terminé. Vous pouvez ouvrir le dashboard dans le navigateur.

| Service | Adresse locale | Exposition |
|---|---|---|
| Dashboard | `http://127.0.0.1:8080` | Boucle locale uniquement |
| API Phoenix | `http://127.0.0.1:4000` | Boucle locale uniquement |
| Mailpit | `http://127.0.0.1:8025` | Boucle locale uniquement |
| PostgreSQL | `127.0.0.1:5433` par défaut | Boucle locale uniquement |

### 3. Arrêter

```bash
docker compose down
```

Les données restent dans le volume `db_data`. Pour supprimer aussi les données locales de test :

```bash
docker compose down -v
```

Cette dernière commande est destructive pour la base locale du projet Compose.

## Lancement sans Docker

Cette méthode est utile pour déboguer rapidement un composant. Elle demande que PostgreSQL, Elixir et Node soient déjà installés sur la machine.

### Backend

Créer une base PostgreSQL locale et exporter les paramètres adaptés :

```bash
cd time_manager
export PGUSER=<UTILISATEUR_POSTGRES_LOCAL>
export PGPASSWORD=<MOT_DE_PASSE_POSTGRES_LOCAL>
export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=time_manager_dev
export JWT_SECRET="$(openssl rand -base64 48 | tr -d '\n')"
mix deps.get
mix ecto.setup
mix phx.server
```

L'API écoute sur `http://localhost:4000` par défaut.

### Frontend

Dans un second terminal :

```bash
cd time-manager-dashboard
cp .env.auth.example .env.local
npm ci
npm run dev
```

Pour le backend local, vérifier dans `.env.local` :

```env
VITE_AUTH_USE_MOCK=false
VITE_USE_MOCK=false
VITE_API_URL=/api
VITE_BACKEND_URL=http://localhost:4000
```

Les variables `VITE_*` sont intégrées au code envoyé au navigateur : elles ne doivent contenir aucun secret.

## Migrations et seeds

Depuis `time_manager/` :

```bash
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

Réinitialisation complète de la base locale :

```bash
mix ecto.reset
```

`mix ecto.reset` supprime puis recrée la base configurée. Vérifier `PGHOST` et `PGDATABASE` avant de l'exécuter.

## Tests et builds

Les tests locaux donnent un retour rapide. Les commandes Docker isolées recréent un environnement propre et évitent qu'une ancienne base locale rende le résultat trompeur.

### Backend local

```bash
cd time_manager
export MIX_ENV=test
export JWT_SECRET="$(openssl rand -base64 48 | tr -d '\n')"
export PGHOST=localhost
mix test
mix precommit
```

`mix precommit` compile avec les avertissements transformés en erreurs, vérifie les dépendances inutilisées, formate et lance les tests. Le formatage peut modifier les fichiers : utiliser `mix format --check-formatted` pour un contrôle sans écriture.

### Frontend local

```bash
cd time-manager-dashboard
npm ci
npm run check
```

`npm run check` exécute ESLint, tous les tests Node puis le build Vite.

### Environnement Docker isolé

```bash
bash scripts/check_workflows.sh backend
bash scripts/check_workflows.sh frontend
```

Le script utilise le projet Compose `gotham-workflow-tests`, une base dédiée et supprime les conteneurs/volumes de test en sortie.
S'il ne reçoit pas déjà `JWT_SECRET`, il génère une clé éphémère en mémoire et la transmet au conteneur de test.

## Mode de démonstration

```bash
cd time-manager-dashboard
npm run dev:demo
```

Ce mode active explicitement les mocks uniquement pendant le serveur Vite de développement. `vite.config.js` refuse une compilation si `VITE_USE_MOCK=true` ou `VITE_AUTH_USE_MOCK=true`.

!!! warning
    Une démonstration mock ne valide ni Phoenix, ni PostgreSQL, ni les autorisations serveur.

## Documentation MkDocs

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
python -m pip install mkdocs-material==9.7.7
mkdocs serve
```

Validation stricte :

```bash
mkdocs build --strict
```

Le résultat statique est écrit dans `site/`, dossier ignoré par Git.

## Variables principales

| Variable | Dev | Test | Production | Rôle |
|---|---:|---:|---:|---|
| `JWT_SECRET` | obligatoire | obligatoire | obligatoire | Signature HS256 des JWT, 32 octets minimum, sans espaces. |
| `DATABASE_URL` | non | non | obligatoire | Connexion PostgreSQL complète. |
| `SECRET_KEY_BASE` | non | non | obligatoire | Secret Phoenix, 64 octets minimum. |
| `PHX_HOST` | non | non | obligatoire | Domaine public sans protocole, port ni chemin. |
| `TRUSTED_PROXY_IP` | non | non | obligatoire | IP interne du seul proxy autorisé. |
| `RESEND_API_KEY` | non | non | obligatoire avec Resend | Authentification du fournisseur de courriel. |
| `RESEND_FROM` | facultatif localement | non utilisé | obligatoire avec Resend | Expéditeur vérifié. |
| `DOCKER_USERNAME` / `IMAGE_TAG` | non | non | Compose prod | Image du registre et SHA testé. |
| `TLS_CERT_DIR` | non | non | Compose prod | Dossier contenant `fullchain.pem` et `privkey.pem`. |

Les modèles `.env.example` et `.env.production.example` contiennent des indications et des valeurs vides. Le fichier `.env` réel est ignoré par Git.
