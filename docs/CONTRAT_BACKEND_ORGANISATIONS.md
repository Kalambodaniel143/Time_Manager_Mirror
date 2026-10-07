# Contrat backend — organisations, adhésions, connexion et fusion de la maquette

Ce document décrit les appels du front dans `time-manager-dashboard/src/services/organizationService.js` et les demandes de correction ajoutées dans `src/services/correctionService.js`. La section 9 précise les changements liés à la fusion de la maquette du 7 octobre 2026. Aucun fichier du backend Phoenix n’a été modifié.

## 1. Parcours implémenté

- Créer une organisation et son compte administrateur, puis ouvrir automatiquement sa session.
- Demander à rejoindre une organisation existante après vérification de son nom.
- Pour créer une organisation : recueillir prénom, nom et email du créateur, sans genre ni date ou lieu de naissance.
- Pour rejoindre : recueillir prénom, nom, email, genre, date et lieu de naissance.
- Conserver la demande en attente : aucun compte actif et aucun mot de passe avant acceptation.
- Permettre uniquement à l’admin de l’organisation d’accepter/refuser ses demandes.
- À l’acceptation, créer un employé avec le mot de passe fourni par l’admin.
- Afficher une fois à l’admin l’email et le mot de passe qu’il vient de définir, pour transmission manuelle au demandeur. Le front ne prétend pas envoyer un email et n’effectue aucun envoi automatique.
- Permettre à l’admin de promouvoir un employé en manager ou de le repasser employé.
- Se connecter avec email/mot de passe ; le backend détermine le rôle et l’organisation.
- Consulter le statut d’une demande grâce à une référence privée.

La création d’une organisation est ouverte au public. Un compte appartient à une seule organisation dans cette version ; l’email est unique globalement. Le créateur reste admin et cette interface ne permet ni sa rétrogradation ni la création d’un autre admin.

## 2. Simulation et branchement réel

Par défaut, le nouveau circuit utilise une simulation persistante dans le navigateur, indépendante de `VITE_USE_MOCK` :

```env
VITE_AUTH_USE_MOCK=true
```

Après intégration du commit backend d’authentification, les deux circuits sont séparés : `authService.js` et `stores/auth.js` conservent la connexion backend existante, avec `/auth/me`, cookie HttpOnly et jeton CSRF. `organizationService.js` expose le contrat d’organisations proposé ci-dessous ; ces endpoints ne sont pas encore raccordés au parcours réel.

Pour utiliser la connexion backend existante (les écrans de création/adhésion d’organisations restent alors désactivés) :

```env
VITE_AUTH_USE_MOCK=false
VITE_USE_MOCK=false
VITE_API_URL=/api
```

Redémarrer Vite après un changement de variables ; reconstruire le bundle pour la production. Les variables `VITE_*` sont publiques, ne jamais y placer de secret.

En simulation, les données sont propres à ce navigateur et à cette origine. La simulation n’est pas un mécanisme de sécurité : son stockage peut être modifié par l’utilisateur. Les mots de passe sont stockés sous forme de dérivés PBKDF2 salés pour ne pas les conserver en clair, mais cela ne transforme pas le navigateur en serveur d’authentification.

Les utilisateurs simulés ne sont pas créés dans le backend. Depuis la fusion, `App.userId` contient leur identifiant local et les services de pointage/périodes/corrections dirigent explicitement leurs appels vers `mocks/organizationWork.js` tant que `auth.organizationSession` existe. Ces identifiants ne sont pas envoyés à l’API. Les données sont persistées sous `tm-work-demo:<organization_id>` ; planning, droits, notes, règles et validation locale sous `tm-org:<organization_id>`. La connexion backend conserve le transport API et `auth.user.id`. Les pages d’administration des utilisateurs et équipes backend sont accessibles en mode backend, tandis que les comptes simulés se gèrent dans Mon organisation.

