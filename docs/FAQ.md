# Dépannage technique

Cherchez d'abord le message qui ressemble à votre symptôme, puis exécutez la commande de diagnostic proposée. Gardez une copie des logs utiles avant de redémarrer un service. Si une commande touche la base ou un volume, vérifiez le nom de l'environnement avant de l'exécuter.

Chaque fiche distingue le symptôme, la cause probable, le diagnostic et la correction. Ne collez jamais la valeur d'un secret dans un ticket ou un terminal partagé.

## Compose refuse `JWT_SECRET`

**Symptôme**

```text
required variable JWT_SECRET is missing a value
```

**Cause probable** : `.env` est absent ou `JWT_SECRET` est vide.

**Diagnostic**

```bash
test -f .env && echo '.env présent' || echo '.env absent'
docker compose config --quiet
```

**Solution**

```bash
cp .env.example .env
umask 077
# Renseigner JWT_SECRET dans .env avec une valeur générée localement.
chmod 600 .env
docker compose up -d --build
```

La clé doit faire au moins 32 octets, ne contenir aucun espace et ne pas être une ancienne clé publique connue.

## Phoenix ne rejoint pas PostgreSQL

**Symptôme** : `entrypoint: PostgreSQL indisponible`, `connection refused` ou redémarrages du conteneur Phoenix.

**Causes probables** : conteneur `db` arrêté, mauvais hôte/port, URL incorrecte ou volume endommagé.

**Diagnostic**

```bash
docker compose ps
docker compose logs --tail=200 db
docker compose logs --tail=200 phoenix
docker compose exec db pg_isready -U "${PGUSER:-postgres}" -d "${PGDATABASE:-time_manager_dev}"
```

**Solution** : en Compose local, utiliser `PGHOST=db` et le port interne `5432`. En production, vérifier la structure de `DATABASE_URL` sans l'afficher dans les logs. Ne supprimez pas le volume avant d'avoir sauvegardé les données nécessaires.

## Le port est déjà utilisé

**Symptôme** : `bind: address already in use` sur 4000, 8080, 5433, 8025, 80 ou 443.

**Diagnostic macOS/Linux**

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

**Solution** : arrêter l'ancien service ou modifier le port hôte dans la composition locale. Ne modifiez pas le port interne utilisé entre conteneurs sans adapter les dépendances.

## L'API répond 401 alors que le compte est connecté

**Causes probables** : cookie absent/expiré, CSRF absent, session révoquée, mot de passe changé ou `sessionStorage` incohérent.

**Diagnostic navigateur**

1. Ouvrir les outils de développement, onglet Réseau.
2. Vérifier la présence du cookie `jwt` sans essayer d'en lire la valeur en JavaScript.
3. Vérifier l'en-tête `X-CSRF-Token`.
4. Lire la réponse de `GET /api/auth/session`.

**Solution** : se déconnecter puis se reconnecter. Si le problème touche tous les comptes, vérifier l'heure du serveur et la stabilité de `JWT_SECRET`. Changer cette clé invalide tous les JWT existants.

## L'API répond 403 « Origine refusée »

**Cause probable** : `Origin` ou `Referer` ne correspond pas exactement au protocole, domaine et port publics attendus.

**Diagnostic**

```bash
curl -i -X POST 'https://<DOMAINE_REEL>/api/auth/login' \
  -H 'Origin: https://<DOMAINE_REEL>' \
  -H 'Content-Type: application/json' \
  --data '{"email":"audit@example.test","password":"<MOT_DE_PASSE_DE_TEST>"}'
```

**Solution** : utiliser la même origine pour le frontend et `/api`, vérifier `PHX_HOST`, `HTTPS_PORT` et les en-têtes posés par Nginx. Ne désactivez pas `CheckOrigin` pour contourner le problème.

## Boucle de redirection HTTPS ou réponse 308 inattendue

**Cause probable** : Phoenix ne reconnaît pas le proxy de confiance ou reçoit `X-Forwarded-Proto` depuis une autre adresse.

**Diagnostic**

```bash
docker compose logs --tail=200 dashboard
docker compose logs --tail=200 phoenix
docker network inspect <PROJET>_proxy
```

**Solution** : faire correspondre l'adresse fixe du service `dashboard` et `TRUSTED_PROXY_IP`. Phoenix ne doit pas être publié directement en production.

## Le certificat HTTPS ne charge pas

