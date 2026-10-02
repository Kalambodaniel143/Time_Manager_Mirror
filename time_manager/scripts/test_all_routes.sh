#!/usr/bin/env bash
#
# Teste les 12 routes de l'API (users, clocks, workingtime) avec plusieurs
# scénarios par route : cas valides, cas invalides (422/400), et cas
# introuvables (404).
#
# Usage : ./scripts/test_all_routes.sh [base_url]
#   base_url par défaut : http://localhost:4000
#
# Prérequis : le serveur doit tourner (`mix phx.server`), `curl` et `jq`
# doivent être installés.
#
# Note : la table `clocks` a une contrainte FK en ON DELETE NOTHING (contrairement
# à `workingtime` en ON DELETE CASCADE) et il n'existe pas de route DELETE pour un
# clock. L'utilisateur créé pour les tests "clocks" n'est donc PAS supprimé en fin
# de script (ça ferait planter DELETE /api/users/:id avec une violation de
# contrainte). Utilise `mix ecto.reset` si tu veux repartir d'une base propre.

set -uo pipefail

BASE="${1:-http://localhost:4000}/api"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

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

# request(method, url, [json_body]) -> renseigne $STATUS et $BODY
request() {
  local method="$1" url="$2" data="${3:-}"
  local response

  if [ -n "$data" ]; then
    response=$(curl -s -o /tmp/route_test_body.$$ -w "%{http_code}" -X "$method" "$url" \
      -H "Content-Type: application/json" -d "$data")
  else
    response=$(curl -s -o /tmp/route_test_body.$$ -w "%{http_code}" -X "$method" "$url")
  fi

  STATUS="$response"
  BODY=$(cat /tmp/route_test_body.$$ 2>/dev/null)
  rm -f /tmp/route_test_body.$$
}

echo "=== Vérification du serveur ($BASE) ==="
if ! curl -s -o /dev/null --max-time 3 "$BASE/users"; then
  echo -e "${RED}Le serveur ne répond pas sur $BASE. Lance 'mix phx.server' d'abord.${NC}"
  exit 1
fi
echo "OK"
echo

################################################################################
# USERS — 5 routes : GET /users, POST /users, GET/:id, PUT/:id, DELETE/:id
################################################################################

echo -e "${YELLOW}########## USERS ##########${NC}"
echo

echo "--- POST /api/users (création valide) ---"
request POST "$BASE/users" '{"user": {"username": "alice", "email": "alice@example.com"}}'
check "create user (valide)" "201" "$STATUS" "$BODY"
USER_ID=$(echo "$BODY" | jq -r '.data.id // empty')
[ -z "$USER_ID" ] && { echo -e "${RED}Impossible de créer l'utilisateur de test, arrêt.${NC}"; exit 1; }

echo "--- POST /api/users (données invalides : champs vides) ---"
request POST "$BASE/users" '{"user": {"username": "", "email": ""}}'
check "create user (invalide -> 422)" "422" "$STATUS" "$BODY"

echo "--- GET /api/users (liste, sans filtre) ---"
request GET "$BASE/users"
check "list users (sans filtre)" "200" "$STATUS" "$BODY"

echo "--- GET /api/users?email=XXX&username=YYY (liste filtrée) ---"
request GET "$BASE/users?email=alice@example.com&username=alice"
check "list users (filtré)" "200" "$STATUS" "$BODY"

echo "--- GET /api/users/:id (existant) ---"
request GET "$BASE/users/$USER_ID"
check "show user (existant)" "200" "$STATUS" "$BODY"

echo "--- GET /api/users/999999999 (id inexistant) ---"
request GET "$BASE/users/999999999"
check "show user (id inexistant -> 404)" "404" "$STATUS" "$BODY"

echo "--- GET /api/users/abc (id non numérique) ---"
request GET "$BASE/users/abc"
check "show user (id non numérique -> 404)" "404" "$STATUS" "$BODY"

echo "--- PUT /api/users/:id (données valides) ---"
request PUT "$BASE/users/$USER_ID" '{"user": {"username": "alice-updated", "email": "alice.updated@example.com"}}'
check "update user (valide)" "200" "$STATUS" "$BODY"

