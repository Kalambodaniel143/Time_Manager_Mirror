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
- Les heures affichent les secondes (`09:15:42`), et les durées aussi
  (`2h 03m 17s`). Les champs de modification conservent cette précision.
- Les boutons attendent la réponse API. Un échec d'écriture impose une
  actualisation avant une nouvelle tentative, car le résultat peut être incertain.

## Démarrage local

Dans le backend : `mix deps.get`, puis `mix phx.server`.
PostgreSQL, les migrations et un utilisateur réel doivent être disponibles.

Dans ce dossier : `npm ci`, puis `npm run dev`.
Ouvrir `/clock/ID` avec l'identifiant d'un utilisateur existant dans PostgreSQL.
Le sélecteur User lit les utilisateurs de la même API que les pointages.
Un utilisateur doit exister dans PostgreSQL pour pouvoir pointer.

Le frontend utilise `/api`. Vite relaie les requêtes vers `localhost:4000`.
Si `VITE_API_URL` est défini, il remplace cette adresse. Une URL externe exige
une configuration CORS côté serveur. Le proxy Vite concerne le développement ;
en déploiement, prévoir aussi le relais `/api` sur le serveur web.

`CLOCK_USE_MOCK = false` active l'API réelle pour les pointages.
`USE_MOCK = false` permet aux périodes, aux utilisateurs et aux totaux de lire la même API.
Les modes de simulation séparés ne reproduisent pas cette liaison automatique.
Les deux modes sont indiqués séparément dans le pied de page.
Le projet réutilise son service HTTP basé sur fetch ; Axios n'est pas ajouté.

## Vérifications

- `npm run build`
- `npm run test:clocks` : 15 tests de logique du composant, de contrat HTTP,
  d'erreurs, de requêtes concurrentes, de dates et du simulateur.
  Les appels HTTP de ces tests sont simulés, sans PostgreSQL.
- Vérification réalisée dans le navigateur avec le backend Phoenix du projet,
  une base de test séparée et des utilisateurs en transaction : arrivée, sortie,
  rechargement de la page, changement d'utilisateur et réponse 404.

## Liaison entre pointages et périodes

Une arrivée (`status: true`) ouvre le travail sans créer de période complète.
Une sortie (`status: false`) crée automatiquement une ligne `workingtime` :
`start` est la date de la dernière arrivée, `end` celle de la sortie, pour le même utilisateur.
L'API conserve sa réponse habituelle `{ "data": { ...clock } }` avec le statut 201.

La création de la sortie et de la période se fait dans une transaction PostgreSQL.
Si l'une échoue, aucune des deux n'est enregistrée. Le verrou sur l'utilisateur
empêche deux demandes simultanées de fermer deux fois la même arrivée.
Une sortie sans arrivée, un statut répété, une date antérieure au dernier pointage,
ou une période de durée nulle sont refusés (HTTP 422).

L'événement `changed` du composant recharge les totaux et la liste des périodes
sur la vue d'ensemble, sans effacer ses filtres. Sur `/clock/:userid`,
le même événement recharge les totaux via `routeListeners` dans `App.vue`. Les heures ne sont comptabilisées
qu'à la sortie. Les durées sont calculées en UTC, indépendamment du changement
vers l'heure d'été ou d'hiver.

Les anciennes paires arrivée/sortie ne sont pas reconstruites automatiquement :
un rattrapage nécessite d'abord de vérifier les périodes déjà saisies manuellement.
Une arrivée ancienne encore ouverte peut être fermée par une nouvelle sortie.
Les doublons de saisie manuelle et les chevauchements entre périodes ne sont pas
interdits par cette correction.

`ChartManager.vue` contient encore des graphiques d'exemple ; le membre du groupe
responsable des graphiques doit les brancher sur les vraies périodes.

## Validation de la liaison

- Backend : `mix precommit` (33 tests, dont API, transaction et accès concurrents).
- Frontend : `npm run build`, `npm run test:clocks`, ESLint sur les fichiers modifiés.
- Les tests utilisent une base PostgreSQL séparée ; aucune reprise des anciens
  pointages ni modification des données de développement n'est effectuée.
