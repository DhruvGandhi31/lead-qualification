#!/usr/bin/env bash
# (Re)load credentials + workflows from this repo into the stack and publish them.
# `docker compose up -d` already does this on every start via the n8n-init service;
# use this script to apply workflow edits to an already-running stack.
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE_ARGS=()
[ "${USE_MOCK:-0}" = "1" ] && PROFILE_ARGS=(--profile mock)

docker compose "${PROFILE_ARGS[@]}" run --rm n8n-init
# n8n only picks up (re)published workflows on start.
docker compose "${PROFILE_ARGS[@]}" restart n8n
