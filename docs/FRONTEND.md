# Frontend — Time Manager

Le frontend Vue utilise désormais les API des comptes, équipes, pointages, corrections, feuilles hebdomadaires, plannings, échanges, absences, paie, permissions, journal et notifications. La lecture vocale utilise le navigateur ; ses préférences sont enregistrées dans le compte.

Ces changements sont présents dans le dépôt local. Le 12 octobre 2026, la spécification du serveur `http://34.155.104.175:4000/api/openapi` ne contenait pas encore les nouvelles routes `/workforce/context`, `/plans`, `/payroll`, `/correction-requests` et `/auth/preferences`. Le [déploiement](DEPLOIEMENT_WORKFLOWS.md) du nouveau backend et de ses migrations est nécessaire pour les utiliser sur ce serveur.

## Démarrage

Node `^22.18.0` ou `>=24.12.0` est requis. Dans `time-manager-dashboard` :

```bash
npm install
npm run dev
```

Le fichier `.env.local` sélectionne la connexion :

```env
VITE_AUTH_USE_MOCK=false
VITE_USE_MOCK=false
VITE_API_URL=/api
VITE_BACKEND_URL=http://34.155.104.175:4000
```

Pour tester le nouveau code avant son déploiement, remplacer seulement `VITE_BACKEND_URL` par `http://localhost:4000`, appliquer les migrations dans `time_manager` puis lancer ce backend local. Le compte doit exister dans cette base. Pour un backend déjà lancé, il n’est pas nécessaire d’en démarrer un second. Redémarrer Vite après changement de configuration.

Le navigateur appelle `/api` sur son origine Vite. Le proxy transmet au backend sélectionné et conserve les cookies. En production, Nginx transmet `/api` au service Phoenix ; `VITE_BACKEND_URL` concerne seulement le développement. Les variables `VITE_*` sont publiques et ne doivent contenir aucun secret.

## Architecture

- `main.js` crée Vue, installe la traduction et le routeur et monte `App.vue`.
- `App.vue` fournit la session, le thème, les préférences serveur et le contexte de l’utilisateur aux pages.
- `router/index.js` applique les règles de navigation. Les autorisations réelles sont répétées dans les contrôleurs et contextes Phoenix.
- `stores/auth.js` conserve l’utilisateur et le jeton CSRF. Le JWT reste dans un cookie HttpOnly.
- `services/http.js` ajoute `X-CSRF-Token`, transmet le cookie et traduit les erreurs API. Il supporte les réponses JSON et le CSV texte.
- `services/workforceService.js` fournit les nouvelles opérations et le contexte réactif des règles/permissions/préférences. Les listes ou rapports malformés sont refusés.
- Les composants de `components/workforce` gèrent les formulaires du planning, des échanges, des absences et les commandes vocales.
- `utils/speech.js` sélectionne une voix de l’appareil, gère la vitesse, l’arrêt et l’annulation des lectures précédentes.

## Écrans et routes

Toutes les routes du tableau sont préfixées par `/api`.

