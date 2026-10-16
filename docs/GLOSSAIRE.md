# Glossaire

Ce glossaire traduit les mots techniques employés dans le projet. Il peut se lire à la demande : lorsque vous rencontrez un terme inconnu dans une autre page, revenez chercher sa définition ici.

| Terme | Définition dans Time Manager |
|---|---|
| API | Porte d'entrée HTTP utilisée par Vue et d'éventuels autres clients pour demander une opération à Phoenix. |
| Argon2id | Algorithme utilisé pour hacher les nouveaux mots de passe avant stockage. Un hash ne permet pas de relire le mot de passe original. |
| Bcrypt | Ancien format de hash encore accepté à la connexion puis remplacé par Argon2id. |
| Bandit | Serveur HTTP qui fait fonctionner l'endpoint Phoenix. |
| Build | Transformation du code source en application exécutable ou en fichiers frontend statiques. |
| Changeset | Objet Ecto qui sélectionne, transforme et valide les modifications avant une écriture en base. |
| CI | Intégration continue : vérifications automatiques du code. Travis construit les images et exécute les tests frontend présents dans son stage Test. |
| CD | Livraison ou déploiement continu. Ici, la publication et le déploiement sont conditionnels ; le déploiement exige une approbation explicite. |
| Contexte Phoenix | Module qui regroupe les règles d'un domaine, par exemple `Accounts`, `Clocks` ou `WorkingTimes`. |
| Cookie | Petite donnée gérée par le navigateur. Le cookie `jwt` porte la session signée. |
| CORS | Mécanisme du navigateur contrôlant les appels entre origines différentes. Le déploiement prévu sert frontend et API sur la même origine. |
| CSRF | Attaque où un autre site pousse le navigateur à envoyer une action avec ses cookies. Time Manager exige un jeton `X-CSRF-Token` lié au JWT et contrôle l'origine. |
| CSP | Politique envoyée par Nginx pour limiter les sources de scripts, styles, images et connexions autorisées. |
| Docker | Format et moteur de conteneurs utilisés pour construire et exécuter l'application. |
| Docker Compose | Description des services, réseaux, volumes et variables nécessaires pour lancer plusieurs conteneurs ensemble. |
| Ecto | Couche Elixir utilisée pour les schémas, validations, requêtes, transactions et migrations PostgreSQL. |
| Endpoint Phoenix | Chaîne d'entrée de toutes les requêtes : proxy de confiance, en-têtes, limites, parseur, session et routeur. |
| ERD | Diagramme montrant les tables et leurs relations. |
| ETS | Stockage en mémoire d'Erlang. Le limiteur de débit y conserve ses compteurs ; ils disparaissent au redémarrage. |
| Guard frontend | Contrôle de navigation Vue qui masque ou redirige une page. Il ne remplace jamais l'autorisation backend. |
| Healthcheck | Commande régulière qui indique à Docker ou à un orchestrateur si un service fonctionne réellement. Il manque dans la composition de production actuelle. |
| HttpOnly | Attribut empêchant JavaScript de lire un cookie. Il limite le vol du JWT par un script injecté. |
| IDOR | Accès à l'objet d'une autre personne en modifiant un identifiant dans une URL. Les contrôleurs comparent les identifiants au périmètre courant. |
| JWT | Jeton signé contenant l'identifiant, la version de session, le CSRF et les dates de validité. Il est signé, pas chiffré. |
| Migration | Fichier versionné qui fait évoluer le schéma PostgreSQL sans recréer toute la base. |
| Mock | Simulation locale du backend ou des données. Le build de production refuse les variables qui l'activent. |
| Nginx | Serveur web qui sert le build Vue en HTTP et transmet `/api` vers Phoenix. |
| OTP | Ensemble de principes et bibliothèques Erlang pour superviser des processus fiables. `TimeManager.Application` démarre les services sous un superviseur `one_for_one`. |
| Pagination par curseur | Lecture par pages en utilisant le dernier identifiant reçu au lieu d'un décalage coûteux. |
| Phoenix | Framework web Elixir du backend. |
| Plug | Étape traversée par une requête Phoenix, par exemple l'authentification, la limite de taille ou le contrôle d'origine. |
| PostgreSQL | Base relationnelle persistante de Time Manager. |
| Proxy inverse | Serveur placé devant une application. Nginx reçoit les appels du dashboard puis transmet `/api` à Phoenix. |
| Rate limiting | Limitation du nombre de requêtes pendant une période afin de ralentir les abus et certaines attaques DoS. |
| Repo | `TimeManager.Repo`, point d'accès Ecto à PostgreSQL. |
| Révocation | Invalidation serveur d'une session avant l'expiration naturelle du JWT. |
| Rollback | Retour à une version applicative ou à un état de base précédent. Le dépôt permet de choisir un ancien tag d'image, mais n'automatise pas le rollback. |
| SameSite=Strict | Attribut empêchant normalement le navigateur d'envoyer le cookie lors d'une navigation provenant d'un autre site. |
| Secret | Valeur privée utilisée pour signer ou authentifier. Les modèles utilisent des placeholders et les valeurs réelles doivent rester hors Git. |
| Session version | Entier stocké sur l'utilisateur et dans le JWT. Son changement invalide toutes les sessions plus anciennes. |
| Transaction | Groupe d'opérations PostgreSQL validées ensemble ou toutes annulées en cas d'erreur. |
| Transport chiffré | Protection du trafic entre le client et le serveur. Elle n'est pas fournie par la configuration actuelle du dépôt. |
| Vue Router | Bibliothèque qui associe les URL du navigateur aux composants Vue. |
| Vite | Outil de développement et de construction du frontend. En développement, il transmet `/api` au backend configuré. |
| XSS | Injection d'un script dans une page. Vue échappe les interpolations par défaut ; CSP et le cookie HttpOnly ajoutent des barrières. Toute utilisation future de `v-html` doit être revue. |
