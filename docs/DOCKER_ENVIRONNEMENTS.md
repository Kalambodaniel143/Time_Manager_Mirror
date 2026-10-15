# Séparation Docker développement / production

## Diagnostic et démarrage

Auparavant, `time_manager/Dockerfile` compilait avec `MIX_ENV=dev`. Travis publiait cette image sous `time-manager-backend:latest`, reprise par `docker-compose.prod.yml`. Le serveur exécutait donc `dev.exs`, avec rechargement du code, erreurs détaillées et routes de diagnostic.

Le Dockerfile possède maintenant deux cibles séparées :

| Usage | Construction | Configuration | Démarrage |
| --- | --- | --- | --- |
| Local | `--target development` (Compose local) | `MIX_ENV=dev` | `entrypoint.sh dev` |
| Production | `--target production` (Travis et cible par défaut) | `MIX_ENV=prod` | `entrypoint.sh prod` |

Chaque cible récupère et compile ses propres dépendances et l'application. `.dockerignore` exclut les artefacts locaux et les fichiers `.env`. La production génère aussi le manifeste statique avec `mix phx.digest`. Les secrets ne sont pas nécessaires à la construction.

L'entrypoint impose le mode de sa cible, même si `MIX_ENV` est contradictoire dans l'environnement. Il charge `runtime.exs` sans démarrer l'application, attend PostgreSQL (60 tentatives au maximum), puis exécute la création de base, les migrations, les seeds idempotents et `mix phx.server --no-compile`. Il n'exige plus de fichier `/app/.env` monté : Compose transmet déjà les variables.

Mix est conservé pour limiter les changements au fonctionnement existant. Ce n'est pas une release OTP. LiveDashboard et ses dépendances propres ne sont pas installés en production ; ses macros de routes, son logger et la socket LiveView associée sont exclus de la compilation. `/dev/dashboard` et `/dev/mailbox` doivent répondre 404. Swagger et OpenAPI conservent leur comportement existant.

## Variables à préparer

Les modèles `.env.example` (local) et `.env.production.example` (serveur) ne contiennent aucun secret utilisable.

| Variable | Nécessaire | Règle |
| --- | --- | --- |
| `JWT_SECRET` | Tous les environnements, y compris tests | Au moins 32 octets, sans espaces ; aucune clé publique de secours. |
| `SECRET_KEY_BASE` | Production | Au moins 64 octets, sans espaces. |
| `DATABASE_URL` | Production | `postgres://USER:PASSWORD@db:5432/DATABASE`, ou schéma `postgresql`. Identifiants et base non vides, port valide. |
| `PGUSER`, `PGPASSWORD`, `PGDATABASE` | PostgreSQL et backend local | En production, doivent correspondre à l'URL ; changer ces variables ne modifie pas un volume Postgres existant. |
| `PGPORT` | Compose | Port publié sur l'hôte, distinct du port interne `5432`. |
| `PHX_HOST` | URL publiques Phoenix | Renseigner le nom DNS du service ; `localhost` est réservé aux essais locaux. |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | Facultatives | Création du premier administrateur par les seeds. |

Générer séparément chaque secret avec `openssl rand -base64 48` et le stocker uniquement dans un fichier local non versionné ou dans les variables secrètes de CI. La longueur ne prouve pas le caractère aléatoire : utiliser un générateur cryptographique. Les anciennes clés publiques de développement/test sont explicitement refusées.

Pour un lancement local, copier `.env.example` vers `.env`, renseigner `JWT_SECRET`, puis lancer `docker compose up --build`. Pour des tests hors Docker, exporter une clé JWT de test aléatoire avant `mix test`. Phoenix ne charge pas automatiquement le fichier `.env` hors Compose.

Travis construit et publie désormais `time-manager-backend:prod`. Le Compose de production référence ce tag, distinct de l'ancienne image `latest`, et refuse les trois variables essentielles vides. La CI transmet `DATABASE_URL`, `SECRET_KEY_BASE`, `JWT_SECRET` et `PHX_HOST` au serveur. Aucun push d'image ni déploiement n'a été exécuté pendant cette correction.

## Validation locale reproductible

Depuis la racine, avec Docker disponible :

```sh
docker build --target production -t time-manager-backend:step1-prod ./time_manager
docker build --target development -t time-manager-backend:step1-dev ./time_manager
```

Le script temporaire d'intégration utilisé pendant le durcissement a été retiré après la campagne de vérification. Les constructions Docker restent exécutées par Travis.

## Périmètre de sécurité

Le contrôle du rôle actif du manager existe déjà dans `TeamController.index/2` et `show/2`, et `Authenticate` recharge le rôle depuis la base à chaque requête. Deux tests de régression vérifient qu'un ancien JWT ne permet plus à un manager rétrogradé de lire les membres de l'équipe, même si `manager_id` le désigne encore. S'il reste membre, il conserve seulement la liste sans membres autorisée aux employés.

HTTPS, les réglages de cookies, les autres autorisations et la gestion des sessions ne sont pas durcis par cette correction. `prod.exs` impose déjà une redirection HTTPS hors localhost ; activer réellement cette configuration rend nécessaire un frontal TLS correctement configuré avant une mise en ligne. Mailpit et les ports du Compose existant sont conservés et restent à examiner. Cette étape ne certifie pas la conformité globale au Thème 7.

## Résultats du 13 octobre 2026

- Les deux images ont été construites localement et ont démarré avec création de base, migrations et seeds sur PostgreSQL jetable. Une variable `MIX_ENV` contradictoire n'a pas changé le mode fixé par leur cible.
- API joignable, route authentifiée refusée sans session (401), routes `/dev` disponibles uniquement en développement et refusées en production (404). Configuration prod sans rechargement de code ni erreurs détaillées, sans `_build/dev` ni module LiveDashboard, manifeste statique présent. Aucune recompilation observée au démarrage.
- 17 configurations invalides de production refusées avant l'attente de PostgreSQL : URL absente/vide/mal formée, clés absentes/vides/courtes/avec espaces/publiques. Absence de `JWT_SECRET` également refusée en dev et test. Aucune valeur de secret dans les erreurs contrôlées.
- Les deux Compose sont validés avec `config --quiet` et des variables fictives. Le Compose prod refuse aussi l'absence de `JWT_SECRET`. Syntaxes shell/Python, format des fichiers Elixir modifiés et `git diff --check` validés.
- `mix precommit` et `mix test` : **169 tests, 3 échecs**, tous dans `JoinRequestControllerTest`. Les deux tests de rétrogradation ajoutés passent.
- Comparaison sur le code initial `HEAD`, dans une autre base jetable : **167 tests, les mêmes 3 échecs**. La migration `20261008120000_add_email_verification.exs` impose `email_verifications.user_id NOT NULL` ; `20261013100000_add_join_request_email_verification.exs` ajoute un propriétaire alternatif `join_request_id` sans lever cette contrainte. Les demandes d'adhésion sans compte échouent donc à l'insertion. Ce défaut préexistant reste à corriger séparément ; la suite globale n'est pas verte.

Tous les conteneurs et réseaux de test ont été supprimés. Les images locales restent disponibles pour reproduire les vérifications. Aucun déploiement public n'a eu lieu.
