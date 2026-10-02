#!/usr/bin/env bash
# Test manuel des endpoints CRUD /api/users contre un serveur mix phx.server
# qui tourne déjà en local. Usage : ./test_users_api.sh [base_url]

set -uo pipefail

BASE_URL="${1:-http://localhost:4000/api/users}"
BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT

PASS=0
FAIL=0
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Envoie une requête et retourne le status HTTP ; le corps atterrit dans $BODY_FILE.
request() {
  local method="$1" url="$2" data="${3:-}"
  if [ -n "$data" ]; then
    curl -s -o "$BODY_FILE" -w "%{http_code}" -X "$method" "$url" \
      -H "Content-Type: application/json" -d "$data"
  else
    curl -s -o "$BODY_FILE" -w "%{http_code}" -X "$method" "$url"
  fi
}

# Compare le status obtenu au status attendu et affiche PASS/FAIL.
check_status() {
  local description="$1" expected="$2" actual="$3"
  local body
  body="$(cat "$BODY_FILE")"

  if [ "$actual" = "$expected" ]; then
    echo -e "${GREEN}PASS${NC} - $description (status $actual)"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC} - $description (attendu $expected, obtenu $actual)"
    echo "       body: ${body:0:300}"
    FAIL=$((FAIL + 1))
  fi
}

echo "== Tests API /api/users =="
echo "Base URL: $BASE_URL"
echo

if ! curl -s -o /dev/null --max-time 3 "$BASE_URL"; then
  echo -e "${RED}Impossible de joindre $BASE_URL${NC} — lance 'mix phx.server' d'abord."
  exit 1
fi
echo

# --- GET /api/users (liste) ---
status=$(request GET "$BASE_URL")
check_status "GET /api/users (liste)" "200" "$status"

# --- POST /api/users (création valide) ---
timestamp=$(date +%s)
email="test${timestamp}@example.com"
username="test_user_${timestamp}"
payload=$(jq -n --arg u "$username" --arg e "$email" '{user: {username: $u, email: $e}}')

status=$(request POST "$BASE_URL" "$payload")
check_status "POST /api/users (données valides)" "201" "$status"
user_id=$(jq -r '.data.id // empty' "$BODY_FILE")
echo "       -> id créé: ${user_id:-<aucun>}"

# --- POST /api/users (données invalides) ---
status=$(request POST "$BASE_URL" '{"user": {"username": "", "email": ""}}')
check_status "POST /api/users (données invalides)" "422" "$status"

if [ -n "$user_id" ]; then
  # --- GET /api/users/:id (existant) ---
  status=$(request GET "$BASE_URL/$user_id")
  check_status "GET /api/users/:id (existant)" "200" "$status"

  # --- GET /api/users?email=...&username=... (filtre) ---
  status=$(request GET "$BASE_URL?email=$email&username=$username")
  count=$(jq '.data | length' "$BODY_FILE" 2>/dev/null || echo "?")
  if [ "$status" = "200" ] && [ "$count" = "1" ]; then
    echo -e "${GREEN}PASS${NC} - GET /api/users?email=&username= (filtre, 1 résultat)"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC} - GET /api/users?email=&username= (status=$status, count=$count)"
    FAIL=$((FAIL + 1))
  fi

  # --- PUT /api/users/:id (valide) ---
  update_payload=$(jq -n --arg u "updated_${timestamp}" '{user: {username: $u}}')
  status=$(request PUT "$BASE_URL/$user_id" "$update_payload")
  check_status "PUT /api/users/:id (données valides)" "200" "$status"

  # --- DELETE /api/users/:id (existant) ---
  status=$(request DELETE "$BASE_URL/$user_id")
  check_status "DELETE /api/users/:id (existant)" "204" "$status"

  # --- DELETE /api/users/:id (déjà supprimé -> inexistant) ---
  status=$(request DELETE "$BASE_URL/$user_id")
  check_status "DELETE /api/users/:id (déjà supprimé)" "404" "$status"
else
  echo -e "${RED}Impossible de récupérer l'id créé, tests suivants ignorés.${NC}"
  FAIL=$((FAIL + 1))
fi

# --- GET /api/users/:id (id inexistant) ---
status=$(request GET "$BASE_URL/999999999")
check_status "GET /api/users/:id (id inexistant)" "404" "$status"

# --- PUT /api/users/:id (id inexistant) ---
status=$(request PUT "$BASE_URL/999999999" '{"user": {"username": "x"}}')
check_status "PUT /api/users/:id (id inexistant)" "404" "$status"

echo
echo "== Résumé: $PASS réussis, $FAIL échoués =="
[ "$FAIL" -eq 0 ]