Pour brancher ensuite les organisations, adapter les réponses `/auth/login` et `/auth/me` et l’état partagé pour inclure l’organisation, activer `LoginScreen` et la route `organization` en mode API, et utiliser le jeton CSRF du transport commun pour les mutations d’organisation. Les tests API du service décrivent le contrat cible ; ils ne prouvent pas sa disponibilité sur le serveur actuel.

Le rôle `admin` du scénario d’organisation est converti en `administrator` dans l’état partagé pour respecter les permissions du front distant. Harmoniser ces noms lors du raccordement backend.

## 3. Transport et enveloppes

Base : `VITE_API_URL`, par défaut `/api`.

Toutes les requêtes d’authentification/organisation utilisent `credentials: 'include'` et `Content-Type: application/json`. Les succès avec un corps doivent utiliser :

```json
{ "data": {} }
```

Une liste est directement dans `data`, sans pagination dans cette version :

```json
{ "data": [] }
```

Une erreur doit fournir :

```json
{
  "errors": {
    "detail": "Une organisation porte déjà ce nom.",
    "name": ["Ce nom est déjà utilisé."]
  }
}
```

`detail` est le message affichable. Les clés de champs permettent d’annoter les formulaires. Pour les champs personnels, utiliser les clés simples (`email`, `birth_date`, etc.), sans préfixe `profile.`.

Codes utilisés : `400` JSON/requête invalide, `401` session absente ou identifiants incorrects, `403` droits insuffisants, `404` ressource absente, `409` conflit/demande déjà traitée, `422` validation, `429` limitation, `5xx` indisponibilité.

## 4. Modèles

### Profil soumis pour rejoindre une organisation

```json
{
  "first_name": "Sara",
  "last_name": "Martin",
  "email": "sara@example.com",
  "gender": "female",
  "birth_date": "1999-03-12",
  "birth_place": "Paris"
}
```

Pour la création d’organisation, le profil contient uniquement `first_name`, `last_name` et `email`. Le serveur ne doit pas exiger `gender`, `birth_date` ou `birth_place` pour le créateur.

Validation serveur obligatoire, même si le front vérifie déjà :

| Champ | Règle |
|---|---|
| `first_name`, `last_name` | Texte obligatoire après suppression des espaces de bord, maximum 100 caractères |
| `birth_place` | Obligatoire uniquement pour rejoindre ; maximum 100 caractères après trim |
| `email` | Adresse valide, maximum 254 caractères ; normalisation trim/minuscules et unicité globale |
| `gender` | Obligatoire uniquement pour rejoindre : `female`, `male`, `non_binary`, `unspecified` ; la dernière valeur permet de ne pas préciser |
| `birth_date` | Obligatoire uniquement pour rejoindre : date civile `YYYY-MM-DD` valide, entre `1900-01-01` et aujourd’hui |
| Nom d’organisation | 2 à 100 caractères après trim ; espaces successifs réduits |
| Mot de passe | 8 à 128 caractères, pas uniquement des espaces ; ne pas modifier silencieusement la valeur |
| Motif de refus | 1 à 500 caractères après trim |

Le mot de passe n’apparaît jamais dans le profil. La confirmation est vérifiée par le front et n’est pas envoyée au serveur.

### Organisation

```json
{
  "id": "org-uuid",
  "name": "Atelier Gotham",
  "created_at": "2026-10-05T12:00:00Z"
}
```

L’identifiant d’organisation doit être une chaîne stable compatible avec un segment d’URL, idéalement un UUID.

### Utilisateur public

```json
{
  "id": 14,
  "username": "sara@example.com",
  "first_name": "Sara",
  "last_name": "Martin",
  "email": "sara@example.com",
  "gender": "female",
  "birth_date": "1999-03-12",
  "birth_place": "Paris",
  "organization_id": "org-uuid",
  "role": "employee",
  "created_at": "2026-10-05T12:30:00Z"
}
```

Pour le créateur admin, les champs `gender`, `birth_date` et `birth_place` peuvent être absents ou `null` dans les réponses utilisateur/session.

