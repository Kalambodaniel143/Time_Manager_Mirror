# Code partagé

- `@shared/components/ui/AppIcon.vue` : passerelle vers l'icône web existante.
- `@shared/services/apiClient.js` : client HTTP générique, sans gestion de session.
- `utils/` : emplacement des prochaines fonctions communes.

L'icône nécessite le dépôt complet. Aucun composant web n'est déplacé ou dupliqué.
Le client générique est restauré directement ici : l'ancien fichier
`time-manager-dashboard/src/services/apiClient.js` n'existe plus dans ce dépôt.

Le client HTTP actuel du web contient sa propre intégration de cookies et CSRF :
elle reste intacte. Jonas devra adapter la session mobile au contrat actuel.
Une extraction physique des composants devra aussi adapter les contextes Docker.
