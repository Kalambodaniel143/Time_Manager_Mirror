# Pipeline CI/CD du Time Manager — Travis CI & Docker

*Oct 2, 2026 · @KALAMBO DANIEL*

Un `git push` suffit à mettre en ligne la nouvelle version du Time Manager. Travis CI construit les images Docker, les publie sur Docker Hub, puis les fait démarrer sur le serveur via SSH.

## Sommaire

1. [Le but du CI/CD](#1-le-but-du-cicd)
2. [Du push au serveur : comment fonctionne le pipeline](#2-du-push-au-serveur-comment-fonctionne-le-pipeline)
3. [Les concepts clés à maîtriser](#3-les-concepts-cles-a-maitriser)
4. [Les fichiers du pipeline, ligne par ligne](#4-les-fichiers-du-pipeline-ligne-par-ligne)
5. [Roadmap pour refaire le projet](#5-roadmap-pour-refaire-le-projet)
6. [Le miroir GitHub Actions](#6-le-miroir-github-actions)

---

## 1. Le but du CI/CD

Le CI/CD remplace le déploiement à la main par une chaîne automatique, identique à chaque fois, déclenchée par un simple push.

Sans pipeline, mettre une version en ligne demande une suite d'opérations manuelles : connexion au serveur, récupération du code, compilation, redémarrage, migration de la base. Chaque étape peut être oubliée ou mal faite, et le résultat dépend de la personne qui déploie.

La **CI** (intégration continue) vérifie et construit automatiquement le code à chaque push, pour détecter les problèmes au plus tôt. Le **CD** a deux sens : en *livraison continue*, chaque version validée est prête à partir d'un geste ; en *déploiement continu*, elle part en production sans intervention. Le Time Manager fait du déploiement continu.

Ce que l'équipe y gagne :

- **Reproductibilité** : mêmes commandes, même résultat, à chaque déploiement.
- **Rapidité** : la version part en ligne dès la fin du build, sans que personne ne se connecte au serveur.
- **Traçabilité** : chaque déploiement correspond à un commit et à un log consultable sur Travis.
- **Secrets protégés** : mots de passe et clés vivent dans les réglages de Travis, jamais dans Git.

!!! warning "Limite actuelle"
    Le pipeline construit et déploie, mais n'exécute aucun test. La « CI » se résume donc à vérifier que le code compile et que les images se construisent ; un stage de tests est la première amélioration proposée en partie 5.

---

## 2. Du push au serveur : comment fonctionne le pipeline

Le code passe par quatre lieux : GitHub, deux machines virtuelles Travis éphémères, Docker Hub, puis le serveur. Le serveur ne compile jamais rien : il télécharge des images déjà construites et les lance.

```text
 git push
    │
    ▼
┌────────┐  webhook  ┌───────────────────────────┐  docker push  ┌────────────┐
│ GitHub │──────────▶│ Travis VM 1               │──────────────▶│ Docker Hub │
└────────┘           │ Stage 1 : Build & Push    │               └─────┬──────┘
                     └───────────────────────────┘                     │
                                 │ succès                              │ docker compose pull
                                 ▼                                     ▼
                     ┌───────────────────────────┐  scp + ssh    ┌────────────┐
                     │ Travis VM 2               │──────────────▶│  Serveur   │
                     │ Stage 2 : Deploy          │  3 fichiers   │ db·phoenix │
                     └───────────────────────────┘               │ ·dashboard │
                                                                 └────────────┘
```

Rien ne circule entre les deux VM Travis : les images passent par Docker Hub, et seuls trois fichiers de configuration arrivent sur le serveur par SSH.

**Le déclenchement.** Un membre de l'équipe pousse ses commits sur GitHub. GitHub prévient Travis CI, qui lit le `.travis.yml` du commit poussé et lance un build de deux stages, exécutés l'un après l'autre.

**Stage 1 — Build & Push Image.** Travis démarre une VM neuve, y clone le dépôt et lance Docker. Il se connecte à Docker Hub, construit l'image du backend (`time_manager/`) et celle du frontend (`time-manager-dashboard/`), puis pousse les deux avec le tag `latest`. La VM est ensuite détruite.

**Stage 2 — Deploy.** Il ne démarre que si le stage 1 a réussi. Une seconde VM clone à nouveau le dépôt, charge la clé SSH de déploiement et enregistre l'empreinte du serveur. Elle copie ensuite trois fichiers dans le dossier personnel de l'utilisateur distant, puis lance `deploy.sh` par SSH :

| Fichier envoyé | Nom sur le serveur | Contenu |
|---|---|---|
| `docker-compose.prod.yml` | `~/docker-compose.yml` | Les conteneurs à faire tourner et leur configuration |
| `.env.deploy`, généré pendant le job | `~/.env` | Les variables secrètes : base de données, compte Docker Hub |
| `deploy.sh` | `~/deploy.sh` | Le script qui installe Docker si besoin et relance l'application |

**Sur le serveur.** `deploy.sh` installe Docker s'il est absent, télécharge les nouvelles images (`docker compose pull`), puis recrée les conteneurs dont l'image a changé (`docker compose up -d`). Postgres démarre ; le conteneur `phoenix` attend qu'il soit prêt, applique les migrations et lance l'API. Le `dashboard` sert le frontend.

**Le résultat.** Le frontend répond sur le port **8080** du serveur, l'API sur le port **4000**. Les données de la base survivent aux déploiements grâce au volume `db_data`.

!!! tip "À retenir"
    Docker Hub sert de pont : les deux VM Travis et le serveur ne partagent aucun fichier, les images transitent par le registre. Les secrets suivent un chemin fermé, des variables Travis au `.env` du serveur, puis aux conteneurs ; ils n'apparaissent jamais dans Git.

---

## 3. Les concepts clés à maîtriser

Reproduire ce pipeline demande de comprendre trois mécanismes : l'organisation d'un build Travis, la connexion SSH au serveur, et le couple image Docker / Docker Compose.

### 3.1 Travis CI

**Le fichier `.travis.yml`.** Une fois le dépôt activé sur travis-ci.com, chaque push déclenche un build. Travis lit le `.travis.yml` à la racine du dépôt, tel qu'il est dans le commit poussé. Le pipeline est donc versionné avec le code : le modifier, c'est faire un commit.

**Build, stages et jobs.** Un build est découpé en *stages* exécutés l'un après l'autre ; chaque stage contient un ou plusieurs *jobs*, lancés en parallèle. Ici, deux stages d'un job chacun. Si un stage échoue, les suivants sont annulés : une image qui n'a pas pu être construite n'est jamais déployée.

**Chaque job part de zéro.** Un job tourne dans une machine virtuelle neuve, qui clone le dépôt puis est détruite. Rien ne passe d'un job à l'autre : les images construites au stage 1 n'existent plus au stage 2. D'où le passage par Docker Hub, et le second clonage qui fournit `deploy.sh` et le fichier compose au stage 2.

**Les phases d'un job.** Un job enchaîne des phases dans un ordre fixe : `before_install`, `install`, `before_script`, `script`, puis `after_success` ou `after_failure`, et `after_script`. Le pipeline n'utilise que `before_script` (préparer SSH) et `script` (le travail). Leur réaction à une erreur diffère, et c'est un piège classique :

| Phase | Si une commande échoue |
|---|---|
| `before_script` | Le job s'arrête aussitôt, avec le statut *errored*. |
| `script` | Les commandes suivantes s'exécutent quand même ; le job est marqué *failed* à la fin. |

Pour qu'une suite de commandes s'arrête à la première erreur, il faut les enchaîner avec `&&`, ou les regrouper dans un script qui commence par `set -e`, comme `deploy.sh`.

**`language` et `services`.** Les clés placées en haut du fichier s'appliquent à tous les jobs. `language: minimal` choisit une VM légère, sans environnement de langage préinstallé : inutile ici, toute la compilation se fait dans Docker. `services: docker` démarre le démon Docker dans la VM.

**Variables d'environnement et secrets.** Aucun secret n'est écrit dans le dépôt. Ils sont saisis dans *Settings → Environment Variables* du dépôt sur Travis, affichage dans les logs désactivé. Travis les exporte dans chaque job, et le fichier les lit avec `$NOM`.

| Variable | Utilisée par | Rôle |
|---|---|---|
| `DOCKER_USERNAME` | Stage 1, et `.env` du serveur | Compte Docker Hub ; sert aussi de préfixe aux noms d'images |
| `DOCKER_PASSWORD` | Stage 1 | Mot de passe Docker Hub (un access token est préférable) |
| `SSH_KEY` | Stage 2 | Clé privée de déploiement, encodée en base64 sur une ligne |
| `SERVER_IP` | Stage 2 | Adresse IP du serveur |
| `SERVER_USER` | Stage 2 | Utilisateur Linux du serveur, autorisé à `sudo` sans mot de passe |
| `PGUSER`, `PGPASSWORD`, `PGDATABASE` | Stage 2, via `.env` | Utilisateur, mot de passe et nom de la base Postgres |
| `PGPORT` | Stage 2, via `.env` | Port de Postgres publié sur le serveur (côté hôte) |

Trois pièges à connaître :

- Travis injecte chaque valeur telle quelle dans une commande `export` bash. Un caractère spécial (`$`, `&`, `!`, espace) doit être échappé avec `\`, ou la valeur entourée de guillemets simples.
- Une variable tient sur une seule ligne. La clé SSH, qui en compte plusieurs, est donc stockée encodée en base64.
- Ces variables ne sont pas transmises aux builds de pull requests venant d'un fork.

**SSH : comment Travis entre sur le serveur.** Le stage 2 utilise une paire de clés dédiée au déploiement. La clé publique est déposée dans `~/.ssh/authorized_keys` de `SERVER_USER` sur le serveur ; la clé privée est le secret `SSH_KEY`. Elle n'a pas de passphrase, puisque personne n'est là pour la taper.

| Outil | Rôle dans le pipeline |
|---|---|
| `ssh-agent` | Garde la clé privée en mémoire, sans l'écrire sur le disque de la VM. |
| `~/.ssh/known_hosts` | Liste les serveurs reconnus. Sans lui, la première connexion demande de confirmer l'empreinte du serveur, et un job automatique ne peut pas répondre. |
| `scp` | Copie des fichiers vers le serveur. |
| `ssh user@ip "commande"` | Exécute une commande sur le serveur et renvoie son code de sortie : si `deploy.sh` échoue, le job Travis échoue. |

### 3.2 Docker et Docker Compose

**Image et conteneur.** Une *image* est un paquet figé : système de base, dépendances et code compilé, construit à partir d'un `Dockerfile`. Un *conteneur* est une image en cours d'exécution, comme un objet est une instance de classe. La même image tourne à l'identique partout où Docker est installé (à architecture de processeur égale) : on peut donc construire sur Travis et exécuter sur le serveur.

**Couches et cache.** Chaque instruction du Dockerfile produit une couche. Docker réutilise une couche tant que ses entrées n'ont pas changé, d'où l'ordre du Dockerfile : dépendances d'abord, code ensuite. Sur Travis, la VM est neuve à chaque build : ce cache est vide et tout est reconstruit.

**Registre, nom et tag.** Docker Hub est un *registre* : il stocke des images comme GitHub stocke du code. Un nom complet suit la forme `compte/dépôt:tag`, par exemple `$DOCKER_USERNAME/time-manager-backend:latest`. `docker push` envoie l'image, `docker pull` la récupère ; `latest` n'est qu'un tag comme un autre, écrasé à chaque push.

Le serveur télécharge les images sans s'authentifier : les dépôts Docker Hub doivent donc être **publics**. Avec des dépôts privés, il faudrait ajouter un `docker login` dans `deploy.sh`.

**Docker Compose.** Compose décrit dans un fichier YAML plusieurs conteneurs qui fonctionnent ensemble, et les pilote d'une seule commande.

| Notion | Ce qu'elle fait | Dans ce projet |
|---|---|---|
| Réseau interne | Les services d'un même fichier se joignent par leur nom de service. | `phoenix` contacte la base à l'adresse `db`, port 5432. |
| `ports` hôte:conteneur | Publie un port du conteneur sur le serveur, joignable de l'extérieur. | `8080:80` pour le frontend, `4000:4000` pour l'API. |
| Volume nommé | Conserve des données quand le conteneur est recréé. | `db_data` garde le contenu de Postgres d'un déploiement à l'autre. |
| Bind mount | Monte un fichier du serveur dans le conteneur. | `./.env:/app/.env:ro`, en lecture seule. |
| `depends_on` | Fixe l'ordre de démarrage, sans attendre que le service soit prêt. | D'où la boucle d'attente de `entrypoint.sh`. |
| `restart: unless-stopped` | Relance le conteneur après un crash ou un redémarrage du serveur, sauf arrêt manuel. | Les trois services. |

**Trois façons de passer des variables.** Elles se ressemblent mais n'agissent pas au même endroit :

- `${VAR}` dans le fichier compose est remplacé par Compose lui-même, à partir du fichier `.env` du dossier courant. C'est ainsi que les images reçoivent leur nom complet.
- `env_file:` injecte toutes les lignes d'un fichier comme variables d'environnement du conteneur.
- `environment:` définit des variables du conteneur, prioritaires sur celles de `env_file`.

La commande `docker compose config` affiche le fichier après remplacement des variables : le moyen le plus simple de vérifier le résultat.

**Mettre à jour sans tout casser.** `docker compose pull` télécharge les nouvelles versions des images. `docker compose up -d` recrée seulement les conteneurs dont l'image ou la configuration a changé, en arrière-plan, et conserve les volumes.

**`ENTRYPOINT`, `exec` et PID 1.** Le processus lancé au démarrage d'un conteneur porte le numéro 1 : c'est lui qui reçoit le signal d'arrêt de `docker stop`. Avec `exec`, le script cède sa place à Phoenix, qui reçoit ce signal et s'arrête proprement. Sans `exec`, le signal n'atteint pas Phoenix, et Docker tue le conteneur après un délai de grâce (10 secondes par défaut).

---

## 4. Les fichiers du pipeline, ligne par ligne

Cinq fichiers font tout le travail ; ils sont présentés dans l'ordre où ils interviennent.

| Fichier | Emplacement dans le dépôt | Où il s'exécute | Quand |
|---|---|---|---|
| `.travis.yml` | racine | VM Travis | à chaque push |
| `Dockerfile` du backend | `time_manager/` | VM Travis, pendant `docker build` | stage 1 |
| `deploy.sh` | racine | serveur, lancé par SSH | fin du stage 2 |
| `docker-compose.prod.yml` | racine | serveur, lu par Docker Compose | pendant `deploy.sh` |
| `entrypoint.sh` | `time_manager/` | conteneur `phoenix` | à chaque démarrage du conteneur |

### 4.1 `.travis.yml` : le chef d'orchestre

```yaml
language: minimal

services:
  - docker

jobs:
  include:
    - stage: "Build & Push Image"
      script:
        - echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
        - docker build -t "$DOCKER_USERNAME/time-manager-backend:latest" ./time_manager
        - docker build -t "$DOCKER_USERNAME/time-manager-frontend:latest" ./time-manager-dashboard
        - docker push "$DOCKER_USERNAME/time-manager-backend:latest"
        - docker push "$DOCKER_USERNAME/time-manager-frontend:latest"

    - stage: "Deploy"
      before_script:
        - eval "$(ssh-agent -s)"
        - echo "$SSH_KEY" | base64 --decode | tr -d '\r' | ssh-add -
        - mkdir -p ~/.ssh
        - chmod 700 ~/.ssh
        - ssh-keyscan -H $SERVER_IP >> ~/.ssh/known_hosts
      script:
        - scp -v docker-compose.prod.yml $SERVER_USER@$SERVER_IP:~/docker-compose.yml
        # Build the server .env from the Travis environment variables
        - printf 'PGUSER=%s\nPGPASSWORD=%s\nPGDATABASE=%s\nPGPORT=%s\nDOCKER_USERNAME=%s\n' "$PGUSER" "$PGPASSWORD" "$PGDATABASE" "$PGPORT" "$DOCKER_USERNAME" > .env.deploy
        - scp .env.deploy $SERVER_USER@$SERVER_IP:~/.env
        - scp deploy.sh $SERVER_USER@$SERVER_IP:~/deploy.sh
        - ssh $SERVER_USER@$SERVER_IP "bash ~/deploy.sh"
```

**En-tête.** `language: minimal` et `services: docker` s'appliquent aux deux jobs (voir [3.1](#31-travis-ci)). `jobs.include` liste les jobs, et la clé `stage` range chacun dans son stage.

**Stage 1 : construire et publier les images.**

| Commande | Ce qu'elle fait |
|---|---|
| `docker login ... --password-stdin` | Se connecte à Docker Hub, condition pour pousser. Le mot de passe arrive par l'entrée standard, pas en argument : il n'apparaît ni dans la liste des processus ni dans les logs. |
| `docker build -t ".../time-manager-backend:latest" ./time_manager` | Construit l'image du backend. `./time_manager` est le *contexte de build* : le dossier envoyé à Docker, qui y trouve le Dockerfile. `-t` donne le nom complet de l'image. |
| `docker build -t ".../time-manager-frontend:latest" ./time-manager-dashboard` | Même chose pour le frontend, avec le Dockerfile de `time-manager-dashboard/`. |
| `docker push ...`, deux fois | Envoie chaque image sur Docker Hub. Seules les couches absentes du registre sont transférées. |

**Stage 2 : préparer la connexion SSH (`before_script`).**

| Commande | Ce qu'elle fait |
|---|---|
| `eval "$(ssh-agent -s)"` | Démarre un agent SSH. `ssh-agent -s` affiche les variables qui permettent de le joindre, et `eval` les applique au shell courant. |
| `echo "$SSH_KEY"` puis `base64 --decode`, `tr -d '\r'` et `ssh-add -` | Décode la clé privée, retire d'éventuels retours chariot Windows qui la rendraient invalide, et la charge dans l'agent depuis l'entrée standard (`-`). La clé ne touche jamais le disque. |
| `mkdir -p ~/.ssh` et `chmod 700 ~/.ssh` | Crée le dossier de configuration SSH, accessible à son seul propriétaire. |
| `ssh-keyscan -H $SERVER_IP >> ~/.ssh/known_hosts` | Récupère l'empreinte du serveur et l'ajoute aux hôtes connus, pour éviter la question de confirmation à la première connexion. `-H` enregistre l'adresse sous forme hachée. |

**Stage 2 : déployer (`script`).**

| Commande | Ce qu'elle fait |
|---|---|
| `scp -v docker-compose.prod.yml ...:~/docker-compose.yml` | Copie le fichier compose de production en le renommant : `docker-compose.yml` est le nom que Compose cherche par défaut. `-v` détaille la connexion, utile pour déboguer. |
| `printf '...' ... > .env.deploy` | Écrit le fichier de variables du serveur, une ligne `CLÉ=valeur` par variable Travis. `printf` remplace chaque `%s` par l'argument suivant, et chaque `\n` par un saut de ligne. |
| `scp .env.deploy ...:~/.env` | Copie ce fichier sur le serveur, sous le nom `.env`. |
| `scp deploy.sh ...:~/deploy.sh` | Copie le script de déploiement. |
| `ssh $SERVER_USER@$SERVER_IP "bash ~/deploy.sh"` | Exécute le script sur le serveur. Son code de sortie remonte à Travis : un échec côté serveur fait échouer le job. |

!!! note "À noter"
    Dans `script`, une commande qui échoue n'arrête pas les suivantes (voir [3.1](#31-travis-ci)). Si un `scp` échoue, `deploy.sh` est quand même lancé, avec les fichiers du déploiement précédent. De même au stage 1 : si le build du backend casse, l'image du frontend est tout de même poussée.

### 4.2 Dockerfile du backend : la recette de l'image

```dockerfile
FROM elixir:1.17.3-otp-27-alpine
# postgresql-client provides pg_isready, used by entrypoint.sh to wait for the db
RUN apk add --no-cache build-base postgresql-client
WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
ENV MIX_ENV=dev
COPY mix.exs mix.lock ./
RUN mix deps.get
RUN mix deps.compile
COPY . .
RUN mix compile
RUN chmod +x entrypoint.sh
EXPOSE 4000
ENTRYPOINT ["./entrypoint.sh"]
```

| Instruction | Rôle |
|---|---|
| `FROM elixir:1.17.3-otp-27-alpine` | Image de départ : Elixir 1.17.3 et Erlang/OTP 27 sur Alpine Linux, une distribution très légère. Une version figée rend le build reproductible. |
| `RUN apk add --no-cache build-base postgresql-client` | `build-base` fournit le compilateur C dont certaines dépendances ont besoin ; `postgresql-client` fournit `pg_isready`, utilisé par l'entrypoint. |
| `WORKDIR /app` | Dossier de travail des instructions suivantes et du conteneur. |
| `RUN mix local.hex --force && mix local.rebar --force` | Installe Hex, le gestionnaire de paquets, et rebar3, l'outil de build Erlang, sans question interactive. |
| `ENV MIX_ENV=dev` | Toutes les commandes `mix` tournent en environnement `dev`, avec `config/dev.exs`. |
| `COPY mix.exs mix.lock ./`, puis `deps.get` et `deps.compile` | Copie d'abord les seuls fichiers de dépendances, puis les télécharge et les compile. Cette couche reste en cache tant que les dépendances ne changent pas. |
| `COPY . .`, puis `RUN mix compile` | Copie le reste du code et le compile pendant le build : le conteneur démarre plus vite, et une erreur de compilation fait échouer le stage 1. |
| `RUN chmod +x entrypoint.sh` | Rend le script exécutable ; ce droit peut se perdre selon l'OS ou la configuration Git. |
| `EXPOSE 4000` | Documente le port écouté, sans rien publier : la publication se fait avec `ports` dans le fichier compose. |
| `ENTRYPOINT ["./entrypoint.sh"]` | Commande lancée à chaque démarrage du conteneur. |

`MIX_ENV=dev` fait tourner le serveur avec la configuration de développement. Ça fonctionne, mais une vraie mise en production passe par `MIX_ENV=prod` et une release (voir [partie 5](#pour-aller-plus-loin)).

Le Dockerfile du frontend, dans `time-manager-dashboard/`, n'est pas détaillé ici. D'après le fichier compose (`8080:80`), son image sert l'application compilée avec un serveur web qui écoute sur le port 80.

### 4.3 `deploy.sh` : ce qui se passe sur le serveur

```bash
#!/usr/bin/env bash
# Executed on the deploy server by Travis (see .travis.yml, "Deploy" stage).
# Expects ~/docker-compose.yml and ~/.env to have been copied beforehand.
set -e
cd ~

# Install Docker (with the compose plugin) if it is missing
if ! command -v docker >/dev/null 2>&1; then
  if ! command -v curl >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y curl
  fi
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
fi

sudo docker compose pull
sudo docker compose up -d
```

Le script est *idempotent* : le relancer plusieurs fois donne le même résultat qu'une seule. Sur un serveur vierge, il installe Docker ; ensuite, il se contente de mettre l'application à jour.

**`set -e` et `cd ~`.** Le script s'arrête à la première erreur, et son code de sortie remonte jusqu'à Travis. Il se place dans le dossier personnel, où `scp` vient de déposer les fichiers.

**L'installation de Docker.** `command -v docker` teste si Docker est présent. Sinon, le script installe `curl` au besoin, puis lance le script officiel `get.docker.com`, qui installe Docker Engine et le plugin Compose. `apt-get` suppose un serveur Debian ou Ubuntu.

**`usermod -aG docker "$USER"`.** Ajoute l'utilisateur au groupe `docker`, pour utiliser Docker sans `sudo`. Ce changement ne prend effet qu'à la connexion suivante : la suite du script utilise donc toujours `sudo`. Il faut que `SERVER_USER` puisse lancer `sudo` sans mot de passe, sinon le script échoue.

**`docker compose pull`, puis `up -d`.** Le premier télécharge depuis Docker Hub les dernières versions des trois images. Le second recrée les conteneurs dont l'image a changé et laisse les autres tourner (voir [3.2](#32-docker-et-docker-compose)).

### 4.4 `docker-compose.prod.yml` : l'application sur le serveur

```yaml
# Used on the deploy server: pulls pre-built images from the registry instead
# of building from source (the server only needs this file + .env).
services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${PGUSER}
      POSTGRES_PASSWORD: ${PGPASSWORD}
      POSTGRES_DB: ${PGDATABASE}
    volumes:
      - db_data:/var/lib/postgresql/data
    ports:
      - "${PGPORT}:5432"

  phoenix:
    image: ${DOCKER_USERNAME}/time-manager-backend:latest
    restart: unless-stopped
    depends_on:
      - db
    env_file: ./.env
    environment:
      PGHOST: db
      PGPORT: "5432"
    volumes:
      - ./.env:/app/.env:ro
    ports:
      - "4000:4000"

  dashboard:
    image: ${DOCKER_USERNAME}/time-manager-frontend:latest
    restart: unless-stopped
    depends_on:
      - phoenix
    ports:
      - "8080:80"

volumes:
  db_data:
```

Ce fichier n'utilise que `image:`, jamais `build:` : le serveur n'a besoin ni du code source ni des outils de compilation.

**Le chemin des variables.** Compose lit `~/.env` pour remplacer les `${...}` : noms des images, identifiants Postgres, port publié. Le service `db` transmet ces identifiants à Postgres, qui crée l'utilisateur et la base au premier démarrage. Le service `phoenix` reçoit tout le `.env` en variables d'environnement (`env_file`), et le fichier lui-même, monté en lecture seule dans `/app/.env`, que l'entrypoint vérifie.

**Pourquoi `PGPORT` est redéfini.** Dans `.env`, `PGPORT` est le port publié sur le serveur. Entre conteneurs, Postgres écoute toujours sur 5432. Le bloc `environment` de `phoenix` impose donc `PGHOST: db` et `PGPORT: "5432"`, prioritaires sur `env_file`.

**Persistance.** Sans le volume `db_data`, chaque recréation du conteneur `db` effacerait la base.

!!! warning "Attention"
    Postgres ne lit `POSTGRES_USER` et `POSTGRES_PASSWORD` qu'à la création du volume ; changer `PGPASSWORD` ensuite ne modifie pas le mot de passe existant.

### 4.5 `entrypoint.sh` : le démarrage du backend

```sh
#!/bin/sh
set -e

if [ ! -f /app/.env ]; then
  echo "entrypoint: .env not found, stopping container"
  exit 1
fi

echo "entrypoint: waiting for database at ${PGHOST}:${PGPORT}..."
until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" > /dev/null 2>&1; do
  sleep 1
done
echo "entrypoint: database is up"

mix ecto.create
mix ecto.migrate

echo "entrypoint: starting Phoenix"
exec mix phx.server
```

Ce script s'exécute à chaque démarrage du conteneur `phoenix` : après un déploiement, un crash ou un redémarrage du serveur. Il est écrit en `sh`, car les images Alpine n'embarquent pas `bash` par défaut.

**Vérifier la configuration.** Si `/app/.env` est absent, le conteneur s'arrête avec un message clair, au lieu d'une erreur obscure plus loin. Avec `restart: unless-stopped`, il redémarre alors en boucle, et `docker compose logs phoenix` affiche ce message.

**Attendre la base.** `depends_on` démarre `db` avant `phoenix`, mais n'attend pas que Postgres accepte les connexions. La boucle interroge la base chaque seconde avec `pg_isready`, jusqu'à une réponse positive.

**Préparer la base.** `mix ecto.create` crée la base si elle n'existe pas, et ne fait rien sinon. `mix ecto.migrate` applique les nouvelles migrations : chaque déploiement met le schéma à jour automatiquement.

**Lancer Phoenix.** `exec` remplace le script par le serveur Phoenix, qui devient le processus principal du conteneur et reçoit directement le signal d'arrêt (voir [3.2](#32-docker-et-docker-compose)).

---

## 5. Roadmap pour refaire le projet

Le principe : construire et valider chaque brique à la main avant de l'automatiser. Quand une étape automatique échoue, tout ce qui précède est déjà prouvé, et la panne est vite localisée.

1. **Réunir les prérequis.** Un dépôt GitHub, un compte travis-ci.com relié à GitHub, un compte Docker Hub, et un serveur Debian ou Ubuntu accessible en SSH. L'utilisateur de déploiement doit pouvoir lancer `sudo` sans mot de passe. Le pare-feu de l'hébergeur doit laisser passer les ports 22, 8080 et 4000.
    - *Validation* : `ssh utilisateur@IP` fonctionne, et `sudo -n true` réussit sans demander de mot de passe.
2. **Dockeriser le backend.** Écrire le `Dockerfile` et `entrypoint.sh` dans `time_manager/`. Côté Phoenix, deux réglages sont indispensables : l'endpoint doit écouter sur `0.0.0.0` et non `127.0.0.1`, sinon l'API est injoignable hors du conteneur ; la configuration de la base doit être lue dans les variables `PG*`. Ajouter un `.dockerignore` (`_build`, `deps`, `.env`) et forcer les fins de ligne LF des scripts avec `*.sh text eol=lf` dans `.gitattributes`.
    - *Validation* : `docker build -t test-backend ./time_manager` réussit.
3. **Dockeriser le frontend.** Un build en deux étapes : Node compile l'application, puis un serveur web la sert sur le port 80. Le frontend s'exécute dans le navigateur, hors du réseau Docker : l'URL de l'API doit être l'adresse publique (`http://IP:4000`), jamais `http://phoenix:4000`. Si cette URL est figée au build, la passer avec `--build-arg` dans Travis ; côté Phoenix, autoriser l'origine du frontend (CORS).
    - *Validation* : `docker run -p 8080:80 <image>` affiche l'application sur `localhost:8080`.
4. **Tout faire tourner en local.** Écrire un `docker-compose.yml` de développement, avec `build:` au lieu de `image:`, et un `.env` local jamais commité. Cette étape valide le réseau interne, le volume et l'entrypoint.
    - *Validation* : `docker compose up --build` donne une application qui marche, et les données survivent à `docker compose down` puis `up`.
5. **Publier les images à la main.** `docker login`, `docker build -t compte/time-manager-backend:latest ./time_manager`, `docker push`, puis vérifier que les dépôts sont publics sur Docker Hub. Depuis un Mac à puce Apple, ajouter `--platform linux/amd64` pour un serveur x86.
    - *Validation* : les deux dépôts apparaissent sur Docker Hub.
6. **Déployer à la main.** Copier sur le serveur `docker-compose.prod.yml` (renommé `docker-compose.yml`), un `.env` et `deploy.sh`, puis lancer `bash ~/deploy.sh`. Toute la partie serveur est ainsi validée avant d'impliquer Travis.
    - *Validation* : `sudo docker compose ps` liste trois conteneurs démarrés, et `http://IP:8080` affiche l'application.
7. **Créer la clé de déploiement.** Une paire dédiée, sans passphrase, jamais commitée :
    - `ssh-keygen -t ed25519 -C "travis-deploy" -f travis_deploy -N ""` crée la paire.
    - `ssh-copy-id -i travis_deploy.pub utilisateur@IP` installe la clé publique sur le serveur.
    - `ssh -i travis_deploy utilisateur@IP "echo ok"` teste la connexion.
    - `base64 -w 0 travis_deploy` (sur macOS : `base64 -i travis_deploy`) produit la valeur de `SSH_KEY`, sur une seule ligne.
    - *Validation* : le test affiche `ok` sans demander de mot de passe.
8. **Configurer Travis.** Activer le dépôt sur travis-ci.com, puis saisir les neuf variables du tableau de la [partie 3.1](#31-travis-ci), affichage dans les logs désactivé.
    - *Validation* : les neuf variables apparaissent dans *Settings*, valeurs masquées.
9. **Automatiser le build.** Écrire `.travis.yml` avec le seul stage « Build & Push Image », puis pousser.
    - *Validation* : le build est vert, et la date du dernier push des images change sur Docker Hub.
10. **Automatiser le déploiement.** Ajouter le stage « Deploy », puis pousser une modification visible.
    - *Validation* : les deux stages sont verts, et la modification apparaît sur `http://IP:8080`.

### Pièges fréquents

| Symptôme | Cause probable | Solution |
|---|---|---|
| `Permission denied (publickey)` au stage Deploy | Clé publique absente du serveur, mauvais `SERVER_USER`, ou `SSH_KEY` mal encodée | Refaire le test `ssh -i` de l'étape 7, puis réencoder la clé |
| `Error loading key "(stdin)": invalid format` | `SSH_KEY` tronquée, ou encodée sur plusieurs lignes | Réencoder la clé avec `base64 -w 0` et recoller la valeur |
| `sudo: a terminal is required to read the password` | `sudo` demande un mot de passe | Autoriser `sudo` sans mot de passe pour `SERVER_USER` |
| `pull access denied` pendant `docker compose pull` | Dépôt Docker Hub privé, ou `DOCKER_USERNAME` erroné dans `.env` | Rendre le dépôt public ; vérifier les noms avec `docker compose config` |
| `exec format error` au démarrage d'un conteneur | Image construite sur une machine ARM pour un serveur x86 | Reconstruire avec `--platform linux/amd64` |
| `exec ./entrypoint.sh: no such file or directory`, alors que le fichier existe | Fins de ligne Windows (CRLF) dans le script | Convertir le fichier en LF et ajouter la règle `.gitattributes` |
| Conteneur `phoenix` qui redémarre en boucle | `.env` absent, base injoignable, ou migration en erreur | Lire `sudo docker compose logs phoenix` |
| `password authentication failed` après un changement de `PGPASSWORD` | Postgres n'applique ses variables qu'à la création du volume | Changer le mot de passe dans Postgres, ou recréer le volume en perdant les données |
| Le frontend s'affiche mais les appels à l'API échouent | URL de l'API injoignable depuis le navigateur, ou CORS non configuré | Utiliser `http://IP:4000` et autoriser l'origine du frontend |
| Rien ne répond alors que les conteneurs tournent | Port fermé dans le pare-feu de l'hébergeur, ou Phoenix qui écoute sur `127.0.0.1` | Ouvrir 8080 et 4000 ; configurer `ip: {0, 0, 0, 0}` |

### Pour aller plus loin

Le pipeline fonctionne, mais plusieurs points sont à durcir avant une vraie production, en particulier côté sécurité.

| Amélioration | Pourquoi |
|---|---|
| Ajouter un stage de tests (`mix test`, tests du frontend) avant le build | Ne déployer que du code qui passe les tests : c'est la partie « intégration continue » qui manque. |
| Limiter build et déploiement à la branche principale | Tel quel, un push sur n'importe quelle branche écrase `latest` et déclenche un déploiement, sauf réglage contraire dans Travis. |
| Taguer aussi chaque image avec `$TRAVIS_COMMIT` | Savoir quelle version tourne, et pouvoir revenir à la précédente. |
| Ne plus publier le port de Postgres, ou le lier à `127.0.0.1` | La base est aujourd'hui joignable depuis Internet. Les ports publiés par Docker contournent même le pare-feu UFW. |
| Passer le backend en `MIX_ENV=prod` avec une release (`mix release`) et un build multi-étapes | Image plus légère, sans outils de développement, avec la configuration de production ; il faudra fournir `SECRET_KEY_BASE`. |
| Ajouter un `healthcheck` à `db`, et `condition: service_healthy` dans le `depends_on` de `phoenix` | Compose attend lui-même que la base soit prête. |
| Ajouter `sudo docker image prune -f` à la fin de `deploy.sh` | Les anciennes images s'accumulent à chaque déploiement et finissent par remplir le disque. |
| Placer un reverse proxy avec HTTPS (Caddy, Nginx, Traefik) devant l'application | Chiffrer le trafic et servir l'application sur un nom de domaine. |
| Utiliser un access token Docker Hub, protéger `~/.env` avec `chmod 600`, stocker l'empreinte du serveur dans une variable Travis | Limiter l'impact d'une fuite, et ne plus faire confiance aveuglément au serveur à chaque déploiement. |

Pour limiter les deux jobs à la branche principale, Travis accepte une condition `if` (adapter `main` au nom de la branche de production) :

```yaml
jobs:
  include:
    - stage: "Build & Push Image"
      if: branch = main AND type = push
      # script inchangé
    - stage: "Deploy"
      if: branch = main AND type = push
      # before_script et script inchangés
```

---

## 6. Le miroir GitHub Actions

En plus de Travis, le dépôt contient un workflow GitHub Actions, `.github/workflows/mirror.yml`. Il ne construit ni ne déploie rien : il recopie le dépôt de l'organisation (`MscProgramm/Theme_5_authentification_security`) vers un dépôt miroir (`Time_Manager_Mirror`), à chaque changement.

```text
 git push ──▶ MscProgramm/Theme_5_authentification_security
                 │
                 ├──▶ Travis CI : build + déploiement (parties 2 à 4)
                 │
                 └──▶ GitHub Actions : mirror.yml
                         │  git push --force --prune (SSH, deploy key)
                         ▼
                      Time_Manager_Mirror
```

!!! danger "Le miroir est une copie, pas un second dépôt de travail"
    Chaque synchronisation écrase le miroir : un commit fait directement dans le miroir est perdu, et une branche ou un tag qui n'existe que là-bas est supprimé. Tout le travail passe par le dépôt de l'organisation.

### 6.1 `mirror.yml`

```yaml
name: Mirror repository

on:
  push:
    branches: ['**']
    tags: ['**']
  delete:
  workflow_dispatch:

concurrency:
  group: mirror
  cancel-in-progress: false

jobs:
  mirror:
    if: github.repository == 'MscProgramm/Theme_5_authentification_security'
    runs-on: ubuntu-latest
    steps:
      - name: Checkout full history
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup SSH key
        env:
          SSH_PRIVATE_KEY: ${{ secrets.MIRROR_SSH_PRIVATE_KEY }}
        run: |
          mkdir -p ~/.ssh
          printf '%s\n' "$SSH_PRIVATE_KEY" | tr -d '\r' > ~/.ssh/id_mirror
          chmod 600 ~/.ssh/id_mirror
          ssh-keygen -y -f ~/.ssh/id_mirror > /dev/null || { echo "::error::MIRROR_SSH_PRIVATE_KEY is not a valid private key"; exit 1; }
          ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null

      - name: Push mirror
        env:
          MIRROR_URL: ${{ vars.MIRROR_REPO_URL }}
          GIT_SSH_COMMAND: ssh -i ~/.ssh/id_mirror -o IdentitiesOnly=yes
        run: |
          git remote add mirror "$MIRROR_URL"
          git fetch --prune origin '+refs/heads/*:refs/remotes/origin/*' '+refs/tags/*:refs/tags/*'
          git remote set-head origin --delete || true
          git push --force --prune mirror '+refs/remotes/origin/*:refs/heads/*' '+refs/tags/*:refs/tags/*'
```

**Déclencheurs (`on`).**

| Événement | Quand |
|---|---|
| `push` sur `branches: ['**']` et `tags: ['**']` | À chaque push, sur n'importe quelle branche ou tag. |
| `delete` | À la suppression d'une branche ou d'un tag, pour la répercuter sur le miroir. |
| `workflow_dispatch` | Lancement manuel depuis l'onglet *Actions*. |

**`concurrency`.** Deux synchronisations ne tournent jamais en même temps : si deux pushs arrivent coup sur coup, la seconde attend la fin de la première au lieu de l'annuler (`cancel-in-progress: false`).

**Le garde-fou `if`.** Le fichier `mirror.yml` est lui-même recopié dans le miroir, où il se déclencherait aussi. Là-bas, la variable `MIRROR_REPO_URL` n'existe pas et le job échouerait (`'mirror' does not appear to be a git repository`). La condition `github.repository == '...'` limite l'exécution au dépôt de l'organisation ; dans le miroir, le job apparaît comme *skipped*.

**Étape « Checkout full history ».** `fetch-depth: 0` récupère tout l'historique. Par défaut, `actions/checkout` ne prend que le dernier commit, et le miroir ne peut pas être poussé à partir d'un historique tronqué.

**Étape « Setup SSH key ».**

| Commande | Ce qu'elle fait |
|---|---|
| `printf '%s\n' "$SSH_PRIVATE_KEY" \| tr -d '\r'` | Écrit la clé dans un fichier en garantissant le retour à la ligne final et en retirant les retours chariot Windows : deux défauts fréquents après un copier-coller, qui rendent la clé illisible. |
| `chmod 600` | SSH refuse une clé privée lisible par d'autres utilisateurs. |
| `ssh-keygen -y -f ...` | Vérifie que la clé est valide. Si le secret est mal collé, le job s'arrête ici avec un message clair. |
| `ssh-keyscan github.com >> ~/.ssh/known_hosts` | Enregistre l'empreinte de GitHub, pour éviter la question de confirmation à la première connexion. |

**Étape « Push mirror ».**

| Commande | Ce qu'elle fait |
|---|---|
| `GIT_SSH_COMMAND: ssh -i ... -o IdentitiesOnly=yes` | Force git à utiliser la clé du miroir, et seulement elle. |
| `git remote add mirror "$MIRROR_URL"` | Déclare le dépôt miroir comme destination. |
| `git fetch --prune origin '+refs/heads/*:...' '+refs/tags/*:...'` | Récupère toutes les branches et tous les tags de la source. Le checkout n'en contient qu'une seule. |
| `git remote set-head origin --delete` | Supprime la référence `origin/HEAD`, qui serait sinon poussée comme une branche nommée `HEAD`. |
| `git push --force --prune mirror ...` | Pousse chaque branche et chaque tag vers le miroir. `--force` écrase un historique divergent ; `--prune` supprime du miroir ce qui n'existe plus à la source. |

### 6.2 Configuration

Le miroir s'authentifie avec une paire de clés SSH dédiée, sans passphrase. La clé publique est une *deploy key* du dépôt miroir : elle ne donne accès qu'à ce dépôt.

| Où | Réglage | Contenu |
|---|---|---|
| Dépôt miroir → *Settings → Deploy keys* | Deploy key, **Allow write access** coché | Clé publique (`.pub`) |
| Dépôt source → *Settings → Secrets and variables → Actions → Secrets* | `MIRROR_SSH_PRIVATE_KEY` | Clé privée complète, lignes `-----BEGIN OPENSSH PRIVATE KEY-----` et `-----END OPENSSH PRIVATE KEY-----` comprises |
| Dépôt source → *Settings → Secrets and variables → Actions → Variables* | `MIRROR_REPO_URL` | URL SSH du miroir, par exemple `git@github.com:compte/Time_Manager_Mirror.git` |

Pour refaire la configuration :

1. Créer la paire : `ssh-keygen -t ed25519 -C "github-mirror" -f mirror_key -N ""`.
2. Ajouter `mirror_key.pub` comme deploy key du miroir, avec droit d'écriture.
3. Enregistrer la clé privée sans copier-coller, avec la CLI GitHub : `gh secret set MIRROR_SSH_PRIVATE_KEY < mirror_key`.
4. Créer la variable `MIRROR_REPO_URL`.
5. Si le miroir contient déjà du travail à garder, le récupérer dans la source avant le premier lancement (`git fetch` du miroir, puis `merge` ou `cherry-pick`).
6. Pousser, ou lancer le workflow à la main depuis *Actions → Mirror repository → Run workflow*.
    - *Validation* : le job est vert dans la source, *skipped* dans le miroir, et le miroir affiche le même dernier commit.

### 6.3 Pièges fréquents

| Symptôme | Cause probable | Solution |
|---|---|---|
| `Load key ".../id_mirror": error in libcrypto` puis `Permission denied (publickey)` | Secret mal collé : lignes `BEGIN`/`END` absentes, clé publique collée à la place de la privée, clé tronquée | Réenregistrer le secret avec `gh secret set MIRROR_SSH_PRIVATE_KEY < mirror_key` |
| `MIRROR_SSH_PRIVATE_KEY is not a valid private key` | Même cause, détectée par la vérification `ssh-keygen -y` | Idem |
| `Permission denied (publickey)` avec une clé valide | Deploy key absente du miroir, ou clé publique d'une autre paire | Vérifier la deploy key du miroir |
| `ERROR: The key you are authenticating with has been marked as read only` | Deploy key ajoutée sans droit d'écriture | Cocher **Allow write access** |
| `'mirror' does not appear to be a git repository` | `MIRROR_REPO_URL` vide : variable absente, ou workflow lancé depuis le miroir | Créer la variable dans la source ; garder la condition `if` du job |
| Commits disparus dans le miroir | Comportement normal de `--force --prune` | Ne jamais travailler directement dans le miroir |