`id` est un entier correspondant à l’utilisateur métier utilisé par les endpoints existants `/clocks/:userID` et `/workingtime/:userID`. `username` est stable, obligatoire pour l’intégration avec les composants existants ; la simulation utilise l’email initial. Ne jamais renvoyer mot de passe, hash ou sel.

### Session

```json
{
  "data": {
    "role": "employee",
    "user": { "id": 14, "username": "sara@example.com", "first_name": "Sara", "last_name": "Martin", "email": "sara@example.com", "organization_id": "org-uuid", "role": "employee", "gender": "female", "birth_date": "1999-03-12", "birth_place": "Paris", "created_at": "2026-10-05T12:30:00Z" },
    "organization": { "id": "org-uuid", "name": "Atelier Gotham", "created_at": "2026-10-05T12:00:00Z" }
  }
}
```

`role` doit être égal à `user.role` ; `user.organization_id` doit être égal à `organization.id`. Le front vérifie ces relations avant d’accepter une session.

### Demande visible par l’admin

```json
{
  "id": "request-uuid",
  "organization_id": "org-uuid",
  "organization_name": "Atelier Gotham",
  "profile": {
    "first_name": "Sara", "last_name": "Martin", "email": "sara@example.com",
    "gender": "female", "birth_date": "1999-03-12", "birth_place": "Paris"
  },
  "status": "pending",
  "created_at": "2026-10-05T12:15:00Z",
  "reviewed_at": null,
  "reviewed_by": null,
  "rejection_reason": null
}
```

États : `pending`, `approved`, `rejected`. Les dates d’événements sont des timestamps ISO 8601 en UTC. La référence privée de suivi ne doit pas figurer dans la liste admin.

## 5. Endpoints exacts

| Méthode | Chemin relatif à `/api` | Accès | Succès |
|---|---|---|---|
| POST | `/organizations` | Public | 201 + session + cookie |
| GET | `/organizations/lookup?name=…` | Public | 200 + `{ id, name }` |
| POST | `/join-requests` | Public | 201 + reçu de suivi |
| POST | `/join-requests/status` | Public, référence privée | 200 + statut |
| POST | `/auth/login` | Public | 200 + session + cookie |
| GET | `/auth/session` | Connecté | 200 + session actualisée |
| POST | `/auth/logout` | Connecté | 204 + invalidation du cookie |
| GET | `/organizations/:orgId/join-requests` | Admin de cette organisation | 200 + liste des demandes |
| POST | `/organizations/:orgId/join-requests/:id/approve` | Admin de cette organisation | 200 + `{ request, user }` |
| POST | `/organizations/:orgId/join-requests/:id/reject` | Admin de cette organisation | 200 + demande traitée |
| GET | `/organizations/:orgId/members` | Admin de cette organisation | 200 + liste des utilisateurs publics |
| PATCH | `/organizations/:orgId/members/:id` | Admin de cette organisation | 200 + utilisateur public actualisé |

### Créer une organisation

Corps :

```json
{
  "name": "Atelier Gotham",
  "profile": { "first_name": "Nando", "last_name": "Martin", "email": "admin@example.com" },
  "password": "MotDePasseChoisiParAdmin!"
}
```

Créer atomiquement l’organisation, son utilisateur admin et sa session. Le client ne fournit aucun rôle. Une organisation au nom équivalent ou un email déjà utilisé produit `409`. La comparaison des noms dans la simulation ignore casse, accents et espaces successifs ; le backend doit fournir la même recherche et la même unicité pour éviter les ambiguïtés.

### Vérifier l’organisation

Chercher le nom exact normalisé, pas une recherche approximative. Retourner seulement `{ id, name }`, sans liste des membres ni coordonnées de l’admin. Un nom absent produit `404` avec un message expliquant qu’il faut vérifier le nom.

### Envoyer une demande

