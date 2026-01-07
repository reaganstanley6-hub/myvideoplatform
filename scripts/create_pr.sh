#!/usr/bin/env bash
# create_pr.sh
# Creates a draft pull request using GITHUB_TOKEN and REPO variables.
# Expects: GITHUB_TOKEN, REPO (like owner/repo), BRANCH (branch name). Optionally BASE (default main).

set -e

if [ -z "$GITHUB_TOKEN" ]; then
  echo "GITHUB_TOKEN is required to create a PR. Export it as environment variable." >&2
  exit 1
fi

if [ -z "$REPO" ]; then
  echo "REPO (owner/repo) is required." >&2
  exit 1
fi

BRANCH=${BRANCH:-feat/transcode-worker-ci}
BASE=${BASE:-main}
TITLE=${TITLE:-"feat: add transcoding worker, HLS, BullMQ, Docker Compose, and CI workflows"}
BODY=${BODY:-"This PR adds FFmpeg-based transcoding, HLS multi-quality outputs, worker and queue scaffolding, Docker Compose for dev, and CI workflows for Playwright E2E tests."}

API_URL="https://api.github.com/repos/$REPO/pulls"

curl -s -X POST $API_URL \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d "{ \"title\": \"$TITLE\", \"head\": \"$BRANCH\", \"base\": \"$BASE\", \"body\": \"$BODY\", \"draft\": true }"

echo "PR creation API call sent (response above)."
