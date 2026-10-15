# Architecture et flux

Cette page raconte les principaux trajets dans l'application. Les schémas sont construits à partir du routeur Phoenix, des contrôleurs, des contextes, des services Vue et des fichiers Docker du dépôt.

Dans un diagramme de séquence, lisez de haut en bas : chaque flèche est un message envoyé au composant suivant. Dans un diagramme d'architecture, suivez les flèches depuis l'utilisateur jusqu'à PostgreSQL.

## Vue logique

```mermaid
flowchart TB
    subgraph Client[Client navigateur]
      UI[Composants et vues Vue]
      Router[Vue Router]
      Store[Store de session réactif]
      Services[Services API]
    end

    subgraph Web[Entrée web]
      Nginx[Nginx]
      Vite[Proxy Vite en développement]
    end

    subgraph API[Backend Phoenix]
      Endpoint[Endpoint et plugs]
      PRouter[Router]
      Controllers[Contrôleurs]
      Contexts[Contextes métier]
      Repo[Ecto Repo]
    end

    DB[(PostgreSQL)]
    Mail[Mailpit ou Resend]

    UI --> Router
    UI --> Services
    Router --> Store
    Services --> Nginx
    Services -. développement .-> Vite
    Nginx --> Endpoint
    Vite --> Endpoint
    Endpoint --> PRouter --> Controllers --> Contexts --> Repo --> DB
    Contexts --> Mail
```

Le frontend aide l'utilisateur, mais Phoenix reste l'autorité. Les gardes Vue masquent les pages inadaptées ; chaque endpoint répète les contrôles avec l'utilisateur relu en base.

## Cycle d'une requête API protégée

Ce premier parcours sert de modèle pour presque toutes les actions connectées. Le navigateur présente la session, Phoenix retrouve l'utilisateur actuel, le contrôleur vérifie le droit demandé et le contexte effectue l'opération.

```mermaid
sequenceDiagram
    actor U as Utilisateur
    participant V as Vue
    participant H as services/http.js
    participant N as Nginx ou Vite
    participant E as Phoenix Endpoint
    participant A as Authenticate
    participant C as Contrôleur
    participant M as Contexte métier
    participant D as PostgreSQL

    U->>V: Déclenche une action
    V->>H: Données de formulaire
    H->>N: Requête /api avec cookie et X-CSRF-Token
    N->>E: Transmission vers Phoenix
    E->>E: Proxy, en-têtes, débit et taille
    E->>A: Route protégée
    A->>A: JWT, CSRF, révocation et session_version
    A->>D: Relire utilisateur et rôle
    D-->>A: Utilisateur actuel
    A->>C: current_user vérifié
    C->>C: Autorisation et paramètres
    C->>M: Commande métier
    M->>D: Transaction Ecto
    D-->>M: Résultat
    M-->>C: ok ou erreur
    C-->>H: JSON et statut HTTP
    H-->>V: data ou ApiError
    V-->>U: Écran actualisé ou message
```

## Connexion et restauration de session

La connexion crée la session. La restauration permet à un nouvel onglet de retrouver cette session sans redemander le mot de passe, tout en recréant la preuve CSRF liée au même JWT.

```mermaid
sequenceDiagram
    actor U as Utilisateur
    participant V as Vue
    participant P as Phoenix
    participant DB as PostgreSQL

    U->>V: Email et mot de passe
    V->>P: POST /api/auth/login
    P->>DB: Chercher le compte
    DB-->>P: Hash et état du compte
    P->>P: Vérifier Argon2id ou bcrypt historique
    P->>P: Générer CSRF et JWT signé
    P-->>V: Set-Cookie jwt HttpOnly et csrf_token JSON
    V->>V: CSRF dans sessionStorage

    Note over V,P: Nouvel onglet
    V->>P: GET /api/auth/session + X-Session-Restore: 1
    P->>P: Vérifier JWT, origine de navigation et compte
    P-->>V: Session et CSRF lié au même JWT
```

Le JWT dure huit heures. La déconnexion révoque son `jti`. Un changement ou une réinitialisation du mot de passe incrémente `session_version`, ce qui invalide les anciennes sessions.

## Gestion d'un utilisateur et changement de rôle

Le rôle enregistré dans le JWT ne suffit pas à accorder un droit. `Authenticate` relit le compte en base à chaque requête. Une rétrogradation est donc visible dès l'appel suivant.

