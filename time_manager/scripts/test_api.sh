#!/usr/bin/env bash
#
# Smoke-test script for the USER and WORKING TIME endpoints required by the subject.
# Usage: ./scripts/test_api.sh [base_url]
#   base_url defaults to http://localhost:4000

set -uo pipefail

BASE="${1:-http://localhost:4000}/api"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

# check(label, expected_status, actual_status, body)
check() {
  local label="$1" expected="$2" actual="$3" body="$4"

  if [ "$actual" = "$expected" ]; then
    echo -e "${GREEN}PASS${NC} [$actual] $label"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "${RED}FAIL${NC} [attendu $expected, reçu $actual] $label"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo "$body" | jq . 2>/dev/null || echo "$body"
  echo
}

# request(method, url, [json_body]) -> sets $STATUS and $BODY
request() {
  local method="$1" url="$2" data="${3:-}"
  local response

  if [ -n "$data" ]; then
    response=$(curl -s -o /tmp/api_test_body.$$ -w "%{http_code}" -X "$method" "$url" \
      -H "Content-Type: application/json" -d "$data")
  else
    response=$(curl -s -o /tmp/api_test_body.$$ -w "%{http_code}" -X "$method" "$url")
  fi

  STATUS="$response"
  BODY=$(cat /tmp/api_test_body.$$ 2>/dev/null)
  rm -f /tmp/api_test_body.$$
}

echo "=== Vérification du serveur ($BASE) ==="
if ! curl -s -o /dev/null --max-time 3 "$BASE/users"; then
  echo -e "${RED}Le serveur ne répond pas sur $BASE. Lance 'mix phx.server' d'abord.${NC}"
  exit 1
fi
echo "OK"
echo

########################################
# USER
########################################

echo "########## USER ##########"
echo

echo "--- POST /api/users (créer) ---"
request POST "$BASE/users" '{"user": {"username": "alice", "email": "alice@example.com"}}'
check "create user" "201" "$STATUS" "$BODY"
USER_ID=$(echo "$BODY" | jq -r '.data.id // empty')

if [ -z "$USER_ID" ]; then
  echo -e "${RED}Impossible de créer l'utilisateur de test, arrêt du script.${NC}"
  exit 1
fi

echo "--- GET /api/users?email=XXX&username=YYY (liste + filtres) ---"
request GET "$BASE/users?email=alice@example.com&username=alice"
check "list users (filtered)" "200" "$STATUS" "$BODY"

echo "--- GET /api/users/:userID ---"
request GET "$BASE/users/$USER_ID"
check "show user" "200" "$STATUS" "$BODY"

echo "--- PUT /api/users/:userID ---"
request PUT "$BASE/users/$USER_ID" '{"user": {"username": "alice-updated", "email": "alice.updated@example.com"}}'
check "update user" "200" "$STATUS" "$BODY"

echo "--- GET /api/users/999999 (id inexistant) ---"
request GET "$BASE/users/999999"
check "show missing user" "404" "$STATUS" "$BODY"

########################################
# WORKING TIME
########################################

echo "########## WORKING TIME ##########"
echo

echo "--- POST /api/workingtime/:userID (créer) ---"
request POST "$BASE/workingtime/$USER_ID" \
  '{"workingtime": {"start": "2026-09-22 08:00:00", "end": "2026-09-22 17:00:00"}}'
check "create working time" "201" "$STATUS" "$BODY"
WT_ID=$(echo "$BODY" | jq -r '.data.id // empty')

if [ -z "$WT_ID" ]; then
  echo -e "${RED}Impossible de créer le working time de test, arrêt du script.${NC}"
  exit 1
fi

echo "--- GET /api/workingtime/:userID?start=XXX&end=YYY (liste + filtres) ---"
request GET "$BASE/workingtime/$USER_ID?start=2026-09-01%2000:00:00&end=2026-09-30%2023:59:59"
check "list working times (filtered)" "200" "$STATUS" "$BODY"

echo "--- GET /api/workingtime/:userID/:id ---"
request GET "$BASE/workingtime/$USER_ID/$WT_ID"
check "show working time" "200" "$STATUS" "$BODY"

echo "--- PUT /api/workingtime/:id ---"
request PUT "$BASE/workingtime/$WT_ID" \
  '{"workingtime": {"start": "2026-09-22 09:00:00", "end": "2026-09-22 18:00:00"}}'
check "update working time" "200" "$STATUS" "$BODY"

echo "--- DELETE /api/workingtime/:id ---"
request DELETE "$BASE/workingtime/$WT_ID"
check "delete working time" "204" "$STATUS" "$BODY"

########################################
# Cleanup
########################################

echo "########## Nettoyage ##########"
echo

echo "--- DELETE /api/users/:userID ---"
request DELETE "$BASE/users/$USER_ID"
check "delete user" "204" "$STATUS" "$BODY"

########################################
# Résumé
########################################

echo "=== Résumé : $PASS_COUNT réussi(s), $FAIL_COUNT échoué(s) ==="
[ "$FAIL_COUNT" -eq 0 ]
