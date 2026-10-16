# Pointage - partie Jonas

Le composant `src/components/ClockManager.vue` utilise l'Options API.
La route `/clock/:userid` lui transmet `userId`. Un watcher recharge les
pointages à l'ouverture et au changement d'utilisateur.

L'accueil (`EmployeeToday.vue`) affiche aussi ce composant, avec un bouton rond
« Pointer mon arrivée / mon départ ». Il attend que le profil fournisse `userId`
avant de charger les pointages. Son événement `changed` remonte à `App.vue`,
qui recharge les périodes après chaque pointage confirmé. La carte « Semaine
dernière » reste limitée à cette semaine-là ; les sorties d'aujourd'hui sont
visibles dans « Mes heures » sur la semaine courante.

## Compléter un départ oublié

- Après **24 heures sans départ**, l'accueil affiche « Départ à vérifier » et
  « Compléter ». C'est une règle de vérification, pas la preuve d'un oubli :
  un service de nuit ne déclenche pas une alerte au seul passage de minuit.
- Le même formulaire apparaît dans « Mes heures », sur la semaine de l'arrivée.
  Un jour sans période mais avec un départ à vérifier affiche « À compléter ».
- L'utilisateur saisit la date et l'heure **réelles**, avec les secondes, puis
  clique sur « Confirmer ». Le champ est vide au départ ; aucune heure n'est devinée.
- La saisie utilise l'heure locale du navigateur, convertie en UTC pour Phoenix.
  Le départ doit suivre le dernier pointage, ne pas être futur et dater de moins
  de 7 jours. Une pause reste exclue du temps travaillé.
- Le serveur enregistre un départ et ferme le segment travaillé dans une même
  transaction. L'alerte disparaît et le compteur, les périodes et les totaux sont
  rechargés. La semaine sélectionnée reste la même.
- Si les pointages ont changé depuis l'ouverture du formulaire, la correction
  est refusée. Après une erreur d'envoi, il faut actualiser avant de réessayer.

`MissingDeparture.vue` contient le formulaire réutilisé par `EmployeeToday.vue`
et `WeekTable.vue`. `utils/missingDeparture.js` contient les règles de date.
`clockService.completeDeparture()` appelle
`POST /api/clocks/:userID/:clockID/complete` avec
`{ "clock": { "time": "YYYY-MM-DD hh:mm:ss" } }`.
`clockID` est l'identifiant du dernier pointage lu, vérifié sous verrou côté serveur
pour éviter de fermer un autre service ou de créer deux périodes.

Cette fonction termine uniquement le service actuellement ouvert. Elle ne
reconstitue pas les anciens services déjà fermés.

## Départs à vérifier côté responsable

`TeamOverview.vue` lit les utilisateurs et les pointages de chaque membre de
l'équipe configurée. La règle des 24 heures est la même que côté employé.
L'alerte indique le nom du salarié et la date réelle de son arrivée, y compris
pendant une pause. Un profil absent ou une erreur de lecture est signalé comme
« Pointages non vérifiés », sans inventer un départ oublié.

- « Demander l'heure à … » ouvre un **brouillon d'e-mail** dans la messagerie
  configurée sur l'appareil, avec l'adresse issue de l'API et la date du service.
  Le responsable choisit de l'envoyer ; l'application n'envoie pas de notification.
- Si l'adresse manque ou est invalide, l'interface propose de contacter directement
  le salarié, sans fabriquer de destinataire.
- « Actualiser » recharge les pointages et les heures : l'alerte disparaît après
  la correction effectuée par le salarié.
- Une feuille avec un départ manquant dans la semaine affichée, ou avec des
  pointages non vérifiés, est exclue de la sélection et de la validation.

La composition de l'équipe et les noms affichés restent ceux de `mocks/org.js`,
déjà utilisés par cette page. Les identifiants, e-mails, pointages et périodes
viennent de l'API en mode réel. Il n'y a pas encore de gestion des équipes ni
de messagerie côté backend ; la validation des feuilles reste le mécanisme
local existant. Le nom « Sara » n'est plus une alerte codée en dur.

## Pauses simples