```mermaid
sequenceDiagram
    actor A as Administrateur
    participant V as Vue
    participant C as UserController
    participant Z as Authorization
    participant AC as Accounts
    participant DB as PostgreSQL

    A->>V: Choisit employee ou manager
    V->>C: PUT /api/users/:id/role
    C->>Z: can_change_role utilisateur courant et cible
    Z-->>C: Autorisé seulement dans la même organisation et jamais sur soi
    C->>AC: change_role
    AC->>DB: Mettre à jour role_id
    DB-->>AC: Utilisateur modifié
    AC-->>C: ok
    C-->>V: 200 et utilisateur

    Note over C,DB: À la requête suivante, Authenticate relit le rôle en base.
```

Une rétrogradation prend donc effet sans attendre l'expiration du JWT. Pour les équipes, `TeamController` exige également que l'appelant possède encore le rôle actif `manager`.

## Voyage d'un pointage

Ce scénario part du clic dans `ClockManager.vue` et va jusqu'à l'écriture en base. Le verrou posé sur l'utilisateur évite que deux clics très proches créent deux transitions incohérentes.

```mermaid
sequenceDiagram
    actor U as Employé
    participant CM as ClockManager.vue
    participant CS as clockService.js
    participant CC as ClockController
    participant AU as Authorization
    participant CL as Clocks
    participant DB as PostgreSQL

    U->>CM: Cliquer arrivée, pause, reprise ou départ
    CM->>CS: createClock userId et attributs
    CS->>CC: POST /api/clocks/:userID
    CC->>AU: can_clock utilisateur courant et userID
    AU-->>CC: Soi uniquement
    CC->>CL: create_clock utilisateur vérifié
    CL->>DB: BEGIN et verrou FOR UPDATE sur utilisateur
    CL->>DB: Lire le dernier pointage
    CL->>CL: Valider heure, transition et semaine mutable
    CL->>DB: Insérer clock
    alt Pause ou départ après un segment ouvert
      CL->>DB: Insérer workingtime
    end
    DB-->>CL: COMMIT
    CL-->>CC: Pointage enregistré
    CC-->>CS: 201 data Clock
    CS-->>CM: Succès
    CM->>CS: Relire l'historique paginé
    CS-->>CM: État serveur actuel
    CM-->>U: Affichage actualisé
```

Transitions autorisées :

```mermaid
stateDiagram-v2
    [*] --> HorsService
    HorsService --> EnService: arrival
    EnService --> EnPause: pause
    EnService --> HorsService: departure
    EnPause --> EnService: resume
    EnPause --> HorsService: departure
```

Le verrou utilisateur sérialise deux clics concurrents. Le second relit l'état créé par le premier et une transition identique est refusée.

## Demande d'absence

```mermaid
sequenceDiagram
    actor E as Employé
    actor R as Responsable autorisé
    participant API as Phoenix
    participant W as Workforce.Absences
    participant DB as PostgreSQL

    E->>API: POST /api/absence-requests
    API->>W: create avec current_user
    W->>DB: Vérifier chevauchements et insérer pending
    DB-->>API: Demande créée
    API-->>E: 200 data Absence

    R->>API: PATCH /api/absence-requests/:id
    API->>W: review approved ou rejected
    W->>W: Vérifier rôle, permission, autre salarié et état
    W->>DB: Transaction, décision, audit et notifications
    DB-->>API: Demande mise à jour
    API-->>R: 200 data Absence
```

## Conteneurs du serveur HTTP

```mermaid
flowchart LR
    Client local ou réseau isolé -->|HTTP| N[Nginx dashboard]
    N -->|proxy interne| P[Phoenix]
    P -->|réseau database interne| DB[(PostgreSQL)]
    P -->|réseau outbound| R[Resend]

    subgraph Hôte Docker
      N
      P
      DB
    end
```

- `db` n'a aucun port publié ;
- `phoenix` n'a aucun port publié ;
- `dashboard` est le seul point d'entrée ;
- Mailpit n'existe pas dans la composition de production ;
- aucun certificat ni port chiffré n'est configuré.

## Invariants d'architecture

1. Le navigateur ne décide jamais d'une autorisation.
2. Les identifiants d'URL sont comparés à l'utilisateur authentifié et au périmètre courant.
3. Les propriétaires (`user_id`, organisation) sont fixés côté serveur pour les écritures sensibles.
4. Les mutations liées sont regroupées en transaction.
5. Les mocks sont explicitement limités au développement et refusés au build.
6. Les secrets sont lus au démarrage, jamais intégrés au bundle Vue.

## Points à confirmer hors dépôt

- topologie réseau réelle du serveur et règles de pare-feu ;
- solution de transport chiffré à ajouter avant toute exposition publique ;
- nombre réel d'instances Phoenix ;
- supervision, collecte des logs et alertes ;
- application mobile consommant éventuellement cette API.
