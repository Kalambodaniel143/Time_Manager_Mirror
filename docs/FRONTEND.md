# Frontend : raccordement au backend

État du raccordement après vérification du routeur Phoenix du dépôt et de la spécification `/api/openapi` du serveur `http://34.155.104.175:4000`, le 12 octobre 2026. Le code frontend est modifié localement ; aucun déploiement ni changement de base distante n’a été effectué.

## Démarrer en mode réel

Dans `time-manager-dashboard/.env.local` :

```env
VITE_AUTH_USE_MOCK=false
VITE_USE_MOCK=false
VITE_API_URL=/api
VITE_BACKEND_URL=http://34.155.104.175:4000
```

Puis `npm run dev` depuis `time-manager-dashboard`. Redémarrer Vite après modification des variables. Le navigateur appelle `/api` sur son origine Vite ; le proxy transmet au backend distant. Un serveur Phoenix local n’est pas nécessaire dans cette configuration.

`VITE_BACKEND_URL` configure seulement le proxy de développement. En production, `.env.production` conserve `/api` et le serveur web doit assurer ce proxy. Les variables `VITE_*` sont publiques et ne doivent contenir aucun secret.

## Fonctionnalités réellement raccordées

| Écran/fonction | API utilisée | Comportement |
|---|---|---|
| Connexion, restauration, déconnexion | `POST /auth/login`, `GET /auth/session`, `POST /auth/logout` | Cookie JWT HttpOnly ; jeton CSRF transmis par le transport partagé. Aucun utilisateur fictif en cas d’erreur. |
| Rejoindre Gotham | `GET /organizations/lookup?name=Gotham%20City`, `POST /join-requests` | Profil réel, organisation résolue par le front ; aucun choix libre d’organisation/rôle et aucun compte actif avant acceptation. |
| Suivi d’adhésion | `POST /join-requests/status` | Référence privée de la demande. |
| Administration Gotham | `/organizations/:id/join-requests`, `/:request/approve`, `/:request/reject`, `/members` | Demandes et membres réels ; acceptation avec mot de passe fourni par l’administrateur. Nécessite un compte rattaché à Gotham. |
| Rôle des membres | `PATCH /organizations/:id/members/:userId` | Promotion employé/manager contrôlée par le serveur. |
| Utilisateurs et rôles | `GET /users`, `GET /roles`, `PUT /users/:id/role`, `DELETE /users/:id` | Comptes du périmètre de l’administrateur ; compte privilégié protégé dans l’interface. |
| Mon compte : identité et mot de passe | `PUT /users/:id` | Identifiant, email, prénom/nom ; changement de mot de passe avec mot de passe actuel. Disponible aussi pour les comptes réels de Gotham. |
| Suppression personnelle | `DELETE /users/:id` | Confirmation par mot de passe ; déconnexion uniquement après succès. Le backend refuse le dernier administrateur. |
| Équipes et droits / Mes équipes | `GET/POST /teams`, `PUT/DELETE /teams/:id`, `POST /teams/:id/members`, `DELETE /teams/:id/members/:userId` | Composition et manager réels ; écriture réservée à l’administration. L’écran des droits réutilise cette gestion réelle. |
| Mon équipe / Vue des heures | `GET /teams`, `GET /workingtime/:id`, `GET /clocks/:id` | Membres des équipes réellement gérées ; sélection d’équipe ; durées et alertes de départ manquant. Les managers n’affichent pas les membres d’une équipe qu’ils ne gèrent pas. |
| Pointage | `GET/POST /clocks/:id` | Arrivée, pause, reprise et départ personnels. Les périodes enregistrées sont rechargées après succès. |
| Départ oublié | `POST /clocks/:userId/:clockId/complete` | Complète son propre départ selon les validations du backend. |
| Mes heures / fiche d’un agent | `GET /workingtime/:userId`, `GET /workingtime/:userId/:id` | Tableau et cartes depuis l’API ; accès aux fiches et aux graphiques. Une journée sans période n’est pas déclarée en repos. |
| Ajout/correction/suppression d’une période | `POST /workingtime/:userId`, `PUT/DELETE /workingtime/:id` | Édition directe par les responsables autorisés, selon les contrôles du serveur. Aucun faux workflow d’approbation. |
| Graphiques | `GET /workingtime/:userId` | Histogramme, évolution et répartition par jour de la semaine ; valeurs fixes supprimées. |
| Heures du mois / CSV | `GET /users`, `GET /teams`, `GET /workingtime/:userId` | Durées réelles par agent, liste de ses équipes, total et export CSV. Aucun calcul de salaire. |

Toutes les routes sont préfixées par `/api`. Les autorisations réelles restent celles du serveur, même si un bouton est masqué dans l’interface.

## Comptes historiques sans organisation