```json
{
  "organization_id": "org-uuid",
  "profile": { "first_name": "Sara", "last_name": "Martin", "email": "sara@example.com", "gender": "female", "birth_date": "1999-03-12", "birth_place": "Paris" }
}
```

Réponse :

```json
{
  "data": {
    "id": "request-uuid",
    "reference": "reference-aleatoire-privee",
    "organization_name": "Atelier Gotham",
    "status": "pending"
  }
}
```

Ne pas créer de compte actif ni ouvrir de session. Vérifier à nouveau l’existence de l’organisation. Refuser avec `409` un email déjà inscrit ou une demande `pending` identique (même organisation/email). Une demande refusée permet une nouvelle soumission, sans modifier l’historique précédent.

### Suivre une demande

```json
{ "reference": "reference-aleatoire-privee" }
```

Réponse :

```json
{
  "data": {
    "id": "request-uuid",
    "reference": "reference-aleatoire-privee",
    "organization_name": "Atelier Gotham",
    "status": "rejected",
    "rejection_reason": "Cette demande concerne une autre organisation."
  }
}
```

Le reçu initial n’a pas besoin de `rejection_reason`. Le statut actualisé renvoie `null` pour ce champ en dehors d’un refus. Ne pas exposer le profil, l’email ou un mot de passe via cet endpoint. La référence est aléatoire, non devinable, et transmise dans le corps plutôt que dans l’URL. `404` si elle est inconnue.

### Connexion et session

```json
{ "email": "sara@example.com", "password": "MotDePasseFourniParAdmin!" }
```

Le serveur vérifie les identifiants puis répond avec le modèle Session. Refus `401` générique si les identifiants sont incorrects ou si aucun compte accepté n’existe. Aucun rôle n’est accepté depuis ce corps.

`GET /auth/session` renvoie le rôle courant depuis la base, notamment après promotion. Le front appelle cet endpoint au démarrage et lorsque la fenêtre reprend le focus. Une session absente/expirée produit `401`, pas `{ data: null }`.

`POST /auth/logout` n’a pas de corps ; il invalide la session côté serveur. Si elle est déjà absente, le front accepte également `401` et efface son cache d’affichage.

### Accepter une demande

```json
{ "password": "MotDePasseFourniParAdmin!" }
```

Réponse :

```json
{ "data": { "request": "objet Demande avec status approved", "user": "objet Utilisateur public avec role employee" } }
```

Les chaînes ci-dessus désignent les objets complets définis en section 4, pas des chaînes à renvoyer réellement.

L’acceptation est atomique : vérifier `pending`, créer l’utilisateur employé et son hash de mot de passe, enregistrer le traitement. En cas de validation ou de conflit, laisser la demande en attente et ne créer aucun utilisateur partiel. Un second traitement produit `409`. Une concurrence doit produire un seul compte.

Le mot de passe est choisi par l’admin, pas généré par le backend. Le front conserve temporairement la valeur qu’il vient de soumettre pour permettre sa copie ; le serveur ne doit pas la renvoyer dans la réponse. La transmission est manuelle dans cette version. Ajouter ultérieurement un envoi automatique nécessiterait un contrat de notification supplémentaire et une modification explicite de l’interface.

### Refuser une demande

```json
{ "reason": "Cette demande concerne une autre organisation." }
```

Passer une demande `pending` à `rejected`, enregistrer l’admin et la date, ne créer aucun compte. Réponse : objet Demande complet dans `data`. Second traitement : `409`.

### Modifier un rôle

```json
{ "role": "manager" }
```

Seules les valeurs `employee` et `manager` sont autorisées. Le membre doit appartenir à cette organisation et ne pas être admin. Le serveur vérifie le rôle de l’auteur ; un employé/manager ne peut pas se promouvoir. Ne pas changer l’email ni le mot de passe. Les sessions actives doivent refléter le nouveau rôle à leur prochaine lecture, et les permissions serveur doivent être actualisées immédiatement.

## 6. Session et permissions serveur

