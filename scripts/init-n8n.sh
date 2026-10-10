#!/bin/sh
# One-shot bootstrap run by the n8n-init compose service (same image/version as n8n).
# Idempotent: safe to re-run on every `docker compose up`.
set -eu

CREDS=/tmp/credentials.rendered.json

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "init: ANTHROPIC_API_KEY is empty - qualification will fail safe into needs_review."
fi

echo "init: rendering credentials from environment"
node /scripts/render-credentials.js /scripts/credentials.template.json "$CREDS"

echo "init: importing credentials"
n8n import:credentials --input="$CREDS"
rm -f "$CREDS"

# Re-runs: import:workflow refuses to touch workflows that are already published
# ("no permission to deactivate"), so unpublish first and re-publish below.
echo "init: unpublishing existing workflows (for idempotent re-import)"
n8n unpublish:workflow --all

echo "init: importing workflows"
n8n import:workflow --separate --input=/workflows

# import:workflow leaves everything unpublished by default; publish each one.
for f in /workflows/*.json; do
  id=$(node -p "require('$f').id")
  echo "init: publishing workflow $id ($(basename "$f"))"
  n8n publish:workflow --id="$id"
done

echo "init: done"
