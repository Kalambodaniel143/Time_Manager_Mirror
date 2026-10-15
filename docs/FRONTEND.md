# Frontend Vue 3 — ce que voit l'utilisateur

Le frontend est la partie visible de Time Manager. Il affiche les écrans, recueille les actions et explique les erreurs. Phoenix garde la décision finale sur chaque action.

Son code se trouve dans `time-manager-dashboard/` et utilise Vue 3, Vue Router 5 et Vite 8. Le projet n'utilise ni Pinia ni Vuex. La session et le contexte de travail sont conservés dans de petits objets réactifs partagés entre les écrans.

Pour suivre un clic, partez d'un composant dans `src/components/` ou d'une page dans `src/views/`. Cherchez ensuite le service appelé dans `src/services/`. Ce service construit la requête envoyée à Phoenix par `services/http.js`.

## Organisation

Le tableau sert de carte. Il indique où chercher selon le problème observé : navigation, session, appel réseau, écran ou style.

| Zone | Fichiers | Responsabilité |
|---|---|---|
| Initialisation | `src/main.js`, `src/App.vue` | Créer Vue, installer i18n et le routeur, charger le contexte connecté. |
| Navigation | `src/router/index.js` | Routes, restauration de session et gardes d'interface. |
| Session | `src/stores/auth.js` | Utilisateur, organisation, CSRF, changement de compte et déconnexion. |
| Transport | `src/services/http.js` | `fetch`, cookie, CSRF, pagination, erreurs et reprise contrôlée après 401. |
| Services métier | `src/services/*.js` | Adapter les composants aux endpoints Phoenix. |
| Écrans | `src/views/` | Pages principales par rôle. |
| Composants | `src/components/` | Pointage, profil, heures, formulaires et composants métier réutilisables. |
| Simulation | `src/mocks/` | Démonstration locale explicitement activée. |
| Utilitaires | `src/utils/` | Dates, heures, validation, traduction, voix, toast et événements de session. |
| Style | `src/assets/main.css` | Variables de thème clair, nuit et contraste, mise en page responsive. |

## Routes de l'interface

Vue Router joue le rôle d'un panneau d'orientation. Il choisit l'écran à afficher et évite qu'un utilisateur arrive par erreur sur une page qui ne correspond pas à son rôle.

| URL | Nom | Composant | Accès affiché par le routeur |
|---|---|---|---|
| `/aide` | `help` | `HelpFaq` | Public, reste accessible connecté. |
| `/connexion` | `login` | `LoginScreen` | Public ; un utilisateur connecté est redirigé vers son accueil. |
| `/inscription` | `register` | `LoginScreen` | Public, mode adhésion. |
| `/notifications` | `notifications` | `Notifications` | Tous les rôles connectés. |
| `/profil` | `profile` | `Profile` | Tous les rôles connectés. |
| `/` | `overview` | `EmployeeToday` | Employé ; les autres rôles vont vers leur accueil. |
| `/planning` | `planning` | `EmployeePlanning` | Employé. |
| `/workingTimes/:userID` | `workingTimes` | `WorkingTimes` | Tous les rôles ; soi, ou responsable selon l'API. |
| `/workingTime/:userid` | `workingTimeCreate` | `WorkingTime` | Manager ou administrateur. |
| `/workingTime/:userid/:workingtimeid` | `workingTimeEdit` | `WorkingTime` | Manager ou administrateur. |
| `/clock/:userid` | `clock` | `ClockManager` | Tous les rôles, uniquement sur leur propre identifiant. |
| `/chartManager/:userid` | `chartManager` | `ChartManager` | Tous les rôles ; périmètre final vérifié par l'API. |
| `/equipe` | `team` | `TeamOverview` | Manager ou administrateur. |
| `/equipe/planning` | `teamPlanning` | `TeamPlanning` | Manager ou administrateur. |
| `/admin/organisation` | `organization` | `OrganizationAdmin` | Administrateur avec organisation. |
| `/admin/paie` | `payroll` | `PayrollMonth` | Administrateur. |
| `/admin/utilisateurs` | `adminUsers` | `AdminUsers` | Administrateur. |
| `/equipes` | `adminTeams` | `AdminTeams` | Manager ou administrateur. |
| `/admin/droits` | `rights` | `TeamsRights` | Administrateur. |
| Toute autre URL | — | redirection | Vers `overview`, puis garde selon la session. |

### Gardes de navigation

Avant chaque changement de page, `router.beforeEach` effectue les contrôles suivants :

