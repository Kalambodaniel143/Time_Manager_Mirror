# Contrat backend — Gotham City, adhésions et super administrateur

La section 13 décrit l’implémentation backend/frontend actuelle et remplace les anciennes limites de raccordement.

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

**État serveur à distinguer :** le nouveau routeur local refuse la création publique d’organisation et l’inscription directe (403) ; l’admission et le provisionnement manuel sont conservés. Les nouveaux workflows sont implémentés dans ce dépôt (section 13), mais nécessitent leur déploiement et leurs migrations sur le serveur distant. Les vérifications de développement utilisent la base de tests ; aucune base distante n’a été modifiée.

## 2. Simulation et branchement réel

Le circuit utilise désormais l’API par défaut. La simulation persistante n’est activée que par une demande explicite, indépendante de `VITE_USE_MOCK` :

```env
VITE_AUTH_USE_MOCK=true
```

Le même écran LoginScreen sert désormais en mode simulation et API. `organizationService.js` utilise le transport HTTP partagé en mode réel, avec cookie HttpOnly et jeton CSRF. `stores/auth.js` restaure la session complète via `/auth/session`, et distingue le contexte réel `auth.organization` du contexte de démonstration `auth.organizationSession` pour ne jamais router les données réelles vers les mocks.

Pour utiliser la connexion, l’adhésion et les décisions sur le backend existant :

```env
VITE_AUTH_USE_MOCK=false
VITE_USE_MOCK=false
VITE_API_URL=/api
VITE_BACKEND_URL=http://localhost:4000
```

Redémarrer Vite après un changement de variables ; reconstruire le bundle pour la production. Les variables `VITE_*` sont publiques, ne jamais y placer de secret.

En simulation, les données sont propres à ce navigateur et à cette origine. La simulation n’est pas un mécanisme de sécurité : son stockage peut être modifié par l’utilisateur. Les mots de passe sont stockés sous forme de dérivés PBKDF2 salés pour ne pas les conserver en clair, mais cela ne transforme pas le navigateur en serveur d’authentification.

Les utilisateurs simulés ne sont pas créés dans le backend. Depuis la fusion, `App.userId` contient leur identifiant local et les services de pointage/périodes/corrections dirigent explicitement leurs appels vers `mocks/organizationWork.js` tant que `auth.organizationSession` existe. Ces identifiants ne sont pas envoyés à l’API. Les données sont persistées sous `tm-work-demo:<organization_id>` ; planning, droits, notes, règles et validation locale sous `tm-org:<organization_id>`. La connexion backend conserve le transport API et `auth.user.id`. Les pages d’administration des utilisateurs et équipes backend sont accessibles en mode backend, tandis que les comptes simulés se gèrent dans Administration Gotham.

Le transport commun transmet `X-CSRF-Token` aux routes protégées. Le token reçu à la connexion est conservé lors de la restauration `/auth/session`, dont la réponse n’a pas besoin de le répéter. Les réponses canonical backend `administrator` sont normalisées en alias admin pour l’écran métier, puis en administrator dans l’état partagé. Les sessions d’une autre ville sont refusées. Les comptes historiques sans organisation sont acceptés uniquement lorsque `organization` et `user.organization_id` sont tous deux absents ou null : ils accèdent à l’espace sans organisation autorisé par le backend, sans rattachement fictif à Gotham, et sans écran d’adhésions. Le prénom et le nom peuvent être null pour ces comptes ; l’identifiant et l’email restent obligatoires. Cette validation ne remplace pas le contrôle serveur de périmètre.

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
| `birth_date` | Obligatoire uniquement pour rejoindre : date civile `YYYY-MM-DD` valide, depuis `1900-01-01`, âge de 18 ans révolus (section 14) |
| Organisation | Valeur fixe Gotham City, provisionnée manuellement ; aucun nom libre fourni par le formulaire |
| Mot de passe | 8 à 128 caractères, refus des valeurs trop simples (section 14) ; ne pas modifier silencieusement la valeur |
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
- En simulation, l’employé propose une correction sur une période existante ; ses heures ne changent qu’après acceptation par un autre responsable autorisé. En réel, ce workflow reste indisponible sans ses endpoints ; les responsables autorisés utilisent l’édition directe des périodes.
- Les heures existent en tableau desktop et cartes mobile avec durée séparée. Les propositions ne sont pas additionnées aux heures confirmées.
- Les vrais membres d’équipe sont lus depuis `/teams` en mode backend pour Mon équipe. Dans la simulation, les membres visibles de l’organisation constituent un groupe de démonstration ; cette simplification ne remplace pas les permissions par équipe du serveur.
- En simulation, le planning employé a deux semaines distinctes et le planning responsable permet une sélection d’agent sur mobile. En réel, aucun planning fictif n’est affiché.
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