| Écran | API | Fonction |
|---|---|---|
| Connexion/session | `/auth/login`, `/auth/session`, `/auth/logout` | Authentification réelle, restauration et déconnexion. |
| Rejoindre Gotham | `/organizations/lookup`, `/join-requests`, `/join-requests/status` | Demande d’adhésion et suivi par référence privée. |
| Administration Gotham | `/organizations/:id/join-requests`, `/:request/approve`, `/:request/reject`, `/members` | Décisions et gestion des membres ; le mot de passe est fourni par l’administrateur. |
| Utilisateurs et rôles | `/users`, `/roles`, `/users/:id/role` | Lecture des comptes et promotion employé/manager ; création directe interdite. |
| Mon compte | `/users/:id`, `/auth/preferences` | Identité, mot de passe, suppression personnelle, thème, textes renforcés, guide et voix. |
| Équipes | `/teams`, `/teams/:id`, `/teams/:id/members` | Création, renommage, suppression, manager et composition. |
| Équipes et droits | `/teams/:id/permissions`, `/organizations/:id/rules`, `/audit-events` | Permissions réelles, règles de l’organisation et historique. |
| Pointage | `/clocks/:id`, `/clocks/:id/:clockId/complete` | Arrivée, pause, reprise, départ et départ oublié. |
| Mes heures / fiches | `/workingtime/:id`, `/workingtime/:userId/:periodId`, `/users/:id/week-notes/:week` | Périodes réelles et note partagée. Les périodes traversant minuit sont réparties sur leurs journées sans changer l’objet original. |
| Correction des heures | `/workingtime/:id/correction-requests`, `/correction-requests`, `/correction-requests/:id` | Proposition, examen, refus motivé, acceptation et historique. |
| Mon équipe | `/teams`, `/workingtime/:id`, `/clocks/:id`, `/weekly-sheets` | Agents autorisés, heures, alertes de départ, notes, validation groupée et état des semaines. |
| Validation/clôture | `/weekly-sheets/validate`, `/weekly-sheets/:userId/:week/:action` | Validation, clôture ou réouverture motivée. Les semaines verrouillées bloquent les mutations serveur. |
| Planning d’équipe | `/plans`, `/teams/:id/plans`, `/plans/:id`, `/plans/:id/shifts`, `/plans/:id/publish` | Brouillons, gardes, modification du brouillon vide, retrait futur et publication versionnée. |
| Mon planning / prochaines gardes | `/plans` | Affectations publiées, dates et lieux réels. |
| Échanges | `/shift-swaps`, `/shift-swaps/:id/consent`, `/shift-swaps/:id` | Proposition, accord du collègue et décision du responsable. |
| Congés et absences | `/absence-requests`, `/absence-requests/:id`, `/:id/cancel`, `/:id/payment` | Demande, examen, annulation et confirmation des heures rémunérables. |
| Paie du mois | `/payroll`, `/payroll/export`, `/users/:id/payroll-profile` | Catégories calculées côté serveur, taux horaire, montant, état de validation et CSV. |
| Notifications | `/notifications`, `/notifications/:id/read` | Publications et décisions reçues dans l’application. |
| Graphiques | `/workingtime/:id` | Histogramme, évolution et répartition calculés depuis les périodes réelles. |

## Permissions et comportements importants

- L’employé pointe pour lui-même, consulte ses heures et envoie ses demandes. Il peut lire les gardes publiées des équipes auxquelles il appartient pour proposer un échange.
- Le manager intervient uniquement sur les membres des équipes qu’il gère. Ses permissions `correct`, `validate` et `publish` sont vérifiées sur le serveur et reflétées dans les boutons.
- L’administration reste limitée à son organisation. Les permissions fines s’appliquent aux managers, pas à l’administrateur.
- Aucun responsable ne valide ou n’accepte sa propre correction/absence. L’édition directe de ses propres périodes est également interdite ; le pointage personnel reste disponible.
- Une rétrogradation invalide l’accès aux brouillons et aux opérations de manager dès les requêtes suivantes, même si l’ancien identifiant reste affecté comme manager d’une équipe.
- Une validation groupée est atomique. Un départ manquant ou une correction en attente bloque la validation.
- Une semaine validée ou clôturée doit être rouverte avant modification de ses heures, notes ou données de paie liées aux absences. Les horaires initiaux et les décisions sont conservés dans le suivi et le journal.
- Les modifications de planning transmettent sa `revision`. Un formulaire périmé produit une erreur explicite. Les employés voient la dernière publication pendant la préparation d’un nouveau brouillon.
- Un échange nécessite le consentement du collègue puis un responsable autorisé à valider et publier. La permutation et la mise à jour publiée sont atomiques. Modifier/supprimer une garde invalide ses échanges en attente.

Les comptes historiques sans organisation restent accessibles dans leur espace autorisé. Aucune organisation fictive n’est créée pour eux. Les réglages d’organisation et les adhésions Gotham nécessitent un rattachement réel.

## Calcul des heures et de la paie

Le fuseau de calcul de cette version est `Etc/UTC`. Les formulaires de planning et d’absence le précisent. Les API rendent les instants en UTC.

Le serveur découpe les périodes aux limites des heures, jours, semaines et mois. Il tient compte des heures de la semaine précédant le début du mois pour calculer correctement le seuil hebdomadaire. Les pauses sont exclues par les périodes distinctes créées lors des pointages.

Les catégories sont distinctes : travail de jour, nuit hors heures supplémentaires, heures supplémentaires, travail donnant droit à récupération, astreinte. Les heures supplémentaires utilisent leur propre coefficient ; elles ne cumulent pas le coefficient de nuit. Les valeurs initiales du scénario sont nuit ×1,5 et heures supplémentaires ×2 après 40 heures hebdomadaires, modifiables par l’administration.

Les absences de congé/maladie sont suivies séparément. Leur rémunération doit être activée dans les règles et leurs heures rémunérables confirmées par un responsable. Une absence de plusieurs jours ne devient pas automatiquement une durée travaillée continue. Pour une absence traversant un mois, la quantité confirmée est répartie proportionnellement à son intervalle ; les heures réellement travaillées en chevauchement sont déduites et signalées comme une régularisation nécessaire.