La réponse backend peut légitimement contenir `organization: null`, `user.organization_id: null` et des noms absents. Ces comptes peuvent se connecter avec leur identifiant/email réels. Ils accèdent aux utilisateurs, équipes et heures de l’espace sans organisation que le backend autorise, sans être transformés en membres de Gotham. Le compte doit être rattaché côté serveur pour ouvrir Administration Gotham ou traiter les demandes d’adhésion.

Les incohérences d’identifiants d’organisation, de rôle ou d’identifiant utilisateur restent refusées. Une organisation différente de Gotham reste refusée par ce parcours.

## Durées et limites des statistiques

- Le backend fournit les périodes terminées avec `start`, `end` et `user_id`. Les pauses ne sont pas comptées lorsque les périodes fournies les excluent.
- Les graphiques et le relevé mensuel découpent les périodes aux limites des jours/mois en UTC, y compris les services traversant minuit. Le changement d’heure local ne modifie pas la durée UTC.
- Un agent membre de plusieurs équipes n’est compté qu’une fois dans le total mensuel. Les lignes restent par agent : additionner plusieurs totaux d’équipes pourrait compter ses heures plusieurs fois.
- Le relevé charge les périodes par lots de quatre utilisateurs. Une lecture en erreur bloque l’export ; elle n’est pas remplacée par zéro ou par une donnée fictive.
- L’API n’a pas de route d’agrégation mensuelle ni de pagination dans ce contrat. Pour de gros volumes, prévoir une agrégation serveur plutôt que récupérer tout l’historique de chaque compte.
- Les catégories jour/nuit des cartes sont des estimations frontend à partir des horaires. Sans règles serveur, aucun seuil d’heures supplémentaires ni multiplicateur de paie n’est appliqué en réel.

## Ce qui reste sans backend

| Fonction manquante | Affichage en mode réel | Travail serveur nécessaire |
|---|---|---|
| Planning employé et équipe, prochaines gardes, publication | Message d’indisponibilité ; pas de gardes fictives. | Affectations persistantes, horaires/lieux, état brouillon/publié et versions. |
| Demandes d’échange de garde | Actions indisponibles. | Demandes, décisions et permutation transactionnelle des gardes. |
| Demandes de correction avec examen/raison/historique | Actions de demande indisponibles ; indication de contacter le responsable. | Routes de `correctionService.js` : liste, création et décision ; contrôle de périmètre et conservation des horaires initiaux. Ces routes n’existent pas dans le routeur vérifié. L’édition directe des périodes est, elle, raccordée. |
| Notes hebdomadaires partagées | Formulaire masqué. | Stockage lié à utilisateur/semaine, visibilité salarié/responsable autorisé. |
| Validation groupée, clôture ou réouverture des semaines | Boutons et états de validation indisponibles. | Feuilles persistantes, états/dates/validateur, validation atomique, contrôle des anomalies et interdiction d’auto-validation. |
| Permissions fines valider/corriger/publier | Pas de cases à cocher de démonstration. | Permissions distinctes par utilisateur/équipe et contrôle backend. Les rôles et la composition des équipes sont déjà réels. |
| Règles d’organisation : quotas de nuits, seuils, délai de publication | Aucun quota de démonstration appliqué aux comptes réels. | Lecture/écriture de règles effectives par organisation. |
| Journal métier et notifications de ces changements | Historique fictif masqué. | Événements d’audit, notifications et états d’envoi. |
| Paie : salaire, majorations, récupération, astreintes, congés/arrêts | Relevé de durées réelles seulement. | Catégories et politiques contractuelles, calculs persistants, clôture et intégration paie. |
| Lecture vocale | Non implémentée. | Une première lecture avec synthèse vocale du navigateur peut être réalisée sans API backend. |
| Préférences d’affichage et progression du guide synchronisées | Conservées dans ce navigateur. | Préférences de compte serveur si une synchronisation entre appareils est souhaitée. |

Le backend expose encore la création publique d’organisation et l’inscription directe. Le frontend ne les propose pas ; leur restriction côté serveur reste nécessaire pour garantir la politique Gotham unique et administrateur créé manuellement.

## Simulation et stockage local

`npm run dev:demo` active explicitement les deux indicateurs de simulation. Les mocks sont conservés pour cette utilisation ; ils ne sont pas un stockage de secours lorsque l’API échoue. Les écrans des équipes/users backend sont réservés au mode réel.

En réel, le frontend ignore les anciens stocks métier `tm-org` et les jeux de gardes/paie/membres de démonstration. Il conserve seulement les préférences d’affichage et l’état du guide dans `localStorage`, et le jeton CSRF dans `sessionStorage`. Le cookie JWT est géré par le navigateur et n’est pas lisible en JavaScript.

## Vérification

```bash
npm run build
npx eslint src dev test vite.config.js
node --test test/*.test.js
```

Les tests couvrent les comptes sans organisation, le maintien du périmètre des managers, les données locales ignorées, les erreurs sans repli sur des mocks, les limites de mois/minuit/changement d’heure, la déduplication du relevé, le CSV et les origines du proxy. Ils complètent les tests de connexion, pointage, départ oublié et suppression existants.