1. appelle `fetchMe()` si la session n'a pas encore été vérifiée ;
2. renvoie un visiteur vers `/connexion` ;
3. contrôle `meta.roles` ;
4. refuse les écrans exigeant une organisation lorsqu'elle manque ;
5. compare les paramètres utilisateur au compte courant ;
6. refuse explicitement un autre identifiant sur la route de pointage `selfOnly`.

!!! warning "Limite volontaire"
    Ces gardes rendent la navigation plus claire. Elles ne suffisent pas à sécuriser les données, car une personne peut appeler l'API sans passer par l'écran. Phoenix répète donc les contrôles sur chaque endpoint.

## Session et transport HTTP

Après la connexion, le navigateur reçoit deux éléments complémentaires. Le cookie JWT prouve la session et reste inaccessible au code JavaScript. Le jeton CSRF accompagne les actions qui modifient des données et montre que la demande vient bien de l'application ouverte par l'utilisateur.

### Connexion

Quand l'utilisateur valide le formulaire, `organizationService.loginAccount()` appelle `POST /api/auth/login`. Phoenix vérifie les identifiants, puis renvoie les informations de session et le jeton CSRF. Il place le JWT dans un cookie `HttpOnly`, que JavaScript ne peut pas lire.

### Requêtes

Toutes les demandes passent ensuite par `services/http.js`. Ce fichier centralise les règles suivantes :

- utilise `API_URL`, `/api` par défaut ;
- ajoute `Content-Type: application/json` ;
- ajoute `X-CSRF-Token` lorsqu'une session existe ;
- utilise `credentials: 'same-origin'` pour transmettre le cookie ;
- transforme les réponses non réussies en `ApiError` ;
- déclenche le gestionnaire de session sur 401 ;
- refuse d'appliquer une réponse ancienne lorsqu'un changement de compte est détecté.

Si une session doit être restaurée, une requête peut être retentée une seule fois. `/auth/session` doit confirmer le **même identifiant utilisateur**. Cette vérification évite qu'une action commencée avec un compte soit rejouée après la connexion d'un autre compte.

### Stockage navigateur

Le navigateur conserve le minimum utile à la session. Les données métier restent dans PostgreSQL et sont relues par l'API.

| Donnée | Emplacement | Observation |
|---|---|---|
| JWT | Cookie `HttpOnly` | Inaccessible au JavaScript ; `Secure` en production. |
| CSRF | `sessionStorage`, clé `tm-csrf` | Séparé par onglet et remplacé à la session suivante. |
| Préférences de compte | API puis état réactif | Langue, thème, guide et voix viennent du backend en mode réel. |
| Signal inter-onglets | `BroadcastChannel` et événement `storage` | Transmet un signal de changement, pas le JWT. |
| Données métier réelles | PostgreSQL via API | Aucun stockage local de secours si l'API échoue. |
| Données de démonstration | Modules `src/mocks` | Uniquement si le mode de démonstration est explicitement actif. |

Lorsqu'un autre utilisateur se connecte, les composants sont recréés afin d'effacer les données encore affichées pour l'ancien compte. Un profil navigateur ne peut maintenir qu'une session Time Manager à la fois, car il ne possède qu'un cookie de session pour ce site.

## Services API

Les composants appellent un service spécialisé au lieu de construire chacun leurs propres URLs. Les échanges avec Phoenix restent ainsi au même endroit et sont plus simples à tester.

| Service | Domaine |
|---|---|
| `authService.js` | Connexion, vérification email, session, rôles et changement de rôle. |
| `organizationService.js` | Gotham City, demande d'adhésion, suivi et administration des membres. |
| `passwordRecoveryService.js` | Demande et validation d'un code de récupération. |
| `accountService.js` | Suppression de son propre compte. |
| `userService.js` | Lecture et mise à jour des utilisateurs. |
| `teamService.js` | Équipes, manager et membres. |
| `clockService.js` | Historique, pointage et départ oublié. |
| `workingTimeService.js` | Périodes travaillées. |
| `correctionService.js` | Demandes de correction et décisions. |
| `workforceService.js` | Règles, permissions, feuilles, plans, gardes, échanges, absences, paie, préférences, audit et notifications. |
| `reportService.js` | Agrégations de présentation et export local lorsque utilisé. |
| `orgService.js` | État de démonstration de l'organisation ; ne remplace pas l'API réelle. |

## Pointage dans l'interface