Le front ne reçoit pas de bearer token. Utiliser un cookie de session `HttpOnly`, `Secure` en production, et `SameSite` adapté à un déploiement de même origine. Le proxy Vite/nginx existant expose l’API sous `/api`.

Le front conserve l’utilisateur dans `stores/auth.js` et le jeton CSRF dans `sessionStorage` (`tm-csrf`). L’identité est restaurée par `/auth/me` en mode backend. La simulation restaure séparément sa session locale. Aucun état navigateur ne constitue une preuve d’identité pour le serveur.

Le transport backend existant envoie `X-CSRF-Token`. Le service d’organisations cible utilise encore son transport isolé pour les tests de contrat ; avant raccordement, le migrer vers le transport commun et conserver la protection CSRF du backend. Valider aussi Origin/Referer, les cookies SameSite et la configuration CORS.

Ne jamais faire confiance aux identifiants d’organisation ou d’utilisateur de l’URL. Tous les endpoints admin vérifient l’appartenance et le rôle. Les endpoints métier existants doivent également appliquer les permissions de la session : les gardes Vue Router ne sécurisent pas l’API.

Ne pas conserver les mots de passe en clair ni dans les logs. Utiliser un hash adapté côté serveur, une limitation des tentatives de connexion/demandes/recherche, et des transactions/contraintes d’unicité. Les détails personnels ne sont visibles que par le demandeur connecté et l’admin autorisé ; le suivi public n’expose que le statut et le motif du refus.

## 7. Recette front sans backend

Depuis `time-manager-dashboard` :

```bash
npm run dev
```

1. « Créer une organisation » : saisir prénom, nom, email, nom d’organisation et mot de passe admin (aucune donnée de naissance ni de genre). La création ouvre « Mon organisation ».
2. Se déconnecter ; choisir « Rejoindre ». Vérifier un nom inconnu : l’interface signale l’erreur.
3. Utiliser le nom créé, saisir un autre email et envoyer la demande. Conserver la référence de suivi.
4. Se reconnecter avec l’email admin et son mot de passe.
5. Dans « Mon organisation », accepter la demande en définissant et confirmant le mot de passe employé. Copier les identifiants avant de fermer ; aucune notification externe n’est envoyée.
6. Se déconnecter ; consulter le statut avec la référence ; se connecter avec les identifiants de l’employé.
7. Se reconnecter admin ; promouvoir le membre manager. À sa prochaine connexion, le membre accède à la navigation manager.
8. Tester aussi un refus motivé, les doublons, un mot de passe incorrect et les rechargements de page.

La simulation ne fonctionne pas entre deux navigateurs ou deux origines différentes. Utiliser des connexions successives dans le même navigateur. En mode réel, le serveur permettra les sessions et demandes depuis plusieurs postes.

## 8. Fichiers et vérification

- `src/views/LoginScreen.vue` : connexion, création, adhésion, suivi.
- `src/views/OrganizationAdmin.vue` : demandes, décisions, identifiants à transmettre, membres et rôles.
- `src/components/auth/ProfileFields.vue` : champs personnels partagés.
- `src/components/auth/AccountIdentity.vue` : identité de la session dans la barre latérale.
- `src/services/organizationService.js` : frontière API/simulation.
- `src/mocks/organizationAuth.js` : simulation persistante.
- `src/utils/registration.js` : validation des formulaires.
- `App.vue`, routeur, barre latérale et utilitaire session : branchement du nouveau circuit.

Commandes de vérification :

```bash
npm run test:auth
npm run test:clocks
npm run test:fusion
npm run build
```


## 9. Compléments après fusion de la maquette — 7 octobre 2026

### 9.1 Ce que le front réalise désormais

