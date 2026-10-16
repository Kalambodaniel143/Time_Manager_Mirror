# Time Manager

Application Vue 3 et Phoenix/Elixir de gestion des pointages, temps de travail, équipes, plannings, absences et validations.

## Démarrage local

```bash
cp .env.example .env
# Renseigner JWT_SECRET avec une clé locale privée d'au moins 32 octets.
docker compose up -d --build
```

- Interface : `http://127.0.0.1:8080`
- API : `http://127.0.0.1:4000`
- Mailpit : `http://127.0.0.1:8025`

## Documentation

La documentation technique complète est dans [`docs/`](docs/index.md) et se construit avec Material for MkDocs :

```bash
python -m pip install mkdocs-material==9.7.7
mkdocs serve
```

Commencer par le [guide d'installation](docs/INSTALLATION.md), puis consulter l'[architecture](docs/ARCHITECTURE.md), le [backend et ses endpoints](docs/BACKEND.md), le [frontend](docs/FRONTEND.md), la [sécurité](docs/SECURITE.md) et l'[exploitation](docs/DEVOPS.md).

> **Attention :** la composition serveur actuelle utilise HTTP. Elle convient au développement et à un réseau isolé, pas à une exposition publique.

## Vérifications

```bash
bash scripts/check_workflows.sh backend
bash scripts/check_workflows.sh frontend
mkdocs build --strict
```

Le déploiement public n'est pas déclenché par ces commandes.
