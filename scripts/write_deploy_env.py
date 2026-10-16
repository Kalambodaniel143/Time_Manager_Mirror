#!/usr/bin/env python3
"""Prépare un .env privé à partir des variables CI, sans en afficher les valeurs."""
import os
from pathlib import Path
import re
import sys

REQUIRED = (
    "DOCKER_USERNAME", "IMAGE_TAG", "PGUSER", "PGPASSWORD", "PGDATABASE",
    "DATABASE_URL", "JWT_SECRET", "SECRET_KEY_BASE", "PHX_HOST",
    "RESEND_API_KEY", "RESEND_FROM",
)


def write_environment(destination):
    values = {key: os.environ.get(key, "") for key in REQUIRED}
    for key, value in values.items():
        if not value.strip() or "\n" in value or "\r" in value:
            raise ValueError(f"{key} requise, sur une seule ligne")
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", values["DOCKER_USERNAME"]):
        raise ValueError("DOCKER_USERNAME invalide")
    if not re.fullmatch(r"[0-9a-f]{40}", values["IMAGE_TAG"]):
        raise ValueError("IMAGE_TAG doit être le SHA du commit validé")
    for key in ("PUBLIC_PORT", "ADMIN_EMAIL", "ADMIN_PASSWORD"):
        value = os.environ.get(key, "")
        if "\n" in value or "\r" in value:
            raise ValueError(f"{key} doit tenir sur une seule ligne")
        if value:
            values[key] = value
    path = Path(destination)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.chmod(path, 0o600)
    with os.fdopen(fd, "w") as output:
        for key, value in values.items():
            escaped = value.replace("\\", "\\\\").replace("'", "\\'")
            output.write(f"{key}='{escaped}'\n")


if __name__ == "__main__":
    try:
        write_environment(sys.argv[1])
    except (ValueError, IndexError) as error:
        sys.exit(str(error))
