# Recette — identité, récupération, équipes et notifications

Utiliser une base de recette et des comptes de test : un administrateur, un manager et deux employés. Appliquer les migrations avant les essais. En local, Mailpit permet d’inspecter les emails sans contacter des destinataires réels. Pour les commandes de lancement et de migration : [déploiement](DEPLOIEMENT_WORKFLOWS.md). Pour suivre le code : [backend](BACKEND.md) et [frontend](FRONTEND.md).

| Fonction | Manipulation | Résultat attendu |
|---|---|---|
| Âge | Rejoindre Gotham avec une naissance demain moins 18 ans, puis aujourd’hui moins 18 ans. | Premier refus explicite ; deuxième demande admise. Vérifier aussi une date impossible et future. |
| Noms | Saisir `Jean2`, puis `Éléonore` / `D’Angelo-Santos`. Répéter dans Mon compte. | Les chiffres sont refusés ; les lettres accentuées et noms composés sont acceptés. |
| Mot de passe | À l’acceptation d’une demande puis dans Mon compte, essayer `123456789`, `Password2026!`, `abcdabcd` ; choisir ensuite une phrase personnelle inédite. | Les trois valeurs simples sont refusées avec une explication. La phrase valide permet l’action. |
| Changement personnel | Se connecter au même compte dans deux navigateurs. Modifier le mot de passe dans Mon compte. | Mot de passe actuel exigé ; déconnexion après succès ; ancienne session refusée dans l’autre navigateur ; email d’alerte sans mot de passe. |
| Mot de passe oublié | Déconnecté, demander un code pour un compte vérifié de recette. Ouvrir Mailpit, saisir les 8 chiffres et un nouveau mot de passe confirmé. | Réponse générique, code reçu, succès puis connexion avec le nouveau mot de passe. Ancien mot de passe refusé. |
| Code incorrect/ancien | Tester cinq erreurs, réutiliser un code consommé, demander deux codes successifs. | Code bloqué après cinq erreurs ; code consommé et premier des deux codes refusés. Le dernier code reste utilisable jusqu’à son expiration. |
| Compte absent | Demander un code pour une adresse absente. | Même message générique ; aucun compte créé et aucun code livré. |
| Manager/membre | Dans Équipes, choisir un manager. Chercher ce manager dans Ajouter un membre. Puis promouvoir un membre au poste de manager. | Le manager n’est pas proposé. La promotion retire l’appartenance redondante tout en conservant son compte et ses heures. |
| Alignement | Afficher une équipe avec des noms courts/longs à 390 px et sur ordinateur. | Retirer reste dans la même colonne, sans débordement horizontal. |
| Correction | Employé : proposer une correction. Manager autorisé : accepter/refuser avec motif. | Notification personnelle claire, sans « demande est approved » ; acceptation met à jour les heures, refus les conserve. |
| Notifications | Tester Toutes / Non lues / Lues ; marquer une notification lue puis actualiser. | Filtres persistants côté serveur, badge décrémenté, lecture conservée après reconnexion. Plusieurs pages si plus de 50 résultats. |
| Confidentialité | Depuis un autre compte, tenter de marquer la notification du premier compte comme lue. | `403`, aucun changement du compteur du destinataire. |
| Français/anglais | Changer la langue à la connexion, puis dans Mon compte ou le menu ; parcourir les écrans et le guide. | Libellés et dates traduits, données personnelles inchangées ; préférence restaurée après reconnexion. |
| Mobile | Répéter connexion, adhésion, récupération et changement personnel à 390 px. | Formulaires lisibles, commandes accessibles et aucun défilement horizontal. |
| Erreurs | Arrêter le backend de recette, puis provoquer un mauvais mot de passe et une validation de champ. | Message réseau actionnable, cause de connexion claire, champ invalide nommé ; aucune trace SQL affichée. |
| Pipeline | Ouvrir une PR ou pousser une branche ; consulter Travis. | Tests backend, tests frontend, lint et build. Publication/déploiement uniquement sur main hors PR, après succès de l’étape Test. |

## Vérification automatique locale

```bash
cd time_manager
mix precommit
cd ../time-manager-dashboard
npm ci
npm run check
```

Comme dans Travis, avec Docker et Docker Compose, depuis la racine :

```bash
bash scripts/check_workflows.sh backend
bash scripts/check_workflows.sh frontend
```

Ces commandes ciblent la composition de test isolée. Le script choisit Compose v2 ou le binaire docker-compose et nettoie automatiquement les ressources de test. Les tests d’email utilisent l’adaptateur de test et n’expédient pas de messages externes.
