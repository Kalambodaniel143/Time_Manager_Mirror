# Time Manager Mobile

Socle Vue en Options API + Cordova restauré. Il contient des écrans de départ
et la navigation. Authentification mobile, stockage et synchronisation restent
à implémenter. Les boutons métier sont désactivés ; les squelettes des services
lèvent `NOT_IMPLEMENTED` au lieu de simuler une sauvegarde réussie.

## Répartition

| Dossier | Responsable | Rôle |
| --- | --- | --- |
| `src/views/`, `components/`, `layouts/`, `assets/`, `router/` | Messline | Écrans, styles, navigation |
| `src/services/`, `storage/`, `native/`, `config/api.js` | Jonas | Session, cache, pointages et synchronisation |
| `config.xml`, `vite.config.js`, plateformes Cordova | Messline, avec Jonas pour l'API | Installation mobile |
| `../shared/` | Commun | Code réutilisable et chemins courts |
| `../time_manager/` | Développeur backend | API commune |

## Architecture

```text
time-manager-mobile/
├── config.xml
├── package.json
├── vite.config.js
├── jsconfig.json
├── index.html
├── src/
│   ├── main.js
│   ├── App.vue
│   ├── config/api.js
│   ├── router/index.js
│   ├── layouts/MobileLayout.vue
│   ├── views/                 # Connexion, Pointage, Heures, Planning, Profil
│   ├── components/
│   │   ├── navigation/BottomTabs.vue
│   │   └── clock/ClockActions.vue
│   ├── assets/main.css
│   ├── services/              # authService, clockService, workingTimeService, syncService, http
│   ├── storage/               # database, sessionStorage, cacheStore, outboxStore
│   └── native/lifecycle.js
└── www/                       # Build généré, ne pas modifier à la main
```

À côté, `shared/` contient `components/ui/`, `services/` et `utils/`.

## Démarrer

Depuis ce dossier, avec la version Node indiquée dans `package.json` :

```sh
npm ci
npm run dev
```

Les quatre onglets permettent de voir les écrans. La connexion est accessible
depuis Profil. Cet aperçu est public et ne contient aucune donnée personnelle.
Jonas devra brancher la session et protéger les routes avant intégration réelle.

```sh
npm run build
npm run preview
```

Vite écrit dans `www/`. Les builds navigateur et Cordova remplacent ce dossier.
Avant `preview`, relancer `build` si le dernier build était `build:cordova`.

## Préparer Android

Après installation du SDK et du JDK requis par la plateforme choisie :

```sh
npm run build:cordova
npm run cordova -- platform add android
npm run cordova -- requirements android
npm run android:build
npm run android:run
```

L'ajout de plateforme enregistrera sa version : versionner le manifeste et le
verrou npm, pas les dossiers générés `platforms/` et `plugins/`.
Ce socle ne préinstalle ni plateforme Android, ni SDK, ni plugin de stockage.
Le build Cordova ajoute `cordova.js` (fourni ensuite par Cordova) ; le démarrage
attend `deviceready`. Le navigateur démarre sans ce script.

## Imports courts

```js
import AppIcon from '@shared/components/ui/AppIcon.vue'
import { getClockState } from '@/services/clockService.js'
```

`@` désigne `src/` et `@shared` désigne `../shared/`. Vite et l'éditeur disposent
de ces alias. L'icône partagée réutilise encore son implémentation web : garder
le dépôt complet pour construire le mobile. Le client HTTP générique est dans
`shared/services/apiClient.js`, car son ancien fichier web a disparu.

## API et session

Copier `.env.example` vers `.env.local`. En développement navigateur, la valeur
vide utilise `/api` et le proxy vers `http://localhost:4000`.
Sur téléphone, renseigner `VITE_API_URL` avec l'URL HTTPS réelle terminée par
`/api`, puis autoriser son origine exacte dans `config.xml`.
Sans URL explicite, le client du build refuse les appels réseau.
`localhost` sur un téléphone n'est pas l'ordinateur de développement.
Les variables Vite sont publiques : aucun secret ne doit y être placé.

Le dépôt restauré contient des hooks de session/CSRF dans le client HTTP web.
Cette restauration ne les remplace pas et ne valide pas leur compatibilité
mobile. Jonas doit vérifier le contrat serveur actuel (cookies, CSRF, expiration,
origines CORS) avant de brancher la connexion.
Avant diffusion, définir aussi une CSP correspondant aux origines réelles ;
ce socle n'est pas une configuration de production.

## Prochaines intégrations

- `login`, `restoreSession`, `logout` : gestion de session réelle.
- `getClockState`, `recordClock(kind)` : état calculé et écriture locale durable.
- `getWorkingTimes` : données avec `source`, `updatedAt`, `stale`.
- `syncNow`, `subscribe(listener)` : envoi et états de synchronisation.
- Stockage : partition par compte, transactions, reprise après fermeture.
- Planning : confirmer le contrat backend ; ne pas confondre planning et heures réalisées.

Les paramètres et retours détaillés sont à définir ensemble. `sessionStorage.js`
désigne un futur adaptateur protégé, pas `window.sessionStorage` ni `localStorage`.
Le mot de passe ne doit jamais être persisté.

## Vérifier cette étape

1. Construire le mobile avec `npm run build` puis `npm run build:cordova`.
2. Ouvrir les quatre onglets et la connexion ; recharger une route avec hash.
3. Vérifier l'affichage à 320 px et les boutons métier désactivés.
4. Vérifier le build web après toute extraction de composants partagés.
5. Tester sur téléphone après installation de la plateforme : un build Vite
   réussi ne valide pas les fonctions natives ni la synchronisation.

Références : [Cordova](https://cordova.apache.org/docs/en/latest/config_ref/index.html),
[plateformes](https://cordova.apache.org/docs/en/latest/guide/cli/index.html),
[Vite](https://vite.dev/config/build-options.html).
