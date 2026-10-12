# Time Manager Mobile

Application mobile Vue 3 (Options API) + Cordova, d'après la maquette Figma et
les sujets Time Manager (projet principal, API, mobile).

| Fonction | Agent | Responsable | Administration (DG) |
| --- | :-: | :-: | :-: |
| Pointer arrivée, pause, reprise, départ (même hors ligne) | ✓ | ✓ | ✓ |
| Tableau de bord : heures par jour / par semaine sur une période, jour/nuit | ✓ | ✓ | ✓ |
| Historique des pointages | ✓ | ✓ | ✓ |
| Modifier prénom, nom, identifiant, e-mail ; changer son mot de passe | ✓ | ✓ | ✓ |
| Supprimer son compte (mot de passe actuel demandé) | ✓ | ✓ | ✓ |
| Compléter un départ oublié (route `complete` du serveur) | ✓ | ✓ | ✓ |
| Corriger les heures d'un agent (ajouter, modifier, supprimer une période) | | son équipe | l'organisation |
| Moyennes quotidiennes / hebdomadaires de l'équipe sur une période | | ✓ | ✓ (toutes) |
| Tableau de bord et historique d'un agent | | ses équipes | tous |
| Planning d'équipe | | ✓ | |
| Tableau de bord de l'organisation : demandes, membres, managers, employés, équipes, heures | | | ✓ (accueil) |
| Demandes d'adhésion : accepter (mot de passe confirmé) ou refuser (motif), historique | | | ✓ |
| Créer un compte, réinitialiser un mot de passe, promouvoir / rétrograder, supprimer | | | ✓ |
| Créer / renommer / supprimer une équipe, responsable, membres | | | ✓ |


L'heure est affichée en permanence en haut de l'écran. Thèmes Clair / Nuit /
Contraste élevé et textes renforcés (handicap visuel). Graphiques : couleurs
vérifiées pour le daltonisme, détail au toucher et version tableau.

## Architecture

```text
src/
├── main.js, App.vue, router/      # démarrage, routes protégées par rôle
├── layouts/MobileLayout.vue       # bandeau réseau + page + barre d'onglets
├── views/                         # un fichier par écran
├── components/                    # morceaux d'écran (dashboard/, history/, admin/…)
├── data/mock.js                   # données fictives
├── services/
│   ├── source.js                  # choisit api.js ou mockApi.js
│   ├── api.js / mockApi.js        # même interface : vrai serveur / faux serveur
│   ├── mock/                      # faux serveur : mêmes règles d'accès que le backend
│   ├── manageService.js           # profil, rôles, équipes (en ligne seulement)
│   ├── http.js                    # cookie + en-tête X-CSRF-Token
│   ├── authService.js             # connexion, session, expiration
│   ├── dataService.js             # getUser, getPlanning, getMesHeures, getPointages (+ cache)
│   ├── clockService.js            # état du pointage, recordClock()
│   ├── syncService.js             # file d'attente -> serveur, dans l'ordre, sans doublon
│   ├── network.js, appState.js    # en ligne / hors ligne / serveur injoignable
├── storage/                       # localStorage de la WebView, rangé par utilisateur
├── native/                        # deviceready, réseau, vibration (plugins Cordova)
└── ui/                            # calculs et mises en forme sans interface
```

## Comment marche le hors ligne

1. Un clic sur « Pointer » écrit d'abord l'action sur le téléphone
   (`storage/outboxStore.js`) avec un identifiant unique et l'**heure réelle**.
2. L'écran confirme : « Arrivée enregistrée sur ce téléphone · En attente d'envoi ».
3. `syncService` envoie les actions du compte connecté **une par une, dans l'ordre**
   au retour du réseau, au retour dans l'app, et toutes les 30 s s'il en reste.
4. Réponse perdue : avant de renvoyer une action déjà tentée, on relit les
   pointages du serveur. Si elle y est déjà (même type, même heure), on ne la
   renvoie pas. Le serveur n'a pas d'identifiant anti-doublon : ce contrôle
   se fait donc côté mobile.
5. Refus du serveur (422) : l'action passe « À vérifier » et reste visible dans
   Mon compte. Elle n'est jamais effacée en silence.
6. Les files, caches et sessions sont rangés par identifiant d'utilisateur :
   un autre compte n'envoie jamais les actions de quelqu'un d'autre.

## Démarrer

```sh
npm ci
npm run dev        # ouvre http://localhost:5173 ; /api est relayé vers le serveur
```

Sans réglage, l'app utilise le serveur déployé `http://34.155.104.175:8080/api`
(la console de `npm run dev` affiche « API : /api est relayé vers … »).
Pour changer, créer `.env.local` (modèle : `.env.example`) :