- Charte verte, navigation desktop et barre inférieure mobile par rôle ; les fonctions d’organisation restent disponibles.
- Mon compte rassemble identité, affichage Clair/Nuit/Contraste, textes renforcés, confidentialité, aide et déconnexion. En mode backend, les formulaires d’identité et changement de mot de passe existants sont conservés. En mode organisation simulée, ils ne tentent pas de modifier un faux utilisateur dans l’API.
- Pointages, pauses/reprises et périodes persistants dans la simulation d’organisation. Une pause est exclue des durées. Les données ne sont pas partagées entre organisations.
- L’employé propose une correction sur une période existante ; ses heures ne changent qu’après acceptation par un autre responsable autorisé. Un refus nécessite un motif. La proposition, les horaires originaux et la décision sont affichés.
- Les heures existent en tableau desktop et cartes mobile avec durée séparée. Les propositions ne sont pas additionnées aux heures confirmées.
- Les vrais membres d’équipe sont lus depuis `/teams` en mode backend pour Mon équipe. Dans la simulation, les membres visibles de l’organisation constituent un groupe de démonstration ; cette simplification ne remplace pas les permissions par équipe du serveur.
- Le planning employé a deux semaines distinctes ; le planning responsable permet une sélection d’agent sur mobile. Les plannings restent des exemples.
- Demandes d’échange enregistrées localement et examinables dans la démonstration. Les accepter signifie organiser l’échange ; cela n’effectue pas automatiquement une permutation réelle de gardes.
- Résumés de l’équipe, accès aux fiches, validation groupée locale, règles enregistrées explicitement et droits accompagnés de leurs états lisibles.
- Aucun badge, aucune géolocalisation, aucune collecte d’activité, aucun email automatique et aucun envoi à un logiciel de paie ne sont introduits. L’export est un téléchargement CSV d’exemple.

### 9.2 Nouvelles routes réellement appelées pour les corrections

Ces trois routes sont proposées au backend et **ne sont pas présentes dans son routeur actuel**. `correctionService.js` utilise le transport HTTP commun : cookie, `credentials: same-origin`, `X-CSRF-Token`, enveloppe `data` et gestion habituelle des erreurs. Les comptes d’organisation simulés utilisent à la place le stockage local. Un serveur répondant 404 produit une information d’indisponibilité ; aucune réussite n’est inventée.

| Méthode | Route sous `/api` | Rôle |
|---|---|---|
| GET | `/correction-requests?user_id=14` | Suivi des demandes du salarié ; sans filtre, demandes du périmètre du responsable connecté. |
| POST | `/workingtime/:id/correction-requests` | Proposition de modification de ses propres horaires. |
| PATCH | `/correction-requests/:id` | Décision d’un autre manager autorisé ou d’un administrateur de l’organisation. |

POST, corps exact envoyé par le front :

```json
{
  "correction": {
    "start": "2026-10-06 06:00:00",
    "end": "2026-10-06 13:00:00",
    "reason": "Départ réel plus tôt après la fin de l’intervention"
  }
}
```

Les dates envoyées sont en UTC, suivant la convention actuelle des pointages (`YYYY-MM-DD HH:mm:ss`). Le formulaire affiche/saisit l’heure locale et la convertit. Le backend accepte et restitue une représentation UTC cohérente. `reason` contient entre 1 et 500 caractères après trim. Les horaires doivent être valides, de durée positive et sans date future. Les identifiants d’auteur, de salarié et d’organisation sont déterminés côté serveur à partir de la session et de la période, jamais depuis le corps client.

Réponse POST/PATCH : un objet dans `data`. Réponse GET : une liste dans `data`. Forme attendue :

```json
{
  "data": {
    "id": 7,
    "period_id": 23,
    "user_id": 14,
    "username": "sara@example.com",
    "before": { "start": "2026-10-06 06:00:00", "end": "2026-10-06 14:00:00" },
    "proposal": { "start": "2026-10-06 06:00:00", "end": "2026-10-06 13:00:00" },
    "reason": "Départ réel plus tôt après la fin de l’intervention",
    "status": "pending",
    "created_at": "2026-10-07T09:00:00Z",
    "reviewed_at": null,
    "reviewed_by": null,
    "review_reason": ""
  }
}
```