En mode réel, les fonctions sans route serveur sont désormais indisponibles et ne lisent pas les données locales de démonstration. En mode simulation explicite, les prototypes ci-dessous sont conservés. Le relevé mensuel constitue une exception : il est calculé depuis les périodes de l’API, sans devenir un calcul de paie.

| Fonction | Comportement actuel | Besoin serveur |
|---|---|---|
| Planning/publication | Indisponible en réel ; exemple local en simulation. | Gardes réelles, brouillon/version publiée, dates de publication et notifications. |
| Demande d’échange | Indisponible en réel ; demande locale en simulation. | Gardes identifiées, demande persistante, décision et échange transactionnel, contrôles de contraintes. |
| Notes | Masquées en réel ; stockage local en simulation. | Note liée au salarié, à la semaine et au manager autorisé, visibilité identique pour les deux. |
| Validation | Actions masquées en réel ; état local par utilisateur/semaine en simulation. | Feuille hebdomadaire persistante, validateur/date, anomalies bloquantes, clôture et nouvelle validation après correction. |
| Droits/règles/journal | Équipes et rôles réels accessibles ; droits fins, règles et journal indisponibles en réel. | Droits validate/correct/publish par équipe, règles par organisation et journal métier persistant. |
| Paie | Relevé mensuel réel par agent et CSV de durées ; paie de démonstration seulement en simulation. | Calcul de paie serveur : catégories, majorations, arrondi, congés et clôture explicites. |

Les dépassements de nuits ne suppriment pas les heures travaillées. La sélection automatique les signale et ne les coche pas ; le responsable peut les examiner puis les sélectionner explicitement. Un départ manquant ou des pointages non vérifiés restent bloquants dans le front. Le serveur devra appliquer une politique cohérente et empêcher l’auto-validation.

Les règles locales de la simulation contiennent :

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


### Reprendre le super administrateur du mock dans la base réelle

Un mot de passe mock dérivé avec PBKDF2 ne permet pas de retrouver son texte ni de copier directement son hash dans l’authentification Argon2 du backend. Pour conserver les mêmes identifiants, saisir le mot de passe original dans le terminal, sans le publier dans un message.

Depuis la racine du dépôt, dans l’environnement où les paramètres PostgreSQL du backend sont configurés :

```bash
bash scripts/recreate_gotham_admin.sh
```

Le script propose l’adresse `nando@gotham.city` et demande prénom/nom (les valeurs proposées Nando/Martin sont à corriger si le mock utilisait une autre identité). Le mot de passe et sa confirmation sont masqués ; aucun secret n’est écrit dans le dépôt. Les migrations et les rôles doivent déjà exister.

Il crée Gotham et le compte ensemble si la ville n’existe pas, ou ajoute le compte à Gotham si elle existe sans administrateur. Un compte déjà identique et avec le même mot de passe est réutilisé. Un compte différent portant cet email ou un autre super administrateur de Gotham bloque l’opération : aucune suppression, promotion ni réinitialisation silencieuse n’est réalisée.

Cette commande est explicite et manuelle ; elle n’est pas exécutée au démarrage du site. Elle nécessite un Elixir compatible avec le projet et l’accès à la base réelle. Son ajout ne signifie pas qu’un compte a déjà été créé.

## 12. Raccordement étendu aux routes existantes — 12 octobre 2026

Le détail des écrans et des fonctions sans API est dans [FRONTEND.md](FRONTEND.md). Ce raccordement ne modifie ni le code backend ni la base distante.

