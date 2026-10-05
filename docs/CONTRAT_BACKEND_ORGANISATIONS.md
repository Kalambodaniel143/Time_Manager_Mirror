# Contrat backend — organisations, adhésions et connexion

Ce document décrit les appels réellement ajoutés au front dans `time-manager-dashboard/src/services/organizationService.js`. Aucun fichier du backend Phoenix n’a été modifié.

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
VITE_API_URL=/api
```

Redémarrer Vite après un changement de variables ; reconstruire le bundle pour la production. Les variables `VITE_*` sont publiques, ne jamais y placer de secret.

En simulation, les données sont propres à ce navigateur et à cette origine. La simulation n’est pas un mécanisme de sécurité : son stockage peut être modifié par l’utilisateur. Les mots de passe sont stockés sous forme de dérivés PBKDF2 salés pour ne pas les conserver en clair, mais cela ne transforme pas le navigateur en serveur d’authentification.

Les nouveaux utilisateurs simulés ne sont pas créés dans l’ancien backend. Leur identifiant métier `App.userId` reste donc `null` : aucun chargement automatique des heures avec un faux identifiant. Les anciens écrans de planning, paie, équipes et droits conservent leurs sources existantes ; leur migration en données multi-organisations est un travail backend/métier distinct. La connexion backend existante utilise `auth.user.id` pour les routes de pointage et de périodes existantes.

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
npm run build
```