`reviewed_by` est le nom affichable du décideur (le serveur conserve également son identifiant). `before` est l’instantané lu par le serveur lors de la création. Il doit être conservé après acceptation, afin que le suivi affiche la différence.

PATCH, corps exact :

```json
{ "status": "approved", "reason": "Horaires vérifiés avec l’agent" }
```

Ou :

```json
{ "status": "rejected", "reason": "Précisez la date de votre départ" }
```

Seuls `approved` et `rejected` sont acceptés pour une décision. Le commentaire est facultatif à l’acceptation, obligatoire au refus.

### 9.3 Règles serveur nécessaires pour ces demandes

1. Un utilisateur peut proposer uniquement une correction de ses propres périodes. Une proposition ne modifie ni les périodes ni les totaux.
2. Un employé voit uniquement ses demandes ; un manager les demandes des membres de ses équipes ; un admin uniquement celles de son organisation. Le filtre `user_id` ne permet jamais d’élargir ce périmètre.
3. Personne n’accepte sa propre correction. Les permissions actuelles de modification des heures restent pertinentes pour les corrections directes du manager ; le front n’affiche pas cette édition directe pour ses propres heures.
4. Une seule demande `pending` par période : doublon = 409. Une demande traitée ne peut pas être rejouée : 409.
5. Si la période a été modifiée ou supprimée depuis la proposition, l’acceptation échoue avec 409 et un message explicite. Vérifier instantané/version et décision dans une transaction.
6. L’acceptation modifie la période et conserve auteur, date, ancienne/nouvelle valeurs et motif. Le refus conserve les heures d’origine et son explication.
7. Les demandes plus anciennes que sept jours restent soumises à une décision manuelle. Elles ne bénéficient pas d’une correction personnelle directe.
8. Une feuille validée/clôturée ne peut pas être modifiée silencieusement : prévoir une régularisation et une nouvelle validation après acceptation selon le périmètre de clôture retenu.
9. Compléter un départ oublié est une opération distincte : garder l’endpoint existant `/clocks/:userID/:clockID/complete`, ses protections contre les formulaires périmés et sa fenêtre de sept jours. Quand les feuilles serveur existeront, vérifier aussi leur clôture.
10. Le front empêche les dates futures et affiche les erreurs ; le backend répète les validations. Les tests de simulation ne constituent pas une preuve de sécurité serveur.

La simulation couvre propositions/décisions/isolement, mais ne possède pas un vrai mécanisme serveur de clôture ou de validation des feuilles. Les points 8 et 9 concernant une feuille clôturée restent à réaliser côté backend, puis à refléter dans les données de capacité retournées au front.

### 9.4 Fonctions encore locales et raccordement à prévoir

Ces fonctionnalités n’introduisent pas aujourd’hui de nouveaux appels HTTP dans le front ; leurs futures API devront être définies et raccordées :

| Fonction | Comportement actuel | Besoin serveur |
|---|---|---|
| Planning/publication | Exemple modifiable localement ; aucun agent notifié. | Gardes réelles, brouillon/version publiée, dates de publication et notifications. |
| Demande d’échange | Enregistrement local dans `org.swapRequests`, statut pending/accepted/rejected ; accepted ne permute pas automatiquement les gardes. | Gardes identifiées, demande persistante, décision et échange transactionnel, contrôles de contraintes. |
| Notes | Stockage local et avertissement sur l’absence de partage réel. | Note liée au salarié, à la semaine et au manager autorisé, visibilité identique pour les deux. |
| Validation | État local par utilisateur/semaine ; accès groupé. | Feuille hebdomadaire persistante, validateur/date, anomalies bloquantes, clôture et nouvelle validation après correction. |
| Droits/règles/journal | Démonstration locale ; pas de notification annoncée comme envoyée. | Droits validate/correct/publish par équipe, règles par organisation et journal métier persistant. |
| Paie | Relevé d’exemple et CSV téléchargé. | Totaux par mois/service depuis heures réellement confirmées ; catégories, majorations et politique d’arrondi explicites. |

