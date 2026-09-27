# Pointage - partie Jonas

Le composant `src/components/ClockManager.vue` utilise l'Options API.
La route `/clock/:userid` lui transmet `userId`. Un watcher recharge les
pointages à l'ouverture et au changement d'utilisateur.

- `refresh()` lit `GET /api/clocks/:userID` et utilise le dernier pointage
  (ordre du backend : date, puis identifiant, croissants).
- `clock()` crée un événement avec `POST /api/clocks/:userID` et le corps
  `{ "clock": { "time": "YYYY-MM-DD hh:mm:ss", "status": true } }`.
  Le statut vaut `true` pour l'arrivée et `false` pour la sortie.
- `startDateTime` vaut `null` hors période active ; `clockIn` est un booléen.
- Les dates de pointage utilisent UTC, comme le champ Ecto `:utc_datetime`.
  Les réponses ISO de Phoenix sont normalisées par `utils/clockDate.js`.
- Les boutons attendent la réponse API. Un échec d'écriture impose une
  actualisation avant une nouvelle tentative, car le résultat peut être incertain.

## Démarrage local

Dans le backend : `mix deps.get`, puis `mix phx.server`.
PostgreSQL, les migrations et un utilisateur réel doivent être disponibles.

Dans ce dossier : `npm ci`, puis `npm run dev`.
Ouvrir `/clock/ID` avec l'identifiant d'un utilisateur existant dans PostgreSQL.
Le sélecteur User utilise encore des utilisateurs simulés : leurs identifiants
ne prouvent pas l'existence des mêmes utilisateurs dans la base.

Le frontend utilise `/api`. Vite relaie les requêtes vers `localhost:4000`.
Si `VITE_API_URL` est défini, il remplace cette adresse. Une URL externe exige
une configuration CORS côté serveur. Le proxy Vite concerne le développement ;
en déploiement, prévoir aussi le relais `/api` sur le serveur web.

`CLOCK_USE_MOCK = false` active l'API réelle pour les pointages.
`USE_MOCK = true` conserve la simulation pour les autres parties du groupe.
Les deux modes sont indiqués séparément dans le pied de page.
Le projet réutilise son service HTTP basé sur fetch ; Axios n'est pas ajouté.

## Vérifications

- `npm run build`
- `npm run test:clocks` : 11 tests de logique du composant, de contrat HTTP,
  d'erreurs, de requêtes concurrentes, de dates et du simulateur.
  Les appels HTTP de ces tests sont simulés, sans PostgreSQL.
- Vérification réalisée dans le navigateur avec le backend Phoenix du projet,
  une base de test séparée et des utilisateurs en transaction : arrivée, sortie,
  rechargement de la page, changement d'utilisateur et réponse 404.

Le backend enregistre des événements Clock ; il ne crée pas automatiquement
les WorkingTimes. Les graphiques et le calcul des périodes restent une autre
partie du projet. Plusieurs navigateurs peuvent envoyer simultanément le même
statut : une garantie d'alternance globale demanderait une règle côté serveur.