- Au travail : « Prendre une pause » fige le compteur et affiche « En pause ».
- En pause : « Reprendre » relance le compteur au temps déjà travaillé.
- « Pointer mon départ » permet aussi de terminer le service depuis une pause.
- L'état et le temps travaillé sont retrouvés après un rechargement, depuis l'API.

Exemple : arrivée à 9 h, pause de 10 h à 10 h 30, départ à 12 h = **2 h 30 de travail**.
Deux périodes sont enregistrées dans « Mes heures » : 9 h–10 h et 10 h 30–12 h.
Les pauses ne créent aucune période travaillée.

La colonne `kind` distingue quatre événements : `arrival`, `pause`, `resume`,
`departure`. `status` reste un booléen : vrai pour arrivée/reprise, faux pour
pause/départ. Les anciens appels sans `kind` conservent arrivée/départ.
La migration `20261005071118_add_kind_to_clocks.exs` doit être appliquée avec
`mix ecto.migrate` sur chaque base utilisée. Elle conserve les anciens pointages.

- `refresh()` lit `GET /api/clocks/:userID` et reconstruit le service et ses pauses
  (ordre du backend : date, puis identifiant, croissants).
- `clock()` crée un événement avec `POST /api/clocks/:userID` et le corps
  `{ "clock": { "time": "YYYY-MM-DD hh:mm:ss", "status": true, "kind": "arrival" } }`.
- `startDateTime` est le début du segment travaillé actuel, ou `null` en pause/hors service.
  `clockIn` indique le travail actif ; `onBreak` distingue une pause d'un départ.
- Un chronomètre `Temps travaillé : HH:mm:ss` apparaît pendant un service connu.
  `currentTime` est actualisé chaque seconde par `startTimer()` ; `elapsedTime`
  additionne `workedSeconds` (travail avant les pauses) et la durée du segment
  en cours en UTC. Aucune requête API par seconde. `restoreClockState()` relit
  les événements pour retrouver ce total après rechargement.
  `stopTimer()` arrête la minuterie à la pause, à la sortie, au changement d'utilisateur,
  lors d'une lecture/écriture incertaine et lorsqu'on quitte le composant.
- Les dates de pointage utilisent UTC, comme le champ Ecto `:utc_datetime`.
  Phoenix renvoie `time` au format texte `YYYY-MM-DD hh:mm:ss`, en UTC.
  `utils/clockDate.js` conserve aussi la compatibilité avec les anciennes réponses ISO.
- Les heures affichent les secondes (`09:15:42`), et les durées aussi
  (`2h 03m 17s`). Les champs de modification conservent cette précision.
- Les boutons attendent la réponse API. Un échec d'écriture impose une
  actualisation avant une nouvelle tentative, car le résultat peut être incertain.

## Démarrage local

Dans le backend : `mix deps.get`, `mix ecto.migrate`, puis `mix phx.server`.
PostgreSQL, les migrations et un utilisateur réel doivent être disponibles.

Dans ce dossier : `npm ci`, puis `npm run dev`.
Ouvrir `/clock/ID` avec l'identifiant d'un utilisateur existant dans PostgreSQL.
Le sélecteur User lit les utilisateurs de la même API que les pointages.
Un utilisateur doit exister dans PostgreSQL pour pouvoir pointer.

Le frontend utilise `/api`. Vite relaie les requêtes vers `localhost:4000`.
Si `VITE_API_URL` est défini, il remplace cette adresse. Une URL externe exige
une configuration CORS côté serveur. Le proxy Vite concerne le développement ;
en déploiement, prévoir aussi le relais `/api` sur le serveur web.

Les pointages utilisent l'API réelle, sauf pour une session de démonstration
par organisation (`auth.organizationSession`), qui utilise `organizationWork.js`.
L'ancien simulateur indépendant `mocks/clocks.js`, inaccessible derrière une
constante fixée à `false`, a été supprimé avec ses branches et son test dédié.
`USE_MOCK = false` permet aux périodes, aux utilisateurs et aux totaux de lire la même API.
La démonstration par organisation conserve ses pointages et périodes dans le navigateur.
Le projet réutilise son service HTTP basé sur fetch ; Axios n'est pas ajouté.

