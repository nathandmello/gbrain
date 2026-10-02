#!/bin/sh
set -eu

SOURCE="${GBRAIN_SYNC_SOURCE:?GBRAIN_SYNC_SOURCE is required}"
REPO="${GBRAIN_SOURCE_REPO_URL:?GBRAIN_SOURCE_REPO_URL is required}"
: "${GBRAIN_GITHUB_PAT:?GBRAIN_GITHUB_PAT is required}"
: "${GBRAIN_HOME:=/data}"
: "${HOME:=/data}"

GBRAIN="./bin/gbrain"
CLONE="$GBRAIN_HOME/.gbrain/clones/$SOURCE"
CREDS="$GBRAIN_HOME/.gbrain/cron-github-credentials"

echo "[cron] Starting GBrain sync for $SOURCE"

mkdir -p "$GBRAIN_HOME/.gbrain"

#
# First run only: create this worker's local GBrain config.
# The brain/database already exists in Supabase.
#
if [ ! -f "$GBRAIN_HOME/.gbrain/config.json" ]; then
  echo "[cron] Initializing local GBrain configuration"

  "$GBRAIN" init \
    --force \
    --non-interactive \
    --db-only \
    --embedding-model voyage:voyage-4 \
    --embedding-dimensions 1024
fi

#
# Temporary Git credential file.
# Never put the PAT into the repo URL or command-line arguments.
#
umask 077
printf 'https://x-access-token:%s@github.com\n' "$GBRAIN_GITHUB_PAT" > "$CREDS"

cleanup() {
  rm -f "$CREDS"
}
trap cleanup EXIT INT TERM

export GIT_TERMINAL_PROMPT=0

mkdir -p "$(dirname "$CLONE")"

#
# First run only: materialize this cron worker's copy of the artifacts repo.
#
if [ ! -d "$CLONE/.git" ]; then
  echo "[cron] Cloning $REPO"

  rm -rf "$CLONE"

  git \
    -c "credential.helper=store --file=$CREDS" \
    clone "$REPO" "$CLONE"
fi

#
# Make subsequent pulls performed by GBrain use our temporary credential.
#
git -C "$CLONE" remote set-url origin "$REPO"
git -C "$CLONE" config credential.helper "store --file=$CREDS"

#
# Incrementally pull/index the source.
#
echo "[cron] Syncing $SOURCE"

"$GBRAIN" sync \
  --source "$SOURCE" \
  --json \
  --timeout 1500

#
# Catch any chunks that weren't embedded inline during sync.
#
echo "[cron] Embedding stale chunks"

"$GBRAIN" embed \
  --stale \
  --source "$SOURCE" \
  --json

echo "[cron] GBrain sync complete"
