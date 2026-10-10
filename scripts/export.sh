#!/usr/bin/env bash
# Export every workflow from the running n8n container into workflows/*.json
# (normalised: no timestamps / version ids, so diffs only show real changes).
# Usage: scripts/export.sh [outDir]      (default: workflows)
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: don't rewrite /tmp paths passed to docker

OUT_DIR="${1:-workflows}"

docker compose exec -T n8n n8n export:workflow --all --pretty --output=/tmp/wf-export.json >/dev/null
docker compose exec -T n8n cat /tmp/wf-export.json | node scripts/normalize-workflows.js "$OUT_DIR"