La récupération prise est distincte du travail donnant droit à récupération et n’augmente pas le total travaillé. Un montant n’est fourni que si le taux horaire est renseigné et les heures d’absence rémunérables connues. Les calculs monétaires utilisent Decimal et un arrondi final à deux décimales. Ce calcul correspond au scénario du projet, sans charges, retenues, déclarations ou transfert vers un logiciel de paie externe.

Les catégories de couleur des cartes hebdomadaires restent une estimation de présentation ; les catégories et montants du relevé financier sont ceux calculés par le serveur.

## Stockage et simulation

`npm run dev:demo` active explicitement les deux indicateurs de simulation. Les mocks restent utilisables pour cette démonstration et ne sont jamais un stockage de secours lorsque l’API échoue.

En réel, les données métier sont dans PostgreSQL. Les anciens stocks `tm-org` et les membres/plannings/paies fictifs sont ignorés. Le navigateur conserve un cache de thème/guide et le jeton CSRF dans `sessionStorage` ; les préférences du compte viennent de l’API après connexion. Les préférences vocales sont synchronisées, mais les voix disponibles dépendent de l’appareil. La lecture est déclenchée par l’utilisateur, et s’arrête à la fermeture du guide ou du lecteur.

## Vérification

```bash
npm run build
npx eslint src dev test vite.config.js
node --test test/*.test.js
```

Depuis `time_manager` avec un Elixir compatible et la base de tests :

```bash
mix precommit
```

Les tests couvrent les accès entre organisations, la rétrogradation, les validations atomiques, les propositions périmées, les appels concurrents, les publications et échanges, les frontières semaine/mois, les absences rémunérables, le CSV, le transport CSRF, les préférences, les voix et les réponses serveur malformées.

## Limites qui restent hors du plan livré

- Publication et décisions produisent des notifications dans l’application ; les envois automatiques par email/SMS et rappels programmés ne sont pas ajoutés.
- La lecture vocale dépend du support du navigateur et des voix de l’appareil.
- Le fuseau configurable au-delà d’UTC, les charges/net fiscal, les déclarations et l’intégration d’un logiciel de paie nécessitent un contrat métier supplémentaire.
- Journal et notifications sont limités aux 200/100 dernières entrées ; une pagination complète et l’archivage des anciens plans seraient utiles pour un usage à grande échelle.

## Identité, langue et récupération — 13 octobre 2026

- `utils/registration.js` valide l’âge (18 ans révolus), les noms sans chiffres et la qualité des nouveaux mots de passe. Les contrôles sont répétés par le backend ; les mots de passe de connexion existants ne sont pas filtrés par la nouvelle politique.
- `utils/apiErrors.js` nomme le champ invalide et précise comment corriger la demande ; `http.js` distingue notamment réseau, session, droits, conflit et serveur. Les erreurs toast restent visibles jusqu’à fermeture.
- `components/auth/PasswordRecovery.vue` et `services/passwordRecoveryService.js` appellent `/auth/forgot-password` puis `/auth/reset-password`. Aucun compte ni mot de passe n’est créé dans localStorage pour ce parcours. Le mode mock explique l’absence d’envoi email.
- Mon compte conserve le changement personnel du mot de passe pour employés/managers, demande le mot de passe actuel et déconnecte après succès. Le serveur invalide les autres sessions et tente l’email d’alerte.
- `utils/i18n.js`, `locales/en.json` et `LanguageSelect.vue` fournissent le français/anglais sans dépendance supplémentaire. `$t(texte, paramètres)` traduit les libellés connus ; `intlLocale()` adapte les dates/nombres. Ajouter tout nouveau libellé au catalogue anglais et utiliser `$t` dans les templates. Ne pas traduire les noms/notes saisis par les utilisateurs.
- La langue est accessible à la connexion, dans le menu et Mon compte. `tm-language` conserve le choix local avant connexion ; `PATCH /auth/preferences` le sauvegarde pour le compte réel. La lecture du guide utilise le texte traduit et la langue sélectionnée, sous réserve des voix du navigateur.
- Notifications : filtres Toutes/Lues/Non lues, pagination et compteur serveur. Le badge est actualisé à la connexion, après lecture, au retour au premier plan et toutes les 30 secondes si la page est visible.
- Administration : le manager est exclu des membres de sa propre équipe ; les boutons Retirer sont alignés dans une colonne dédiée.

Validation complète : `npm run check` lance ESLint, les tests Node et le build Vite. [Recette manuelle](RECETTE_VALIDATIONS.md).