Les dépassements de nuits ne suppriment pas les heures travaillées. La sélection automatique les signale et ne les coche pas ; le responsable peut les examiner puis les sélectionner explicitement. Un départ manquant ou des pointages non vérifiés restent bloquants dans le front. Le serveur devra appliquer une politique cohérente et empêcher l’auto-validation.

Les règles locales contiennent désormais :

```json
{
  "maxConsecutiveNights": 2,
  "maxNightsPerWeek": 0,
  "maxNightsPerMonth": 0,
  "overtimeThreshold": 40,
  "publishDaysAhead": 14
}
```

Les seuils de fréquence `0` signifient désactivés ; aucun quota n’est imposé sans décision de l’organisation. Les valeurs sont des entiers, minimum 1 pour nuits consécutives/heures supplémentaires/publication, minimum 0 pour fréquences semaine/mois. Le front déduplique les périodes classées nuit par date de début ; les services coupés par une pause et traversant minuit doivent être rattachés à leur garde par le serveur ; la règle finale de rattachement au jour de service et le fuseau doivent être établis côté serveur. Mon équipe utilise les périodes du mois lorsque le seuil mensuel est activé. Pour le planning de démonstration, les contrôles mensuels portent uniquement sur les quatorze jours affichés : le serveur devra vérifier le mois complet et les frontières entre périodes.

Le repère hebdomadaire du résumé est maintenant explicitement le seuil d’heures supplémentaires, et n’est plus présenté comme un nombre d’heures prévues. Un futur contrat de planning fournira les heures prévues/contractuelles séparément.

Les rappels sont à déclencher après le départ attendu avec un délai adapté à la garde, sans relances répétitives. Ne pas envoyer aveuglément un message à 9 h le lendemain lorsqu’un service de nuit est encore en cours. Aucun automatisme n’a été ajouté au backend par cette fusion.

### 9.5 Préférences et recette complémentaire

Le thème (`tm-theme`) et le renforcement des textes (`tm-strong-text`) sont stockés localement. Aucune nouvelle route n’est nécessaire pour ces préférences. Une synchronisation entre appareils serait une évolution facultative du profil.

Recette dans un même navigateur :

1. Créer une organisation, faire accepter un employé et se connecter avec son email/mot de passe.
2. Pointer une arrivée, une pause, une reprise, un départ ; recharger et vérifier la persistance. Les pauses ne sont pas comptées.
3. Depuis Mes heures, proposer une correction motivée. Vérifier que les totaux restent inchangés tant qu’elle est pending.
4. Se reconnecter admin ou manager autorisé, accepter/refuser et vérifier le suivi et les heures mises à jour.
5. Tester le refus motivé, le doublon pending, l’auto-acceptation interdite et une période modifiée après proposition.
6. Essayer une autre organisation : aucune période ou demande de la première n’est visible.
7. Sur mobile, naviguer par la barre inférieure, changer de semaine, choisir un agent dans le planning responsable et ouvrir Mon compte.
8. Choisir Nuit/Contraste, activer les textes renforcés et recharger.
9. Vérifier que notes/planning/validation/CSV restent identifiés comme locaux ou d’exemple, sans promesse d’envoi.

Fichiers ajoutés : `mocks/organizationWork.js`, `services/correctionService.js`, `components/reviews/CorrectionRequest.vue`, `components/reviews/CorrectionPanel.vue`, `components/ui/ModalDialog.vue`, `test/fusion-workflow.test.js`.

La limite maximale de mot de passe du contrat organisations reste 128 caractères ; le modèle User du backend existant limite aujourd’hui à 72. Le raccordement doit harmoniser cette limite et le hachage, sans réduire le minimum de 8 caractères retenu.

Point existant à corriger côté backend avant recette réelle : `AuthController.login` utilise `:unatuhorized` au lieu de `:unauthorized` en cas d’identifiants incorrects. Le backend est resté inchangé pendant cette intervention front.