- Le front accepte la session historique sans organisation telle que rendue par `SessionJSON` : organisation et `user.organization_id` null, rôle cohérent, identifiant positif, username et email renseignés. Il ne crée pas de rattachement ni de permission Gotham. Les noms sont facultatifs uniquement pour ces comptes historiques.
- Le profil réel permet les mises à jour déjà acceptées par `PUT /users/:id` (`user` contenant username/email/prénom/nom, ou password/current_password). Les champs genre/date/lieu restent en lecture dans les réponses, sans écriture de profil ajoutée hors contrat.
- Les équipes, managers et membres sont fournis par `GET /teams`. Un manager n’utilise pour la vue des heures que les équipes dont `manager.id` est son identifiant. Aucun membre fictif ne complète une équipe vide ou une réponse en erreur.
- Les graphiques et le relevé mensuel utilisent les périodes `GET /workingtime/:userId`. Le relevé obtient le périmètre via `GET /users`, les équipes via `GET /teams`, et compte chaque utilisateur une seule fois. Il découpe les périodes aux limites UTC du mois et exporte des durées par agent. Il ne représente pas une API de paie.
- Les mois/jours du relevé et des graphiques sont explicitement en UTC ; une éventuelle convention de jour de service/fuseau métier devra être définie et appliquée avant les calculs de paie.
- Aucun seuil de démonstration ni multiplicateur de salaire n’est appliqué en réel. Les droits fins, règles, notes, planning, échanges, validation de semaines et journal restent à implémenter sur le serveur. Leurs interactions locales sont indisponibles en réel.
- Les services de demande de correction sont conservés comme contrat futur, mais leurs boutons/listes n’appellent pas ces endpoints absents en réel. L’édition directe de période reste raccordée au backend.
- Le proxy Vite peut viser un serveur distant via `VITE_BACKEND_URL`. Il réécrit seulement l’Origin/Referer de sa propre origine vers le backend, pour conserver le contrôle d’origine Phoenix après le changement de Host ; les origines tierces sont laissées au contrôle serveur.

Pour un volume important, une route de relevé agrégé par mois serait préférable aux lectures de tous les historiques utilisateur. Elle devra conserver le périmètre de session, fournir les totaux exacts et expliciter le fuseau, l’arrondi et les catégories. Aucune nouvelle route d’agrégation n’est requise pour le raccordement actuel.

## 13. Implémentation complète des workflows — 12 octobre 2026

Cette section décrit le nouveau code backend/frontend du dépôt et remplace les états « route absente », « uniquement local » ou « à implémenter » des sections 9.2–9.4 et 12. Le serveur distant doit encore recevoir ce code et les trois migrations : voir [DEPLOIEMENT_WORKFLOWS.md](DEPLOIEMENT_WORKFLOWS.md). Le détail des écrans est dans [FRONTEND.md](FRONTEND.md).

### Transport, identité et admission

Toutes les nouvelles routes sont sous `/api`, dans les pipelines API/auth existants : cookie JWT HttpOnly, jeton `X-CSRF-Token`, contrôle d’origine, identité et rôle rechargés depuis la base. Les réponses JSON sont enveloppées dans `data`. Les erreurs restent `400/401/403/404/409/422` ; les conflits de version, état, clôture ou chevauchement donnent un message explicite. Le CSV est une réponse `text/csv`, pas une enveloppe JSON.

`POST /auth/register`, `POST /organizations` et `POST /users` répondent désormais `403` : les comptes sont créés par admission ou provisionnement manuel. Les routes de changement de rôle refusent la création d’un administrateur ; le rôle privilégié reste manuel. Les domaines internes de provisionnement sont conservés pour les scripts et les fixtures.

### Routes nouvelles exactes