## Vérifications

- `npm run build`
- `npm run test:clocks` : 50 tests de logique des composants, de contrat HTTP,
  d'erreurs, de requêtes concurrentes, de dates et du chronomètre.
  L'horloge contrôlée vérifie les reprises, les arrêts et les retards de minuterie.
  Les appels HTTP de ces tests sont simulés, sans PostgreSQL.
- Les tests de pause couvrent plusieurs pauses, la reprise après rechargement,
  le départ pendant une pause, le changement d'utilisateur et un appel dont la réponse est perdue.
- Les tests de départ oublié couvrent le seuil de 24 h, les dates invalides,
  le changement d'heure, une réponse perdue et le rechargement des totaux.
- Les tests du responsable couvrent les alertes par salarié, le contenu du
  brouillon, les adresses absentes, les erreurs partielles, le rechargement après
  correction et l'exclusion des feuilles incomplètes de la validation.
- La vue du responsable a aussi été vérifiée dans le navigateur avec une API
  simulée, sur ordinateur et téléphone : alerte réelle pour le scénario fourni,
  erreur partielle visible et disparition de l'alerte après « Actualiser ».
  Le lien de brouillon a été inspecté ; aucun e-mail n'a été envoyé.
- Le formulaire a été vérifié dans le navigateur sur l'accueil et « Mes heures »,
  sur grand et petit écran, avec des réponses API simulées. Les tests backend
  vérifient séparément l'enregistrement réel dans PostgreSQL, y compris deux
  validations simultanées. Les secondes du départ sont conservées et visibles
  dans le tableau ; les cartes de total gardent leur affichage arrondi existant.
- Vérification réalisée dans le navigateur avec le backend Phoenix du projet,
  une base de test séparée et des utilisateurs en transaction : arrivée, sortie,
  rechargement de la page, changement d'utilisateur et réponse 404.

## Liaison entre pointages et périodes

Une arrivée ou une reprise (`status: true`) ouvre un segment de travail.
Une pause ou une sortie ferme ce segment et crée automatiquement une ligne `workingtime` :
`start` est la dernière arrivée/reprise, `end` la pause/sortie, pour le même utilisateur.
Un départ pendant une pause ferme le service sans ajouter de période.
L'API conserve sa réponse habituelle `{ "data": { ...clock } }` avec le statut 201.

La création de la sortie et de la période se fait dans une transaction PostgreSQL.
Si l'une échoue, aucune des deux n'est enregistrée. Le verrou sur l'utilisateur
empêche deux demandes simultanées de fermer deux fois la même arrivée.
Une action incohérente (deux pauses successives, reprise hors pause…), une date
antérieure au dernier pointage ou une période de durée nulle sont refusées (HTTP 422).

L'événement `changed` du composant recharge les totaux et la liste des périodes
sur la vue d'ensemble, sans effacer ses filtres. Sur `/clock/:userid`,
le même événement recharge les totaux via `routeListeners` dans `App.vue`. Les heures ne sont comptabilisées
qu'à la fermeture d'un segment (pause ou sortie). Les durées sont calculées en UTC, indépendamment du changement
vers l'heure d'été ou d'hiver.

Les anciennes paires arrivée/sortie ne sont pas reconstruites automatiquement :
un rattrapage nécessite d'abord de vérifier les périodes déjà saisies manuellement.
Une arrivée ancienne encore ouverte peut être fermée par une nouvelle sortie.
Les doublons de saisie manuelle et les chevauchements entre périodes ne sont pas
interdits par cette correction.

`ChartManager.vue` contient encore des graphiques d'exemple ; le membre du groupe
responsable des graphiques doit les brancher sur les vraies périodes.

## Validation de la liaison

- Backend : `mix precommit` (155 tests, dont API, pauses, départs oubliés, transaction et accès concurrents).
- Frontend : `npm run build`, `npm run test:clocks`, ESLint sur les fichiers modifiés.
- Les tests utilisent une base PostgreSQL séparée. La migration additive est
  aussi appliquée en développement ; elle renseigne `kind` sur les anciens
  événements sans reconstruire leurs périodes ni modifier leurs dates.