echo "--- PUT /api/users/:id (données invalides) ---"
request PUT "$BASE/users/$USER_ID" '{"user": {"username": null, "email": null}}'
check "update user (invalide -> 422)" "422" "$STATUS" "$BODY"

echo "--- PUT /api/users/999999999 (id inexistant) ---"
request PUT "$BASE/users/999999999" '{"user": {"username": "x"}}'
check "update user (id inexistant -> 404)" "404" "$STATUS" "$BODY"

echo "--- DELETE /api/users/:id (existant) ---"
request DELETE "$BASE/users/$USER_ID"
check "delete user (existant -> 204)" "204" "$STATUS" "$BODY"

echo "--- DELETE /api/users/:id (déjà supprimé) ---"
request DELETE "$BASE/users/$USER_ID"
check "delete user (déjà supprimé -> 404)" "404" "$STATUS" "$BODY"

################################################################################
# CLOCKS — 2 routes : GET /clocks/:userID, POST /clocks/:userID
################################################################################

echo -e "${YELLOW}########## CLOCKS ##########${NC}"
echo

echo "--- POST /api/users (utilisateur dédié aux tests clocks) ---"
request POST "$BASE/users" '{"user": {"username": "bob-clock", "email": "bob-clock@example.com"}}'
check "create user (pour clocks)" "201" "$STATUS" "$BODY"
USER2_ID=$(echo "$BODY" | jq -r '.data.id // empty')
[ -z "$USER2_ID" ] && { echo -e "${RED}Impossible de créer l'utilisateur clocks, arrêt.${NC}"; exit 1; }

echo "--- POST /api/clocks/:userID (arrivée valide) ---"
request POST "$BASE/clocks/$USER2_ID" '{"clock": {"time": "2026-09-23T08:00:00Z", "status": true}}'
check "create clock (valide)" "201" "$STATUS" "$BODY"

echo "--- POST /api/clocks/:userID (sans la clé \"clock\") ---"
request POST "$BASE/clocks/$USER2_ID" '{}'
check "create clock (clé manquante -> 400)" "400" "$STATUS" "$BODY"

echo "--- POST /api/clocks/:userID (attrs invalides : time/status manquants) ---"
request POST "$BASE/clocks/$USER2_ID" '{"clock": {}}'
check "create clock (attrs invalides -> 422)" "422" "$STATUS" "$BODY"

echo "--- POST /api/clocks/999999999 (utilisateur inexistant) ---"
request POST "$BASE/clocks/999999999" '{"clock": {"time": "2026-09-23T08:00:00Z", "status": true}}'
check "create clock (user inexistant -> 404)" "404" "$STATUS" "$BODY"

echo "--- POST /api/clocks/abc (userID non numérique) ---"
request POST "$BASE/clocks/abc" '{"clock": {"time": "2026-09-23T08:00:00Z", "status": true}}'
check "create clock (userID non numérique -> 404)" "404" "$STATUS" "$BODY"

echo "--- GET /api/clocks/:userID (existant, avec un clock) ---"
request GET "$BASE/clocks/$USER2_ID"
check "list clocks (existant)" "200" "$STATUS" "$BODY"

echo "--- GET /api/clocks/999999999 (utilisateur inexistant) ---"
request GET "$BASE/clocks/999999999"
check "list clocks (user inexistant -> 404)" "404" "$STATUS" "$BODY"

################################################################################
# WORKING TIME — 5 routes : GET/:userID, GET/:userID/:id, POST/:userID,
#                            PUT/:id, DELETE/:id
################################################################################

echo -e "${YELLOW}########## WORKING TIME ##########${NC}"
echo

echo "--- POST /api/workingtime/:userID (création valide) ---"
request POST "$BASE/workingtime/$USER2_ID" \
  '{"workingtime": {"start": "2026-09-22T08:00:00Z", "end": "2026-09-22T17:00:00Z"}}'
check "create working time (valide)" "201" "$STATUS" "$BODY"
WT_ID=$(echo "$BODY" | jq -r '.data.id // empty')
[ -z "$WT_ID" ] && { echo -e "${RED}Impossible de créer le working time de test, arrêt.${NC}"; exit 1; }