| Variable | Valeur |
| --- | --- |
| `VITE_DATA_SOURCE` | `api` (serveur réel, par défaut) ou `mock` (données fictives, sans serveur) |
| `VITE_API_URL` | adresse du serveur terminée par `/api` |

Relancer `npm run dev` (ou reconstruire l'APK) après chaque changement.

### Comment l'app parle au serveur

Le serveur refuse les écritures venant d'une autre adresse que la sienne
(plug `CheckOrigin`) et pose un cookie `SameSite=Strict` sans CORS. Il ne
connaît que le site web servi à la même adresse. Sans toucher au backend :

- **Téléphone** : les requêtes passent par le réseau natif d'Android
  (`cordova-plugin-advanced-http`) : ni en-tête `Origin`, ni CORS, et le
  cookie de session est gardé par le plugin. `config.xml` autorise le HTTP
  simple (`usesCleartextTraffic`), car le serveur n'est pas en HTTPS.
- **Navigateur** (`npm run dev`) : l'app appelle `/api` ; Vite relaie vers
  `VITE_API_URL` en retirant `Origin` et `Referer`.

### Écran de connexion (comme le web)

Deux choix seulement : **Connexion** et **Rejoindre Gotham City**. Une seule
organisation, retrouvée par son nom exact (`VITE_ORGANIZATION_NAME`, par défaut
`Gotham City`) ; un compte qui n'y est pas rattaché est refusé à la connexion.
Rejoindre = profil (prénom, nom, e-mail, genre, date et lieu de naissance),
sans mot de passe ; la référence de suivi est gardée sur le téléphone et le
statut s'actualise depuis le même onglet. Pas de création d'organisation ni
d'inscription directe : le super administrateur est créé côté serveur, puis il
accepte les demandes en choisissant le mot de passe à transmettre.

### Mode démo

Comptes de démonstration (mot de passe `demo1234`) : `messline@example.com`
(agent), `manager@example.com` (responsable), `admin@example.com` (administration).

En mode mock, la carte « Outils de test » de Mon compte coupe le serveur fictif,
perd une réponse ou fait expirer la session : elle sert à montrer le hors ligne
en démonstration sans toucher au Wi-Fi. Elle n'existe pas en mode API.
Pour repartir de zéro : vider le stockage du site (outils du navigateur).

## Plugins Cordova

| Plugin | Utilisation |
| --- | --- |
| `cordova-plugin-network-information` | savoir si le téléphone a Internet |
| `cordova-plugin-vibration` | vibration discrète après un pointage |
| `cordova-plugin-dialogs` | vraies boîtes de confirmation Android (suppressions) |
| `cordova-plugin-advanced-http` | requêtes natives vers le serveur (voir plus haut) |

Autres éléments natifs : sélecteurs de date du téléphone, bouton retour Android
(quitte depuis l'accueil, sinon page précédente).

Le mobile suit le serveur déployé (branche `authentification_christ`) : tous
les endpoints de son Swagger sont utilisés, voir `src/services/api.js`.

## À régler côté serveur (hors du dossier mobile)

- Aucune route « planning » : en mode api, le planning affiche « Aucun planning publié ».
- Composer les équipes est réservé à l'administration : le responsable consulte
  ses équipes mais ne peut pas les modifier.
- Pas d'identifiant d'action côté serveur : l'anti-doublon des pointages repose
  sur une relecture des pointages avant chaque nouvel essai.
- Serveur en HTTP : à passer en HTTPS (puis `COOKIE_SECURE=true` et retirer
  `usesCleartextTraffic` de `config.xml`).

## Compatibilité Android

- Cordova 12 installe `cordova-android` 12 : **Android 7.0 (API 24) minimum**.
- L'app tourne dans le WebView Android (Chrome intégré). Le build convertit la
  syntaxe récente (`chrome69`) et `src/native/polyfills.js` ajoute les fonctions
  manquantes : un WebView ancien mais à jour du Play Store suffit.
- Taille d'écran : testé de 320 px à 720 px de large, portrait.

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

## Vérifier

Scénarios testés dans le navigateur (mode mock) : connexion, consultation,
arrivée hors ligne, fermeture/réouverture, retour du réseau, arrivée + pause +
départ hors ligne dans l'ordre, réponse perdue sans doublon, session expirée,
changement de compte, serveur indisponible avec données en cache, largeur 320 px,
retour arrière et second onglet après changement de compte, pointage des trois
rôles, promotion, création d'équipe. Le mode API a été testé contre un serveur
qui imite les réponses Phoenix (cookie HttpOnly + X-CSRF-Token).
À refaire sur un vrai téléphone : Wi-Fi/données coupés, vibration, fermeture
forcée de l'app.

Références : [Cordova](https://cordova.apache.org/docs/en/latest/config_ref/index.html),
[plateformes](https://cordova.apache.org/docs/en/latest/guide/cli/index.html),
[Vite](https://vite.dev/config/build-options.html).
