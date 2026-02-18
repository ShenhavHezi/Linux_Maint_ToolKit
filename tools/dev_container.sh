#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="linux-maint-dev"

usage(){
  cat <<'USAGE'
Usage: tools/dev_container.sh [build|shell|test]

Commands:
  build  Build the dev container image
  shell  Start an interactive shell in the container
  test   Run make lint && make test in the container

Notes:
- Requires Podman or Docker.
- Uses the current repo as a bind mount at /work.
USAGE
}

runtime=""
if command -v podman >/dev/null 2>&1; then
  runtime="podman"
elif command -v docker >/dev/null 2>&1; then
  runtime="docker"
else
  echo "ERROR: podman or docker is required" >&2
  exit 1
fi

cmd="${1:-}"
case "$cmd" in
  build)
    $runtime build -t "$IMAGE_NAME" -f containers/dev.Dockerfile .
    ;;
  shell)
    $runtime run --rm -it -v "$(pwd)":/work -w /work "$IMAGE_NAME" bash
    ;;
  test)
    $runtime run --rm -t -v "$(pwd)":/work -w /work "$IMAGE_NAME" bash -lc "make lint && make test"
    ;;
  -h|--help|"")
    usage
    exit 0
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage
    exit 2
    ;;
esac