| Méthode | Route | Autorisation / effet |
|---|---|---|
| GET | `/workforce/context` | Connecté : règles effectives, préférences personnelles et permissions des équipes gérées. |
| GET/PATCH | `/organizations/:org_id/rules` | Lecture dans sa propre organisation ; écriture par son administrateur. |
| GET/PATCH | `/teams/:id/permissions` | Lecture d’une équipe accessible ; écriture par son administrateur. |
| GET/PUT | `/users/:user_id/week-notes/:week` | Lecture selon le périmètre ; seul le salarié écrit sa note. |
| GET | `/weekly-sheets?week=YYYY-MM-DD` | Semaines des utilisateurs accessibles, y compris une représentation open si aucune ligne n’existe encore. |
| POST | `/weekly-sheets/validate` | Validation atomique d’une sélection, permission validate, jamais soi-même. |
| POST | `/weekly-sheets/:user_id/:week/:action` | Actions close/reopen, permission validate, motif obligatoire. |
| GET | `/correction-requests?user_id=...` | Suivi personnel ou du périmètre du responsable. |
| POST | `/workingtime/:id/correction-requests` | Proposition sur sa propre période ; aucune mutation directe. |
| PATCH | `/correction-requests/:id` | Décision approved/rejected par un autre responsable, permission correct. |
| GET | `/plans?from=YYYY-MM-DD&to=YYYY-MM-DD` | Équipes gérées et/ou appartenances autorisées ; publications pour les employés. |
| GET | `/plans/:id` | Planning d’une équipe accessible ; brouillon seulement pour son manager actuel ou l’administration. |
| POST | `/teams/:id/plans` | Création d’un planning par le manager de l’équipe ou son administration. |
| PATCH | `/plans/:id` | Modification de la période d’un brouillon vide. |
| DELETE | `/plans/:id` | Retrait d’un planning futur ; publication requise si déjà publié, motif obligatoire. |
| POST | `/plans/:plan_id/shifts` | Nouvelle affectation d’un membre de l’équipe. |
| PUT/DELETE | `/plans/:plan_id/shifts/:id` | Modification/suppression de garde future. |
| POST | `/plans/:id/publish` | Permission publish ; contrôles d’affectation, horaires, absences et quotas. |
| GET/POST | `/shift-swaps` | Liste personnelle/périmètre responsable ; proposition d’échange de sa garde avec celle d’un collègue du même planning. |
| PATCH | `/shift-swaps/:id/consent` | Accord/refus uniquement par le collègue destinataire. |
| PATCH | `/shift-swaps/:id` | Décision d’un autre responsable après consentement ; approbation nécessite validate pour les deux agents et publish pour l’équipe. |
| GET/POST | `/absence-requests` | Consultation du périmètre et demande personnelle de congé, maladie ou récupération. |
| PATCH | `/absence-requests/:id` | Décision par un responsable avec permission validate. |
| POST | `/absence-requests/:id/cancel` | Retrait personnel pending ou annulation par un responsable ; motif obligatoire. |
| PATCH | `/absence-requests/:id/payment` | Confirmation des heures rémunérables d’une absence approuvée, par un autre responsable autorisé. |
| GET | `/payroll?month=YYYY-MM` | Relevé calculé pour l’organisation de l’administrateur. |
| GET | `/payroll/export?month=YYYY-MM` | CSV du même calcul et du même périmètre. |
| GET/PUT | `/users/:id/payroll-profile` | Lecture personnelle ou administration ; taux/devise modifiés uniquement par son administration. |
| GET/PATCH | `/auth/preferences` | Préférences du compte authentifié, sans identifiant d’utilisateur dans le corps. |
| GET | `/audit-events` | 200 dernières actions de son organisation, pour l’administration. |
| GET | `/notifications` | Notifications personnelles filtrables et paginées, 50 par page (section 14). |
| PATCH | `/notifications/:id/read` | Marquage comme lue uniquement pour leur destinataire. |

Les routes existantes de pointage/périodes, utilisateurs et équipes sont conservées, avec protection des semaines et journalisation supplémentaires. L’index de périodes filtre désormais les **chevauchements** de la fenêtre start/end : les périodes originales sont renvoyées sans découpage, et le front répartit leur affichage sur les journées. Cela conserve les services traversant minuit, une semaine ou un mois.

### Corps et états

Règles : `PATCH /organizations/:id/rules` avec `{"rules": {...}}`. Clés acceptées :

