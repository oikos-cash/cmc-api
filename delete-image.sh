#!/usr/bin/env bash
# Delete a Docker image both locally and from Docker Hub.
#
# Usage:
#   ./delete-image.sh                       # deletes oikos2/cmc-api:latest
#   ./delete-image.sh <namespace>/<repo>    # deletes <namespace>/<repo>:latest
#   ./delete-image.sh <namespace>/<repo> <tag>
#   ./delete-image.sh <namespace>/<repo> --all-tags   # delete every tag (whole repo)
#
# Auth: set DOCKERHUB_USER and DOCKERHUB_TOKEN in your env, or you'll be prompted.

set -euo pipefail

IMAGE="${1:-oikos2/cmc-api}"
TAG_OR_FLAG="${2:-latest}"

NAMESPACE="${IMAGE%%/*}"
REPO="${IMAGE##*/}"

if [[ "$NAMESPACE" == "$IMAGE" ]]; then
  echo "Image must be in '<namespace>/<repo>' form, got: $IMAGE" >&2
  exit 1
fi

DELETE_ALL=false
TAG="$TAG_OR_FLAG"
if [[ "$TAG_OR_FLAG" == "--all-tags" ]]; then
  DELETE_ALL=true
  TAG=""
fi

echo "Target: docker.io/${NAMESPACE}/${REPO}"
if $DELETE_ALL; then
  echo "Scope:  ALL TAGS (entire repository on Docker Hub)"
else
  echo "Scope:  tag '${TAG}' on Docker Hub + matching local image"
fi
read -r -p "Continue? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

: "${DOCKERHUB_USER:=}"
: "${DOCKERHUB_TOKEN:=}"
if [[ -z "$DOCKERHUB_USER" ]]; then
  read -r -p "Docker Hub username: " DOCKERHUB_USER
fi
if [[ -z "$DOCKERHUB_TOKEN" ]]; then
  read -r -s -p "Docker Hub access token (input hidden): " DOCKERHUB_TOKEN
  echo
fi

echo "Authenticating to Docker Hub API..."
JWT=$(curl -fsS -H "Content-Type: application/json" \
  -X POST -d "{\"username\":\"${DOCKERHUB_USER}\",\"password\":\"${DOCKERHUB_TOKEN}\"}" \
  https://hub.docker.com/v2/users/login/ \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')

if [[ -z "$JWT" ]]; then
  echo "Failed to obtain JWT — check username/token." >&2
  exit 1
fi

if $DELETE_ALL; then
  echo "Deleting entire repository ${NAMESPACE}/${REPO} on Docker Hub..."
  http_code=$(curl -s -o /tmp/dockerhub-del.$$ -w "%{http_code}" \
    -X DELETE -H "Authorization: JWT ${JWT}" \
    "https://hub.docker.com/v2/repositories/${NAMESPACE}/${REPO}/")
else
  echo "Deleting tag ${NAMESPACE}/${REPO}:${TAG} on Docker Hub..."
  http_code=$(curl -s -o /tmp/dockerhub-del.$$ -w "%{http_code}" \
    -X DELETE -H "Authorization: JWT ${JWT}" \
    "https://hub.docker.com/v2/repositories/${NAMESPACE}/${REPO}/tags/${TAG}/")
fi

case "$http_code" in
  204) echo "Docker Hub: deleted (HTTP $http_code)" ;;
  202) echo "Docker Hub: delete accepted (HTTP $http_code)" ;;
  404) echo "Docker Hub: nothing to delete (HTTP 404 — already gone or never existed)" ;;
  *)   echo "Docker Hub: unexpected response (HTTP $http_code):"; cat /tmp/dockerhub-del.$$ ;;
esac
rm -f /tmp/dockerhub-del.$$

LOCAL_REF="${IMAGE}:${TAG:-latest}"
echo "Removing local image ${LOCAL_REF}..."
if docker image inspect "$LOCAL_REF" >/dev/null 2>&1; then
  docker rmi "$LOCAL_REF"
else
  echo "Local image ${LOCAL_REF} not present — skipping."
fi

if $DELETE_ALL; then
  echo "Removing any other local tags of ${IMAGE}..."
  docker images --format '{{.Repository}}:{{.Tag}}' \
    | grep -E "^${IMAGE}:" \
    | xargs -r docker rmi || true
fi

echo "Done."