Au chargement, `ClockManager.vue` demande l'historique avec `getClocks(userId)`. Il reconstruit ensuite la situation actuelle : hors service, en service ou en pause. Le bouton propose l'action cohérente avec cette situation.

| État affiché | Action envoyée |
|---|---|
| Hors service | `arrival` |
| En service | `departure` ou `pause` |
| En pause | `resume` ou `departure` |

Pendant l'enregistrement, le bouton est désactivé pour limiter les doubles clics. Après un succès, le composant relit les données du serveur et affiche ce qui a réellement été enregistré. Après une erreur, il abandonne sa copie locale et demande un rafraîchissement : la réponse a pu se perdre alors que l'écriture a réussi.

!!! note "Qui décide ?"
    `ClockManager.vue` aide l'utilisateur à choisir la bonne action. `ClockController` et le contexte `Clocks` contrôlent encore l'identité, l'ordre des pointages, l'heure et l'état de la semaine avant toute écriture.

## Pagination et validation des réponses

Un long historique n'est pas téléchargé en une seule fois. Le frontend demande plusieurs pages et vérifie que le serveur lui fournit une suite cohérente.

`requestHistory()` suit `X-Next-Cursor` avec les limites suivantes :

- 20 pages maximum côté navigateur ;
- curseur numérique strictement croissant ;
- tableau obligatoire dans chaque réponse ;
- abandon si le compte change pendant la lecture.

Le backend borne chaque page entre 1 et 200 éléments, 100 par défaut.

## Mode réel et mode simulé

Le mode simulé sert à travailler sur l'interface sans backend. Il doit être demandé explicitement et Vite bloque sa présence dans un build destiné à un serveur.

```bash
npm run dev       # backend réel selon VITE_BACKEND_URL
npm run dev:demo  # mocks explicitement actifs
```

`src/config.js` exige aussi `import.meta.env.DEV` pour activer les mocks. `vite.config.js` refuse tout build si `VITE_USE_MOCK` ou `VITE_AUTH_USE_MOCK` vaut `true`. En build serveur, `VITE_API_URL` doit être absent ou égal à `/api`.

Il n'existe pas de véritable mode hors ligne ni de file de synchronisation. **Information non trouvée dans le dépôt** : application mobile ou synchronisation native.

## Internationalisation et accessibilité

- le catalogue anglais se trouve dans `src/locales/en.json` ; le français sert de texte source ;
- `utils/i18n.js` fournit `$t()` et la locale des dates/nombres ;
- trois thèmes existent : clair, nuit et contraste ;
- les composants utilisent des libellés visibles, des états de chargement, des alertes et des zones adaptées au clavier ;
- la synthèse vocale dépend des voix disponibles dans le navigateur.

La documentation MkDocs reprend la palette blanche et verte réellement utilisée dans `main.css` : vert principal `#24584f`, vert sombre `#19473f`, fond blanc et vert pâle `#edf4f1`.

## Tests et build

```bash
cd time-manager-dashboard
npm ci
npm run check
```

| Fichier de test | Périmètre principal |
|---|---|
| `auth.test.js`, `auth-api.test.js`, `auth-store.test.js` | Connexion, appels, session et changement de compte. |
| `gotham.test.js` | Organisation et adhésion. |
| `clocks.test.js` | Pointage, pauses, historique et erreurs. |
| `fusion-workflow.test.js`, `workforce-api.test.js` | Workflows, permissions et appels API. |
| `account-deletion.test.js` | Suppression de compte. |
| `input-policy.test.js` | Validation des entrées. |
| `real-backend.test.js` | Contrats attendus avec le backend réel. |

`npm run check` exécute ESLint, `node --test test/*.test.js` et `vite build`.

**Information non trouvée dans le dépôt** : rapport chiffré de couverture frontend. Les tests Node présents ne constituent pas des tests visuels complets dans un navigateur réel.

## Limites et améliorations

| Priorité | Limite confirmée | Amélioration |
|---|---|---|
| Haute | Pas de test end-to-end navigateur dans le pipeline. | Ajouter Playwright sur les parcours connexion, changement de compte, pointage et adhésion. |
| Moyenne | `orgService.js` contient encore un domaine de démonstration important. | Maintenir une séparation stricte et supprimer les mocks si la démonstration n'est plus requise. |
| Moyenne | Les données `ClockJSON` et `WorkingTimeJSON` utilisent un format UTC sans suffixe. | Uniformiser les réponses ISO 8601 côté backend. |
| Faible | Pas de mesure de couverture. | Produire et archiver un rapport de couverture. |