- `maxConsecutiveNights` : entier 1–31, défaut 3.
- `maxNightsPerWeek` : 0–7, et `maxNightsPerMonth` : 0–31 ; 0 désactive ce quota, défaut 0.
- `overtimeThreshold` : 1–168 heures/semaine, défaut 40.
- `publishDaysAhead` : 0–365 jours, défaut 14.
- `nightStart`/`nightEnd` : heures UTC 0–23 distinctes, défaut 22/6.
- `nightMultiplier`/`overtimeMultiplier` : nombres 1–10, défaut 1,5/2.
- `paidAbsenceKinds` : liste de leave/sick, vide par défaut ; recup n’est pas rémunérée.
- `timezone` : `Etc/UTC` dans cette version.

Permissions : `{"permissions":{"validate":true,"correct":true,"publish":false}}`. Les trois flags sont booléens et attachés à l’équipe ; ils s’appliquent à son manager actuel. Les valeurs initiales sont validate/correct true et publish false. L’administration conserve ses droits de périmètre. Le contexte fournit team_id, manager_id, member_ids et ces flags pour piloter l’interface ; ces données ne remplacent pas le contrôle serveur.

Note : `{"note":"..."}`, limitée à 2000 caractères. `week` est une date de lundi. Le même enregistrement de feuille conserve note, status (open/validated/closed), reviewer_id, reviewed_at et reason. Validation : `{"week":"2026-10-05","user_ids":[14,15]}`, 1–100 comptes uniques. Close/reopen : `{"reason":"..."}`, 1–500 caractères. Seules les semaines terminées sont validables ; les départs manquants et corrections pending sont bloquants.

La correction conserve le contrat de la section 9.2 : `{"correction":{"start":"...","end":"...","reason":"..."}}`, puis décision `{"status":"approved","reason":"..."}` ou rejected avec motif obligatoire. Les horaires before sont conservés ; accepter une proposition périmée ou déjà traitée retourne 409. La période n’est changée qu’au succès de la transaction.

Planning : `POST /teams/:id/plans` avec `{"plan":{"start":"2026-10-27","days":14}}`, 1–31 jours. Les réponses fournissent id, team_id, start, days, revision, published_revision, published_at, shifts, members, can_manage et can_publish. Un brouillon vide peut recevoir start/days par PATCH avec revision.

Garde : `{"shift":{"user_id":14,"start":"2026-10-27T22:00:00Z","end":"2026-10-28T06:00:00Z","kind":"night","place":"Centre","revision":1}}`. Kind : day/night/oncall/leave/rest ; durée positive jusqu’à 24 h. L’utilisateur est vérifié comme membre, la garde doit commencer dans la période du planning et être future. DELETE garde et publication utilisent `{"revision":2}` ; retrait du planning ajoute reason. Les dates et limites sont calculées en UTC.

Une publication conserve une copie immuable des affectations. Les modifications incrémentent revision ; les employés continuent à lire la dernière publication. Les contrôles utilisent les publications des autres équipes pour détecter chevauchements et quotas mensuels/hebdomadaires, y compris les frontières de plannings. Un planning commencé ne peut pas être supprimé.

Échange : `{"shift_id":1,"target_shift_id":2,"reason":"..."}`. Les utilisateurs sont dérivés des deux gardes ; le demandeur doit posséder la première. Consentement : `{"accepted":true}`. États : pending → consented → approved/rejected ; le refus du collègue produit rejected. La décision utilise status/reason. L’acceptation permute les propriétaires des deux gardes et actualise la publication dans une seule transaction ; elle vérifie snapshots, membres et règles courantes. Modifier/supprimer une garde ou retirer un planning rejette ses échanges actifs et notifie les agents.

Absence : `{"start":"...","end":"...","kind":"leave","reason":"..."}` ; kind leave/sick/recup, plage positive limitée à 366 jours. Décision : `{"status":"approved","reason":"","payable_hours":"24"}`. Payable_hours est facultatif à l’acceptation, mais nécessaire pour chiffrer une absence rémunérable ; il peut être complété par l’endpoint payment. Il est non négatif, fini et ne dépasse pas l’intervalle. Le repos compensatoire pris n’est pas payable. Un manager ne décide jamais sa propre absence. États : pending, approved, rejected, cancelled. Les demandes et approbations vérifient les chevauchements et les semaines verrouillées.

