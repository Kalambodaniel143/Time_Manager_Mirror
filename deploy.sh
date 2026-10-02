#!/usr/bin/env bash
# Executed on the deploy server by Travis (see .travis.yml, "Deploy" stage).
# Expects ~/docker-compose.yml and ~/.env to have been copied beforehand.
set -e

cd ~

# Install Docker (with the compose plugin) if it is missing
if ! command -v docker >/dev/null 2>&1; then
  if ! command -v curl >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y curl
  fi
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
fi

sudo docker compose pull
sudo docker compose up -d
