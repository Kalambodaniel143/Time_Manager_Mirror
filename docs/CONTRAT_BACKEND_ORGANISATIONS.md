# Contrat backend — Gotham City, adhésions et super administrateur

Ce document décrit les appels du front dans `time-manager-dashboard/src/services/organizationService.js` et les demandes de correction ajoutées dans `src/services/correctionService.js`. La section 9 précise les changements liés à la fusion de la maquette du 7 octobre 2026. La section 11 décrit l’ajout du 9 octobre 2026 : suppression personnelle du compte, avec adaptation ciblée du contrôleur et des permissions backend.

## 1. Parcours actuel — organisation unique (8 octobre 2026)

- L’organisation unique est **Gotham City**, initialisée manuellement avec son super administrateur. Aucun compte privilégié et aucun mot de passe par défaut n’est créé au démarrage.
- La page publique de création d’organisation est supprimée. L’inscription directe d’un compte actif n’est plus accessible dans le front.
- `/inscription` ouvre « Rejoindre Gotham City ». Le demandeur fournit prénom, nom, email, genre, date et lieu de naissance ; il ne choisit ni nom/identifiant d’organisation, ni rôle, ni mot de passe.
- Le front résout en interne Gotham City, puis envoie une demande pending à l’API existante. Une organisation non initialisée produit une erreur explicite, sans création automatique.
- Le super administrateur accepte/refuse et fournit le mot de passe à l’acceptation. Le nouvel utilisateur est employé par défaut et pourra être promu manager.
- Le demandeur suit sa demande par référence privée puis se connecte avec son email et le mot de passe fourni.
- Les managers ne créent pas de super administrateur et ne décident pas des demandes d’adhésion. La promotion ne propose que employee/manager.

Le code de rôle backend reste `administrator`. « Super administrateur » est son libellé métier dans l’organisation unique ; aucun rôle supplémentaire `super_admin` n’est envoyé par le front. L’alias `admin` est normalisé par le service pour les écrans d’administration existants.

**État serveur à distinguer :** les endpoints d’organisations/adhésions existent désormais dans le backend récupéré depuis main. Son routeur expose encore la création publique `POST /api/organizations` et l’inscription directe `POST /api/auth/register`. Leur suppression/refus côté serveur est nécessaire pour imposer réellement la nouvelle politique (voir section 10). L’adaptation mono-organisation du 8 octobre concernait le front et le contrat ; les seules modifications serveur ultérieures sont celles de la suppression personnelle (section 11). Aucune base de données utilisateur n’a été modifiée lors de ce développement.

## 2. Simulation et branchement réel

Par défaut, le nouveau circuit utilise une simulation persistante dans le navigateur, indépendante de `VITE_USE_MOCK` :

```env
VITE_AUTH_USE_MOCK=true
```

Le même écran LoginScreen sert désormais en mode simulation et API. `organizationService.js` utilise le transport HTTP partagé en mode réel, avec cookie HttpOnly et jeton CSRF. `stores/auth.js` restaure la session complète via `/auth/session`, et distingue le contexte réel `auth.organization` du contexte de démonstration `auth.organizationSession` pour ne jamais router les données réelles vers les mocks.

Pour utiliser la connexion, l’adhésion et les décisions sur le backend existant :

```env
VITE_AUTH_USE_MOCK=false
VITE_USE_MOCK=false
VITE_API_URL=/api
```

Redémarrer Vite après un changement de variables ; reconstruire le bundle pour la production. Les variables `VITE_*` sont publiques, ne jamais y placer de secret.

En simulation, les données sont propres à ce navigateur et à cette origine. La simulation n’est pas un mécanisme de sécurité : son stockage peut être modifié par l’utilisateur. Les mots de passe sont stockés sous forme de dérivés PBKDF2 salés pour ne pas les conserver en clair, mais cela ne transforme pas le navigateur en serveur d’authentification.

Les utilisateurs simulés ne sont pas créés dans le backend. Depuis la fusion, `App.userId` contient leur identifiant local et les services de pointage/périodes/corrections dirigent explicitement leurs appels vers `mocks/organizationWork.js` tant que `auth.organizationSession` existe. Ces identifiants ne sont pas envoyés à l’API. Les données sont persistées sous `tm-work-demo:<organization_id>` ; planning, droits, notes, règles et validation locale sous `tm-org:<organization_id>`. La connexion backend conserve le transport API et `auth.user.id`. Les pages d’administration des utilisateurs et équipes backend sont accessibles en mode backend, tandis que les comptes simulés se gèrent dans Administration Gotham.