Profil de paie : `{"hourly_rate":"15.50","currency":"EUR"}`. Taux non négatif jusqu’à 100000, fini, deux décimales maximum ; null supprime le taux. Devises EUR/USD/GBP. Le taux n’est jamais supposé ni remplacé par un exemple.

Préférences : theme (light/night/contrast), strong_text, tour_seen, speech_enabled (booléens), speech_rate (0,5–2), speech_voice (texte jusqu’à 200 caractères). Les voix sont propres à l’appareil ; le backend stocke la sélection, pas une piste audio.

### Calcul financier

Les catégories de travail sont exclusives : day, night hors dépassement hebdomadaire, sup, recup (travail donnant droit à récupération), oncall. La catégorie d’une période enregistrée est work/oncall/recup ; jour/nuit et dépassements sont calculés, pas choisis librement comme un multiplicateur dans le corps client.

Le calcul récupère le début de la semaine contenant le premier jour du mois pour tenir compte des heures du mois précédent consommant déjà le seuil hebdomadaire. Il découpe en UTC aux frontières d’heure/semaine/mois. Les heures sup. ne cumulent pas la majoration nuit. Montants : Decimal, arrondi final à deux décimales ; totaux monétaires séparés par devise. Les personnes présentes dans plusieurs équipes ne sont comptées qu’une fois.

Leave/sick et recup_taken sont des absences suivies séparément du total travaillé. La rémunération d’absence n’est incluse que pour les catégories activées et la quantité confirmée par le responsable. Cette quantité est répartie au prorata de l’intervalle si l’absence traverse le mois ; le travail en chevauchement est déduit et signalé. Un montant reste null si un taux ou une quantité nécessaire manque. Le relevé fournit absence_payment_incomplete, absence_conflict et confirmed, et le front signale les régularisations et semaines non validées. L’export est un relevé du scénario, pas une déclaration fiscale ou un calcul de salaire net.

### Atomicité, historique et sécurité

Les mutations des heures et les validations utilisent un verrou par salarié ; les validations groupées verrouillent les comptes dans l’ordre des identifiants. Les décisions vérifient l’état courant sous verrou. Les plans utilisent revision et un verrou de publication par organisation. Les tests de concurrence utilisent des connexions PostgreSQL indépendantes : une seule création/décision réussit lorsque deux appels visent la même opération.

Une semaine validated/closed bloque les périodes, les pointages datés dans cette semaine, les notes et les régularisations d’absence. Réouvrir exige un responsable différent et un motif. Les utilisateurs, équipes, plannings et permissions restent dans le périmètre réel ; une rétrogradation interdit immédiatement les accès de manager au prochain appel.

Les événements d’audit enregistrent l’acteur, l’organisation, l’action et les détails métier pertinents. Les mots de passe, hashes et jetons ne sont pas journalisés. Les notifications de publication/décision restent dans l’application et sont personnelles ; aucun email/SMS ou rappel programmé supplémentaire n’est promis par cette implémentation.

### Base, vérification et mise en ligne

Les tables workforce_settings, team_permissions, account_preferences, weekly_sheets, correction_requests, workforce_plans, planned_shifts, shift_swaps, absence_requests, payroll_profiles, workforce_events et workforce_notifications sont créées par les migrations, sans suppression des données existantes. Workingtime reçoit kind ; absence_requests reçoit payable_hours. Les clés étrangères nettoient les données opérationnelles liées à un compte supprimé et anonymisent les références d’acteurs du journal.

```bash
# time_manager : base de tests isolée, Elixir compatible
mix precommit
# time-manager-dashboard
node --test test/*.test.js
npx eslint src dev test vite.config.js
npm run build
```

La mise en ligne doit installer les nouveaux backend/frontend et exécuter les migrations sur la base du serveur existant. Le code local n’active pas de nouvelles routes sur le serveur distant à lui seul.

## 14. Validations, récupération et accessibilité — 13 octobre 2026

Cette section décrit les changements implémentés dans le dépôt. Elle complète les parcours précédents ; leur disponibilité distante exige le déploiement et les migrations.

### Identité, âge et mots de passe

