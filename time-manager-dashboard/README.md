# Time Manager — frontend Vue

La documentation des écrans, des routes utilisées et des fonctions restant sans backend est dans [docs/FRONTEND.md](../docs/FRONTEND.md). Le parcours d’adhésion et les compléments serveur sont décrits dans [le contrat backend](../docs/CONTRAT_BACKEND_ORGANISATIONS.md).

## Démarrage

Utiliser Node `^22.18.0` ou `>=24.12.0`.

```bash
npm install
```

Créer `.env.local` :

```env
VITE_AUTH_USE_MOCK=false
VITE_USE_MOCK=false
VITE_API_URL=/api
VITE_BACKEND_URL=http://34.155.104.175:4000
```

```bash
npm run dev
```

Le proxy Vite appelle le backend déployé. Pour utiliser Phoenix local, remplacer `VITE_BACKEND_URL` par `http://localhost:4000` et démarrer le serveur local. Ne pas inscrire de mot de passe dans les variables `VITE_*`.

Les identifiants doivent exister dans la base de ce backend. Un compte sans organisation peut accéder à son espace historique ; les adhésions Gotham exigent un administrateur rattaché à Gotham côté serveur.

## Simulation explicite

```bash
npm run dev:demo
```

Cette commande active les mocks d’authentification et de données. Les comptes simulés sont indépendants de la base réelle ; aucun mot de passe par défaut n’est fourni.

## Vérifications

```bash
npm run build
npx eslint src dev test vite.config.js
node --test test/*.test.js
```

Les écrans réels utilisent les comptes, équipes, pointages et périodes de l’API. Graphiques et relevés CSV sont calculés depuis ces périodes. Les fonctions sans endpoint restent indisponibles : aucun planning ou relevé de paie fictif n’est utilisé en cas d’échec serveur.