Le transport commun transmet `X-CSRF-Token` aux routes protégées. Le token reçu à la connexion est conservé lors de la restauration `/auth/session`, dont la réponse n’a pas besoin de le répéter. Les réponses canonical backend `administrator` sont normalisées en alias admin pour l’écran métier, puis en administrator dans l’état partagé. Les sessions d’une autre ville ou sans organisation sont refusées par ce front ; cette validation ne remplace pas le contrôle serveur de périmètre.

## 3. Transport et enveloppes

Base : `VITE_API_URL`, par défaut `/api`.

Toutes les requêtes d’authentification/organisation utilisent `credentials: 'same-origin'` et `Content-Type: application/json`. Les succès avec un corps doivent utiliser :

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
| Organisation | Valeur fixe Gotham City, provisionnée manuellement ; aucun nom libre fourni par le formulaire |
| Mot de passe | 8 à 128 caractères, pas uniquement des espaces ; ne pas modifier silencieusement la valeur |
| Motif de refus | 1 à 500 caractères après trim |

Le mot de passe n’apparaît jamais dans le profil. La confirmation est vérifiée par le front et n’est pas envoyée au serveur.

### Organisation

```json
{
  "id": "org-uuid",
  "name": "Gotham City",
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

Pour le super administrateur provisionné manuellement, les champs `gender`, `birth_date` et `birth_place` peuvent être absents ou `null` dans les réponses utilisateur/session.

`id` est un entier correspondant à l’utilisateur métier utilisé par les endpoints existants `/clocks/:userID` et `/workingtime/:userID`. `username` est stable, obligatoire pour l’intégration avec les composants existants ; la simulation utilise l’email initial. Ne jamais renvoyer mot de passe, hash ou sel.

### Session

```json
{
  "data": {
    "role": "employee",
    "user": { "id": 14, "username": "sara@example.com", "first_name": "Sara", "last_name": "Martin", "email": "sara@example.com", "organization_id": "org-uuid", "role": "employee", "gender": "female", "birth_date": "1999-03-12", "birth_place": "Paris", "created_at": "2026-10-05T12:30:00Z" },
    "organization": { "id": "org-uuid", "name": "Gotham City", "created_at": "2026-10-05T12:00:00Z" }
  }
}
```

`role` doit être égal à `user.role` ; `user.organization_id` doit être égal à `organization.id`. Le front vérifie ces relations avant d’accepter une session.

### Demande visible par l’admin

```json
{
  "id": "request-uuid",
  "organization_id": "org-uuid",
  "organization_name": "Gotham City",
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
| — | `/organizations` | Création publique retirée du front ; endpoint serveur à désactiver | Initialisation manuelle uniquement |
| GET | `/organizations/lookup?name=Gotham%20City` | Public | 200 + `{ id, name }` |
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

### Initialiser Gotham City

Cette opération est manuelle et n’est plus proposée dans le front. Utiliser le contexte serveur `TimeManager.Organizations` depuis un terminal autorisé ; ne pas créer une nouvelle API publique de bootstrap. Voir section 10 pour la procédure.

### Résoudre Gotham City en interne

Le seul nom recherché par le front est `Gotham City`, via `GET /organizations/lookup?name=Gotham%20City`. Retourner `{ id, name }` ; cette requête n’est pas exposée comme champ ou bouton dans l’interface. L’identifiant UUID retourné est transmis ensuite à l’API existante de demande d’adhésion.

Le service `joinOrganization({ profile })` ignore tout organization_id éventuellement fourni par un appelant et utilise celui résolu pour Gotham. Le backend doit également refuser un identifiant différent de l’organisation unique, ou résoudre lui-même l’organisation fixe. Ce dernier changement de payload éventuel devra être synchronisé avec le service.

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
    "organization_name": "Gotham City",
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
    "organization_name": "Gotham City",
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

Le front conserve l’utilisateur dans `stores/auth.js` et le jeton CSRF dans `sessionStorage` (`tm-csrf`). L’identité et l’organisation sont restaurées par `/auth/session` en mode backend. La simulation restaure séparément sa session locale. Aucun état navigateur ne constitue une preuve d’identité pour le serveur.

Le service d’organisations utilise maintenant le transport commun avec `X-CSRF-Token`. Les décisions, membres, rôles, session et déconnexion conservent la protection CSRF du backend. Valider aussi Origin/Referer, les cookies SameSite et la configuration CORS.

Ne jamais faire confiance aux identifiants d’organisation ou d’utilisateur de l’URL. Tous les endpoints admin vérifient l’appartenance et le rôle. Les endpoints métier existants doivent également appliquer les permissions de la session : les gardes Vue Router ne sécurisent pas l’API.

Ne pas conserver les mots de passe en clair ni dans les logs. Utiliser un hash adapté côté serveur, une limitation des tentatives de connexion/demandes/recherche, et des transactions/contraintes d’unicité. Les détails personnels ne sont visibles que par le demandeur connecté et l’admin autorisé ; le suivi public n’expose que le statut et le motif du refus.

## 7. Recette front sans backend

Depuis `time-manager-dashboard` :

```bash
npm run dev
```

1. Initialiser manuellement le super administrateur de démonstration suivant la section 10.
2. Ouvrir `/inscription` : aucun bouton de création ni champ de nom d’organisation. Prénom, nom, email, genre, date et lieu de naissance restent présents.
3. Envoyer une demande avec un autre email ; conserver la référence. Aucun compte actif ni session n’est créé.
4. Se connecter avec les identifiants manuels du super administrateur et ouvrir Administration Gotham.
5. Accepter en définissant un mot de passe de 8 caractères minimum ; copier les identifiants avant fermeture.
6. Suivre le statut puis se connecter comme employé.
7. Promouvoir ensuite le membre manager ; vérifier ses accès après rechargement/connexion.
8. Tester un refus motivé, les doublons, les erreurs de connexion et une Gotham non initialisée.

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

Cette section décrit les fonctionnalités de la fusion ; les références au parcours multi-organisations sont remplacées par la politique mono-organisation des sections 1, 2 et 10.

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

1. Initialiser manuellement Gotham et son super administrateur (section 10), faire accepter un employé et se connecter avec son email/mot de passe.
2. Pointer une arrivée, une pause, une reprise, un départ ; recharger et vérifier la persistance. Les pauses ne sont pas comptées.
3. Depuis Mes heures, proposer une correction motivée. Vérifier que les totaux restent inchangés tant qu’elle est pending.
4. Se reconnecter admin ou manager autorisé, accepter/refuser et vérifier le suivi et les heures mises à jour.
5. Tester le refus motivé, le doublon pending, l’auto-acceptation interdite et une période modifiée après proposition.
6. Essayer une autre organisation : aucune période ou demande de la première n’est visible.
7. Sur mobile, naviguer par la barre inférieure, changer de semaine, choisir un agent dans le planning responsable et ouvrir Mon compte.
8. Choisir Nuit/Contraste, activer les textes renforcés et recharger.
9. Vérifier que notes/planning/validation/CSV restent identifiés comme locaux ou d’exemple, sans promesse d’envoi.

Fichiers ajoutés : `mocks/organizationWork.js`, `services/correctionService.js`, `components/reviews/CorrectionRequest.vue`, `components/reviews/CorrectionPanel.vue`, `components/ui/ModalDialog.vue`, `test/fusion-workflow.test.js`.

Le backend récupéré depuis main utilise désormais Argon2id et la même limite 8–128 caractères que le circuit d’adhésion.

Le statut d’erreur de connexion est désormais correctement `:unauthorized` dans le backend récupéré depuis main.


## 10. Provisionnement manuel et verrouillage de Gotham City

### 10.1 Backend réel : création initiale depuis un terminal autorisé

Aucune initialisation n’a été exécutée automatiquement par le front. Le super administrateur doit appartenir à Gotham City et posséder prénom, nom, email et le rôle technique administrator. Un ancien compte de seed sans organization_id ne suffit pas pour examiner les demandes.

Pour une installation neuve, fournir les identifiants depuis le terminal, puis démarrer IEx dans time_manager :

```bash
read -r -p "Email du super administrateur : " ADMIN_EMAIL
read -r -s -p "Mot de passe : " ADMIN_PASSWORD
export ADMIN_EMAIL ADMIN_PASSWORD
iex -S mix
```

Depuis IEx, après migrations et insertion des rôles de référence :

```elixir
TimeManager.Organizations.create_organization(
  "Gotham City",
  %{
    "first_name" => "Prénom à renseigner",
    "last_name" => "Nom à renseigner",
    "email" => System.fetch_env!("ADMIN_EMAIL")
  },
  System.fetch_env!("ADMIN_PASSWORD")
)
```

Cette fonction existante crée atomiquement Gotham et son administrator, sans ouvrir de session HTTP. Les noms sont à remplacer par ceux de la personne choisie. Ne pas relancer pour créer une seconde organisation ; une Gotham existante doit être conservée et son super administrateur existant utilisé. Pour un ancien compte global, le rattachement explicite à l’organisation doit être effectué côté serveur par un opérateur autorisé ; ne pas changer son rôle ou son organisation depuis le formulaire public.

### 10.2 Démonstration locale : provisionnement explicite

Sur le front en développement, la console du navigateur peut exécuter :

```js
const demo = await import('/src/mocks/organizationAuth.js')
await demo.mockProvisionSuperAdministrator({
  profile: {
    first_name: 'Prénom à renseigner',
    last_name: 'Nom à renseigner',
    email: 'adresse du compte à renseigner'
  },
  password: prompt('Mot de passe du super administrateur (8 caractères minimum)')
})
```

Aucun mot de passe prédéfini n’est livré. Cette fonction n’est appelée ni par la page ni au démarrage, n’ouvre pas de session et refuse un deuxième super administrateur de Gotham. Se connecter ensuite avec les valeurs choisies. L’organisation doit être initialisée avant les demandes d’adhésion ; l’absence de Gotham est signalée, jamais compensée par une création automatique.

Le helper historique mockCreateOrganization est conservé pour les fixtures des tests de non-régression/isolement ; il n’est plus exposé par le service ni par l’interface publique. Les modules de simulation ne constituent jamais une barrière de sécurité en production.

### 10.3 Mesures serveur restant nécessaires pour la politique unique

- Retirer ou refuser POST /api/organizations et POST /api/auth/register publics : cacher une page ne ferme pas ces endpoints.
- Désigner Gotham City comme organisation serveur unique et refuser les demandes pour d’autres IDs. Le front continue momentanément d’envoyer organization_id pour compatibilité avec JoinRequestController.create.
- Garder l’approbation/refus et la promotion réservés au super administrateur de Gotham, sans possibilité publique d’obtenir administrator ou de définir son organisation. La page Utilisateurs et rôles ne propose plus administrator ni création directe de compte : les nouveaux comptes passent par l’acceptation des demandes. Aligner aussi POST /users et PUT /users/:id/role pour interdire de créer/promouvoir un autre compte privilégié via HTTP, et protéger le dernier super administrateur contre suppression/rétrogradation. La suppression personnelle reste permise après transfert des responsabilités, selon la section 11.
- Assurer l’unicité du compte privilégié si la politique veut un seul super administrateur ; les protections du front/démo ne remplacent pas une contrainte ou une règle serveur.
- Ne pas activer de provisionnement automatique, ne pas livrer de secret par défaut et ne pas supprimer silencieusement les anciennes données d’autres organisations. Prévoir une migration explicite si elles existent.

Les endpoints protégés de décisions/membres sont conservés, et les nouveaux parcours frontend les utilisent déjà en mode API avec CSRF. Le backend n’a pas été modifié pour la fusion graphique ; la suppression personnelle est maintenant implémentée selon la section 11.


## 11. Suppression personnelle du compte — 9 octobre 2026

Le sujet project.pdf précise que tous les utilisateurs peuvent supprimer leur compte. Mon compte propose désormais une suppression directe, sans approbation administrative. Un dialogue exige le mot de passe actuel et une confirmation explicite ; Annuler/Échap ferme le dialogue sans requête. Le bouton est bloqué pendant l’opération pour éviter les doubles clics.

### API implémentée

La route existante `DELETE /api/users/:id` est adaptée, sans ajout de route :

```http
DELETE /api/users/14
Content-Type: application/json
X-CSRF-Token: <token de la session>
```

```json
{ "current_password": "mot de passe saisi par l’utilisateur" }
```

- Le front utilise l’identifiant de la session, jamais un identifiant saisi dans le formulaire.
- Tous les rôles peuvent supprimer leur propre compte, après vérification du mot de passe côté serveur.
- Le super administrateur conserve son droit de supprimer un autre compte de son organisation ; le mot de passe de la personne n’est pas demandé dans ce cas. L’API reste compatible avec la page de gestion des utilisateurs.
- Un employé ne peut pas supprimer un collègue ; un manager ne peut pas supprimer un membre de son équipe. Le contrôle est fait par `Authorization.can_delete_account?/2`, en plus de JWT/CSRF.
- Le dernier administrator de l’organisation ne peut pas être supprimé : transférer les responsabilités auparavant.

Réponses :

| Code | Résultat |
|---|---|
| 204 | Compte supprimé. En suppression personnelle, le cookie JWT est retiré de la réponse. |
| 422 | Mot de passe actuel absent/incorrect ; `errors.current_password` indique l’erreur. Le compte et la session restent inchangés. |
| 409 | Dernier super administrateur : compte conservé. |
| 403 | Suppression d’un autre utilisateur sans droit d’administration de son organisation. |
| 401 | Session absente/expirée ou compte déjà supprimé. |
| 404 | Compte cible introuvable dans le périmètre autorisé. |

Le mot de passe est transmis uniquement dans la requête de confirmation et n’est pas enregistré dans le stockage front. Les filtres Phoenix sur les clés contenant password s’appliquent aussi à current_password. Les erreurs de validation ne doivent pas être traduites en 401 : un mot de passe de confirmation incorrect ne ferme pas la session.

### Effacement et session

L’API existante supprime réellement la ligne users. Les clés étrangères existantes effacent ses clocks, workingtime et liens team_members ; les équipes dont il était manager restent présentes avec manager_id null. Il ne s’agit pas d’une simple désactivation.

Les demandes d’adhésion et historiques métier indépendants ne sont pas tous des dépendances de users : ne pas présenter cette action comme l’effacement universel de toute trace. La politique de conservation de ces autres éléments est distincte ; aucune nouvelle politique légale n’est définie ici.

Les JWT existants de ce compte ne permettent plus d’accéder à l’API : Authenticate relit l’utilisateur en base et refuse un utilisateur supprimé. Le front attend la confirmation du serveur, efface utilisateur/contexte d’organisation/CSRF, invalide les lectures de statistiques en cours et revient à Connexion. Il ne tente pas un logout supplémentaire avec un compte déjà supprimé. Une réponse tardive après navigation ne doit pas déconnecter une autre session.

### Mode démonstration

`mockDeleteOwnAccount` vérifie le mot de passe PBKDF2, protège le dernier super administrateur et retire l’utilisateur du registre local. Ses pointages, périodes, demandes de correction et données locales de semaine sont nettoyés dans son organisation ; les données des collègues sont conservées. Les IDs supprimés ne sont pas réattribués à de nouveaux comptes, pour ne pas rendre une ancienne session valide pour une autre personne.

La démonstration supprime aussi la demande d’adhésion associée au compte ; le backend conserve actuellement ce dossier indépendant. Cette différence n’altère ni la suppression effective du compte ni l’interdiction de se reconnecter, mais doit être harmonisée si une politique commune des dossiers est retenue.

### Fichiers et vérification

- `src/components/Profile.vue` : section de suppression, confirmation et gestion des erreurs.
- `src/services/accountService.js` : transport DELETE, identifiant connecté et corps du mot de passe.
- `src/mocks/organizationAuth.js` : suppression locale et absence de réutilisation des IDs.
- `src/App.vue` : fermeture de la session et invalidation des lectures en attente.
- `time_manager/lib/time_manager/authorization.ex` : permission personnelle ou administrateur du périmètre.
- `time_manager/lib/time_manager_web/controllers/user_controller.ex` : contrôle du mot de passe et retrait du cookie.
- `time_manager/lib/time_manager_web/schemas/account_deletion_request.ex` : schéma OpenAPI du corps de confirmation.

Recette : essayer Annuler, un mot de passe incorrect, la suppression d’un employé/manager, la reconnexion refusée après suppression et le refus du dernier super administrateur. Vérifier que les collègues et leurs heures restent présents.

```bash
npm run test:account
# Dans time_manager, avec Elixir compatible et une base de tests isolée :
mix precommit
```