**Symptôme** : Nginx redémarre ou le navigateur affiche un certificat absent/invalide.

**Diagnostic**

```bash
test -r "<TLS_CERT_DIR>/fullchain.pem" && echo fullchain-ok
test -r "<TLS_CERT_DIR>/privkey.pem" && echo private-key-ok
docker compose logs --tail=100 dashboard
openssl s_client -connect '<DOMAINE_REEL>:443' -servername '<DOMAINE_REEL>' </dev/null
```

**Solution** : corriger le montage `TLS_CERT_DIR`, les permissions et le renouvellement ACME. Vérifier le domaine et la chaîne complète depuis un autre réseau.

## Les emails n'arrivent pas en développement

**Cause probable** : Mailpit arrêté ou mauvais hôte SMTP.

**Diagnostic**

```bash
docker compose ps mailpit
docker compose logs --tail=100 mailpit
```

**Solution** : utiliser `MAILPIT_HOST=mailpit` et `MAILPIT_PORT=1025` dans le conteneur Phoenix, puis ouvrir `http://127.0.0.1:8025`.

## Les emails n'arrivent pas en production

**Causes probables** : `RESEND_API_KEY` absente, `RESEND_FROM` non vérifié, réseau sortant bloqué ou rejet du fournisseur.

**Diagnostic**

```bash
docker compose logs --tail=200 phoenix
```

**Solution** : vérifier les variables dans le gestionnaire de secrets et l'expéditeur chez Resend sans afficher la clé. **Point à confirmer** : état du compte fournisseur et domaine d'envoi.

## Une migration échoue

**Diagnostic**

```bash
docker compose logs --tail=300 phoenix
docker compose exec phoenix mix ecto.migrations
```

**Solution** : identifier précisément la migration et sauvegarder la base avant toute intervention. Ne modifiez pas une migration déjà appliquée sur un environnement partagé ; ajouter une nouvelle migration corrective.

## Le build frontend refuse les mocks

**Symptôme**

```text
Une version compilée ne peut pas activer les données simulées.
```

**Cause** : `VITE_USE_MOCK=true` ou `VITE_AUTH_USE_MOCK=true` pendant `npm run build`.

**Solution** : supprimer ces valeurs du contexte de build ou les mettre à `false`. Utiliser `npm run dev:demo` uniquement pour la démonstration locale.

## Le frontend utilise une version Node incompatible

**Diagnostic**

```bash
node --version
npm --version
```

**Solution** : utiliser Node `^22.18.0` ou `>=24.12.0`, puis reconstruire les dépendances avec `npm ci`.

## Les tests backend échouent avant leur exécution

**Cause probable** : PostgreSQL de test absent ou `JWT_SECRET` non fourni à `runtime.exs`.

**Diagnostic**

```bash
cd time_manager
MIX_ENV=test mix ecto.migrations
```

**Solution**

```bash
export MIX_ENV=test
export JWT_SECRET="$(openssl rand -base64 48 | tr -d '\n')"
export PGHOST=localhost
mix ecto.create
mix ecto.migrate
mix test
```

## MkDocs refuse la configuration

**Symptôme** : thème `material` introuvable ou extension `pymdownx` inconnue.

**Diagnostic**

```bash
python -m pip show mkdocs-material
mkdocs build --strict
```

**Solution**

```bash
python -m pip install mkdocs-material
mkdocs build --strict
```

## Les fichiers `/.env` ou `/.git/config` répondent 200

Avec une application monopage, Nginx peut renvoyer `index.html` avec 200 pour une URL inconnue. Le code actuel contient néanmoins une règle `location ~ /\.` qui doit répondre 404 pour les chemins cachés.

**Diagnostic**

```bash
for path in '/.env' '/.git/config'; do
  curl -sS -o /dev/null -w "$path -> %{http_code} %{content_type}\n" "https://<DOMAINE_REEL>$path"
done
```

**Résultat attendu** : 404. Si 200 persiste, l'image Nginx exécutée n'utilise probablement pas la configuration actuelle. Vérifier le tag d'image et recréer le conteneur.

## Informations à fournir dans un rapport de panne

- SHA Git et branche ;
- environnement concerné ;
- commande exécutée ;
- code HTTP et corps d'erreur sans cookie ni secret ;
- `request_id` des logs Phoenix ;
- extrait de logs expurgé ;
- heure et fuseau du problème ;
- résultat de `docker compose ps`.
