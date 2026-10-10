#!/usr/bin/env bash
# Runs tests/audit_log_immutable.sql against the running Postgres container.
# Fails on a non-zero psql exit (a failed assertion raises under ON_ERROR_STOP) or if fewer than 5 PASS lines appear.
set -uo pipefail
cd "$(dirname "$0")/.."
set -a; [ -f .env ] && . ./.env; set +a

out=$(docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER:-leads_app}" -d "${POSTGRES_DB:-leads}" \
  < tests/audit_log_immutable.sql 2>&1)
status=$?
echo "$out" | grep -E "PASS|FAIL|ERROR" || true

passes=$(echo "$out" | grep -c "PASS" || true)
if [ "$status" -ne 0 ] || [ "$passes" -ne 5 ]; then
  echo "AUDIT TEST FAILED (psql exit $status, $passes/5 PASS)"; exit 1
fi
echo "audit_log immutability: OK (5/5)"