## Audit Web du 8 octobre 2026

Périmètre examiné : ClockManager, MissingDeparture, services HTTP et pointage,
utilitaires de dates, simulations, routeur, relais des événements dans App et
EmployeeToday, WeekTable et TeamOverview ; contexte Clocks, schéma Clock,
contrôleur, JSON, OpenAPI, autorisations, migrations, associations et création
des WorkingTimes côté Phoenix. Les templates, styles et règles responsive
de ClockManager sont inchangés ; aucune intégration Cordova/Capacitor n'a été modifiée.

### Confrontation aux sujets fournis

| Exigence | Constat |
| --- | --- |
| Thème 01 : time, status et utilisateur obligatoires | Schéma Ecto et contraintes SQL présents ; false est accepté. |
| Thème 01 : GET et POST /api/clocks/:userID | Routes présentes ; le POST traite arrivée et départ, ainsi que pause/reprise. |
| Thème 02 : ClockManager et /clock/:userid | Composant et route présents, avec userId transmis en prop. |
| Thème 02 : startDateTime, clockIn, refresh(), clock() | Présents ; startDateTime vaut null hors segment actif. |
| Thème 02 : YYYY-MM-DD hh:mm:ss | Envoi, état du composant et réponses JSON Clock conformes ; les heures restent en UTC. |
| Thème 02 : une vue App.vue, composants dans src/components | L'application actuelle utilise aussi src/views : écart global au sujet historique. |

Aucune fonction de pointage obligatoire ne manque. La conformité littérale de
l'organisation des vues reste à arbitrer pour une soutenance strictement limitée
aux thèmes 01/02. Le format JSON Clock a été aligné sur le sujet après la refactorisation.

### Limites déjà présentes

- Le serveur reçoit toujours l'heure du client, mais refuse désormais les dates
  futures sur le POST ordinaire comme sur le complément de départ (HTTP 422).
  La comparaison utilise l'heure UTC du serveur.
- Les créations/modifications manuelles de WorkingTimes ne réécrivent pas les
  Clocks. Les chevauchements et doublons avec des périodes manuelles ne sont pas
  empêchés. Ce point relève d'une règle commune avec le périmètre WorkingTime.
- L'historique complet est relu à chaque actualisation ; aucune pagination ou
  requête dédiée à l'état courant n'est prévue pour les historiques volumineux.
- Les tests Web exécutent la logique des composants et simulent HTTP. Cette
  intervention n'ajoute pas de parcours navigateur de bout en bout contre Phoenix.

### Validation de cette refactorisation

Avant modification : 147 tests Backend et 71 tests Web réussis après installation
des dépendances verrouillées. Après modification : 149 tests Backend via
`mix precommit`, 72 tests Web via `node --test test/*.test.js`, build Vite,
ESLint et Oxlint sur les fichiers Web modifiés réussis. Aucun test ignoré.

Quatre cas de régression ont été ajoutés : utilisateur supprimé, ordre des
pointages à la même seconde, événement invalide et réponse d'écriture tardive
après changement d'utilisateur. Le seul test retiré couvrait le simulateur
inaccessible supprimé ; les tests du mode démonstration actif sont conservés.

Vite signale une collision sur son port WebSocket de développement lors de
l'exécution parallèle des suites ; les assertions passent malgré ce message.
Les dépendances et leurs fichiers de verrouillage n'ont pas été mis à jour.

### Mise en conformité du contrat Clock

`ClockJSON` formate `time`, seul champ temporel exposé par cette ressource, avec
`Calendar.strftime/2` pour GET, POST et complément de départ. Les dates restent
des DateTime UTC en base ; les réponses n'ajoutent ni fuseau ni fractions de seconde.
OpenAPI décrit le format de sortie strict et les deux formats d'entrée acceptés.

Le contexte Clocks refuse les dates futures avant toute insertion, y compris
pour les appels directs sans contrôleur. Les tests vérifient les quatre types
de pointage, l'absence d'écriture sur refus, l'acceptation de la seconde courante,
la conversion d'une entrée avec décalage horaire et le format des réponses.
Validation Backend : `mix precommit`, 155 tests réussis.