- Admission : **18 ans révolus**, date évaluée en UTC, date civile valide depuis 1900. Le jour du dix-huitième anniversaire est accepté. Un anniversaire du 29 février est considéré au 28 février dans une année non bissextile. Le front limite la date et le serveur répète la validation.
- Prénom/nom : lettres Unicode, espaces, apostrophes droites/courbes et traits d’union ; les chiffres sont interdits, y compris les chiffres Unicode. Les champs obligatoires et la limite de 100 caractères restent applicables.
- Nouveau mot de passe : 8–128 caractères ; refus des valeurs uniquement numériques, des mots de passe courants même suivis de chiffres (`Password2026!`, `azerty123`), des répétitions courtes et des valeurs avec moins de quatre caractères distincts après normalisation. Les phrases secrètes sont acceptées sans imposer majuscule/symbole. Cette règle s’applique à la création, l’approbation et au changement/rétablissement. Elle ne bloque pas la connexion d’un ancien compte sur la seule base de la nouvelle politique.
- L’employé et le manager conservent le changement personnel dans **Mon compte**, avec le mot de passe actuel. Un email informe le titulaire après modification ; il ne contient aucun mot de passe. Le front déconnecte le compte après succès et demande une nouvelle connexion.
- `users.session_version` augmente lors d’un changement/rétablissement. Le JWT porte cette version et le serveur la compare à la base à chaque requête authentifiée. Les anciennes sessions deviennent invalides (`401`), même sur un autre appareil. La version ne fait pas partie des champs modifiables par le client.

### Récupération publique du mot de passe

Préfixe `/api`, JSON, sans session requise ; contrôle d’origine et limitation de débit actifs.

| Méthode et chemin | Corps attendu | Succès | Erreurs |
|---|---|---|---|
| `POST /auth/forgot-password` | `{"email":"agent@example.test"}` | `202 {"data":{"message":"Si un compte actif correspond…"}}`, même réponse pour compte absent/non vérifié/présent | `400` structure incorrecte ; `422` format email ; `429` débit dépassé. |
| `POST /auth/reset-password` | `{"email":"agent@example.test","code":"01234567","password":"<nouvelle phrase secrète>"}` | `200 {"data":{"message":"Mot de passe réinitialisé. Connectez-vous avec votre nouveau mot de passe."}}` | `400` structure incorrecte ; `422` code incorrect/expiré/utilisé ou mot de passe faible ; `429` débit dépassé. |

Le code comporte **8 chiffres**, expire après **15 minutes**, s’utilise une seule fois et est remplacé à chaque nouvelle demande. Seul son SHA-256 est conservé dans `password_recoveries`. Après cinq mauvais codes, demander un nouveau code est obligatoire. Une erreur de qualité du nouveau mot de passe ne consomme pas le code. Un changement personnel/administratif invalide également les codes précédents.

La requête publique n’expose ni code, ni existence du compte, ni diagnostic de délivrance. L’envoi de récupération est délégué à une tâche supervisée pour que la réponse publique n’attende pas le fournisseur. Il n’existe pas de file persistante de réessai : après interruption du serveur, demander un nouveau code. Un échec d’envoi est journalisé côté serveur ; l’utilisateur peut réessayer ou contacter l’administration. Le code et le mot de passe sont filtrés des logs Phoenix. Les emails de récupération et d’alerte sont bilingues FR/EN. L’envoi utilise `EMAIL_DELIVERY` : Mailpit pour les essais, Resend pour les boîtes réelles. En mode mock, la récupération explique qu’aucun email ne peut être envoyé ; aucun faux succès n’est affiché.

Limites actuelles : demande de code 5/minute/email et 50/minute/IP ; rétablissement 10/minute/email et 100/minute/IP, en plus des cinq essais par code. La réponse ne connecte pas automatiquement l’utilisateur.

### Équipes

`POST /teams/:id/members` refuse le manager de cette même équipe : `422`, avec un `errors.detail` explicite. La vérification porte sur le manager courant sous verrou transactionnel, pas sur un objet chargé avant une modification concurrente. Nommer un membre manager via `PUT /teams/:id` supprime son appartenance redondante à cette équipe. Il reste manager et conserve ses heures.