echo "--- POST /api/workingtime/:userID (end avant start) ---"
request POST "$BASE/workingtime/$USER2_ID" \
  '{"workingtime": {"start": "2026-09-22T17:00:00Z", "end": "2026-09-22T08:00:00Z"}}'
check "create working time (end < start -> 422)" "422" "$STATUS" "$BODY"

echo "--- POST /api/workingtime/:userID (start/end manquants) ---"
request POST "$BASE/workingtime/$USER2_ID" '{"workingtime": {}}'
check "create working time (attrs manquants -> 422)" "422" "$STATUS" "$BODY"

echo "--- POST /api/workingtime/999999999 (utilisateur inexistant) ---"
request POST "$BASE/workingtime/999999999" \
  '{"workingtime": {"start": "2026-09-22T08:00:00Z", "end": "2026-09-22T17:00:00Z"}}'
check "create working time (user inexistant -> 404)" "404" "$STATUS" "$BODY"

echo "--- GET /api/workingtime/:userID (liste, sans filtre) ---"
request GET "$BASE/workingtime/$USER2_ID"
check "list working times (sans filtre)" "200" "$STATUS" "$BODY"

echo "--- GET /api/workingtime/:userID?start=...&end=... (liste filtrée) ---"
request GET "$BASE/workingtime/$USER2_ID?start=2026-09-01T00:00:00Z&end=2026-09-30T23:59:59Z"
check "list working times (filtré)" "200" "$STATUS" "$BODY"

echo "--- GET /api/workingtime/:userID/:id (existant) ---"
request GET "$BASE/workingtime/$USER2_ID/$WT_ID"
check "show working time (existant)" "200" "$STATUS" "$BODY"

echo "--- GET /api/workingtime/:userID/999999999 (id inexistant) ---"
request GET "$BASE/workingtime/$USER2_ID/999999999"
check "show working time (id inexistant -> 404)" "404" "$STATUS" "$BODY"

echo "--- PUT /api/workingtime/:id (données valides) ---"
request PUT "$BASE/workingtime/$WT_ID" \
  '{"workingtime": {"start": "2026-09-22T09:00:00Z", "end": "2026-09-22T18:00:00Z"}}'
check "update working time (valide)" "200" "$STATUS" "$BODY"

echo "--- PUT /api/workingtime/:id (end avant start) ---"
request PUT "$BASE/workingtime/$WT_ID" \
  '{"workingtime": {"start": "2026-09-22T18:00:00Z", "end": "2026-09-22T09:00:00Z"}}'
check "update working time (end < start -> 422)" "422" "$STATUS" "$BODY"

echo "--- PUT /api/workingtime/999999999 (id inexistant) ---"
request PUT "$BASE/workingtime/999999999" \
  '{"workingtime": {"start": "2026-09-22T09:00:00Z", "end": "2026-09-22T18:00:00Z"}}'
check "update working time (id inexistant -> 404)" "404" "$STATUS" "$BODY"

echo "--- DELETE /api/workingtime/:id (existant) ---"
request DELETE "$BASE/workingtime/$WT_ID"
check "delete working time (existant -> 204)" "204" "$STATUS" "$BODY"

echo "--- DELETE /api/workingtime/:id (déjà supprimé) ---"
request DELETE "$BASE/workingtime/$WT_ID"
check "delete working time (déjà supprimé -> 404)" "404" "$STATUS" "$BODY"

################################################################################
# Nettoyage partiel
################################################################################

echo -e "${YELLOW}########## Nettoyage ##########${NC}"
echo
echo -e "${YELLOW}NB${NC}: l'utilisateur $USER2_ID (id=$USER2_ID) n'est pas supprimé : il a encore"
echo "un clock rattaché et il n'existe pas de route DELETE /api/clocks/:id."
echo "La FK clocks.user_id est en ON DELETE NOTHING, donc le supprimer via"
echo "DELETE /api/users/:id ferait échouer la requête. Utilise 'mix ecto.reset'"
echo "pour repartir d'une base propre si besoin."

################################################################################
# Résumé
################################################################################

echo
echo "=== Résumé : $PASS_COUNT réussi(s), $FAIL_COUNT échoué(s) ==="
[ "$FAIL_COUNT" -eq 0 ]
