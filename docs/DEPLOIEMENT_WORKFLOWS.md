# Déployer les nouveaux workflows

Le code local implémente les nouvelles API et leurs écrans. La vérification du serveur `34.155.104.175:4000` le 12 octobre 2026 montre qu’il ne les expose pas encore. Le serveur qui tourne déjà doit recevoir les nouveaux fichiers/images et les migrations ; lancer uniquement un nouveau frontend ne les crée pas.

## Tester localement avant déploiement

Depuis `time_manager`, avec Elixir compatible :

```bash
mix ecto.migrate
mix phx.server
```

Garder le serveur ouvert. Si ce backend local est déjà lancé, appliquer ses migrations sans lancer un deuxième serveur. Dans `time-manager-dashboard/.env.local` :

```env
VITE_AUTH_USE_MOCK=false
VITE_USE_MOCK=false
VITE_API_URL=/api
VITE_BACKEND_URL=http://localhost:4000
```

Puis `npm run dev`. Le compte utilisé doit exister dans la base locale ; le compte distant et le compte mock sont indépendants.

## Migrations ajoutées

1. `20261012143436_add_workforce_workflows.exs` : règles, permissions, préférences, feuilles, corrections, plannings, gardes, échanges, absences, profils de paie, journal, notifications et catégorie de période.
2. `20261012145131_allow_legacy_audit_events.exs` : journal pour les comptes historiques sans organisation.
3. `20261012164950_add_absence_payable_hours.exs` : quantité d’heures rémunérables confirmée sur une absence.

4. `20261013143422_add_password_recovery_and_session_version.exs` : codes de récupération et version de session.
5. `20261013203307_remove_managers_from_own_team_memberships.exs` : retrait des appartenances redondantes des managers à leur propre équipe. Cette migration ne touche ni aux comptes, ni à leurs heures, ni à leur rôle de manager. Le rollback ne reconstitue pas ces appartenances.

Les migrations de structure sont additives ; la cinquième nettoie les appartenances indiquées. Aucune réinitialisation de base n’est requise. Ne pas utiliser `mix ecto.reset`, supprimer le volume PostgreSQL ou recréer les comptes pour ce déploiement.

## Serveur Docker existant

La personne disposant de l’accès au serveur/registre doit d’abord construire et publier les images du commit contenant le travail, par le pipeline existant ou son processus habituel. Ne pas considérer un simple `pull` comme une preuve que les nouvelles images ont été publiées.

Sur le serveur, depuis le dossier contenant `docker-compose.prod.yml` et sa configuration actuelle, sauvegarder la base avant les migrations :

```bash
docker compose -f docker-compose.prod.yml exec -T db \
  sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > gotham-before-workflows.sql
```

Conserver cette sauvegarde hors du dépôt et dans l’espace prévu pour les sauvegardes.

Après publication des nouvelles images :

```bash
docker compose -f docker-compose.prod.yml pull phoenix dashboard
docker compose -f docker-compose.prod.yml up -d --no-deps phoenix dashboard
docker compose -f docker-compose.prod.yml logs --tail=100 phoenix dashboard
```

L’entrypoint actuel de Phoenix exécute `mix ecto.migrate` avant de démarrer. Il doit utiliser le même service `db`, la même base et le même volume existant. Ne pas modifier les paramètres PostgreSQL pour ce raccordement.

Pour un lancement sans Docker, la personne qui gère le service applique `mix ecto.migrate` avec son environnement/base habituels, puis redémarre ce service et publie le nouveau build frontend.

## Vérifier la mise en ligne

Sans compte connecté, cette route doit répondre `401` lorsque le nouveau routeur est installé :

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  http://34.155.104.175:4000/api/workforce/context
```

Une `404` signifie que le nouveau routeur n’est pas encore servi. Vérifier également que `/api/openapi` contient `/plans`, `/payroll`, `/correction-requests`, `/auth/preferences` et `/weekly-sheets`.

Avec un compte réel, vérifier successivement : connexion, permissions, règles, note, correction, validation/réouverture, création/publication de gardes, consentement/validation d’un échange, absence, confirmation de ses heures rémunérables, relevé mensuel/CSV et notifications. Les essais doivent utiliser des comptes/données de recette appropriés.

Le guide de lecture vocale se teste dans un navigateur compatible, via Mon compte et « Écouter cette étape ». Il ne nécessite pas de service audio backend.

## Emails et pipeline du 13 octobre

Travis exécute maintenant une étape **Test** avant **Build & Push Image**, puis **Deploy**. Backend : format, compilation sans avertissements et tests PostgreSQL. Frontend : ESLint, tests et build. Publication et déploiement sont limités à main hors pull request et ne s’exécutent pas après un échec des tests. Les jobs utilisent `scripts/check_workflows.sh` : Docker Compose v2 est préféré, avec repli sur `docker-compose` si nécessaire. Le script supprime uniquement les ressources de la composition de test à la fin.

La composition `docker-compose.test.yml` utilise sa propre base éphémère. Les tests locaux peuvent aussi être lancés avec `mix precommit` et `npm run check`. Voir la [recette](RECETTE_VALIDATIONS.md).

Le serveur conserve Mailpit par défaut. Pour que les emails arrivent dans des boîtes réelles, configurer les variables protégées Travis (ou le fichier d’environnement privé du serveur pour un déploiement manuel) :

```env
EMAIL_DELIVERY=resend
RESEND_API_KEY=<clé privée Resend>
RESEND_FROM=Time Manager <notifications@votre-domaine>
RESEND_FROM_EMAIL=notifications@votre-domaine
```

L’expéditeur doit être autorisé chez le fournisseur. Ne pas committer ces valeurs. Le pipeline transmet ces paramètres et Compose respecte désormais EMAIL_DELIVERY au lieu d’imposer Mailpit. En recette, garder `EMAIL_DELIVERY=mailpit` et vérifier les messages dans Mailpit. La réussite des tests avec l’adaptateur de test ne garantit pas la délivrance par le fournisseur distant.

Après déploiement, vérifier dans OpenAPI `/auth/forgot-password`, `/auth/reset-password` et `/notifications/count`. Faire un essai sur un compte de recette : récupération, connexion avec le nouveau mot de passe, refus de l’ancienne session et réception de l’alerte. Aucune réinitialisation de base ni recréation des comptes existants n’est nécessaire.