Le front exclut le manager de la liste des candidats et aligne les boutons Retirer. La migration de nettoyage retire les appartenances redondantes déjà présentes ; elle ne supprime ni utilisateur, ni équipe, ni heures. La composition reste réservée à l’administration.

### Notifications et langue

| Méthode et chemin | Paramètres | Succès |
|---|---|---|
| `GET /notifications` | `status=all` (défaut), `read` ou `unread` ; `page=1` par défaut, entier 1–100000 | `200 {"data":[Notification]}` ; filtrage **avant** pagination, 50 résultats par page. Paramètre invalide : `422`. |
| `GET /notifications/count` | Aucun ; compte connecté | `200 {"data":{"unread":3}}` ; compte toutes les notifications personnelles non lues. |
| `PATCH /notifications/:id/read` | Aucun corps requis | `200 {"data":Notification}` ; destinataire uniquement (`403` sinon, `404` identifiant absent). |
| `PATCH /auth/preferences` | `{"language":"fr"}` ou `{"language":"en"}`, en plus des champs existants | `200 {"data":Preferences}` fusionnées ; langue inconnue : `422`. |

La langue par défaut est `fr`. Le navigateur conserve le choix avant connexion ; la préférence du compte est restaurée après connexion. Les libellés, dates et commandes vocales suivent la langue. Les noms, notes et raisons saisis par les personnes ne sont pas traduits automatiquement. Les erreurs API conservent leur structure `errors.detail`/champs ; le front les présente avec le champ concerné et une action à effectuer. Les erreurs en notification flottante restent visibles jusqu’à fermeture.

Le badge est actualisé après connexion, lecture d’une notification, retour au premier plan et toutes les 30 secondes lorsque la page est visible. Ce n’est pas du WebSocket. Les nouvelles décisions de correction annoncent « Correction acceptée » ou « Correction refusée » et expliquent l’effet sur les horaires ; les anciennes notifications déjà stockées ne sont pas réécrites.

### Déploiement et vérification

Deux migrations : `20261013143422_add_password_recovery_and_session_version.exs`, puis `20261013203307_remove_managers_from_own_team_memberships.exs`. Consulter [le déploiement](DEPLOIEMENT_WORKFLOWS.md) et [la recette](RECETTE_VALIDATIONS.md). Les tests frontend/backend peuvent être exécutés localement avant publication. Travis est conservé à l’identique de main ; le raccordement des tests au pipeline est à coordonner avec son responsable. Aucun déploiement distant n’est effectué par ces modifications locales.

## 15. Fusion avec main — 14 octobre 2026

Le parcours réel d’adhésion conserve la vérification email de main. Après `POST /api/join-requests`, l’interface demande un code de **6 chiffres**, distinct du code de récupération du mot de passe (8 chiffres). `POST /api/join-requests/verify-email` prend `{"email":"agent@example.test","code":"012345"}` et répond `200 {"data":{"request_submitted":true,"organization_name":"Gotham City"}}`. `POST /api/join-requests/resend-verification` prend `{"email":"agent@example.test"}` et répond `200 {"data":{"verification_required":true}}`. Code de vérification : 10 minutes, cinq essais, hash en base. Les demandes non vérifiées ne figurent pas dans la liste administrative. La simulation locale reste sans email ni faux code à recopier.

Après acceptation réelle, main envoie les identifiants choisis par l’administrateur via `Email.credentials/4`. En simulation, la transmission reste manuelle. Les mentions de transmission exclusivement manuelle dans les sections précédentes sont remplacées par ce fonctionnement. Un échec du fournisseur lors de l’acceptation renvoie `503`, alors que le compte a déjà été créé : actualiser la liste et gérer la transmission, sans tenter de recréer le compte.

Conserver la migration `20261013100000_add_join_request_email_verification.exs` de main et appliquer aussi `allow_join_request_verification_without_user` : une vérification d’adhésion appartient à une demande, avant qu’un utilisateur n’existe. `email_verifications.user_id` doit donc pouvoir être null ; la contrainte exige toujours exactement un propriétaire (user_id ou join_request_id). Cette correction est additive et ne supprime aucune vérification.

La configuration `.travis.yml` est restaurée à l’identique de main, conformément à la règle du projet. Les scripts et tests locaux restent disponibles.
