#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

mkdir -p user/fonts

compose() {
    if [ -s user/license-key ]; then
        docker compose -f compose.release.yml -f compose.license.yml "$@"
    else
        docker compose -f compose.release.yml "$@"
    fi
}

command=${1:-up}
if [ "$#" -gt 0 ]; then
    shift
fi

case "$command" in
    up)
        compose up -d "$@"
        ;;
    update)
        compose pull
        compose up -d "$@"
        ;;
    down)
        compose down "$@"
        ;;
    restart)
        compose restart "$@"
        ;;
    status)
        compose ps "$@"
        ;;
    logs)
        compose logs -f "$@"
        ;;
    *)
        echo "usage: $0 {up|update|down|restart|status|logs}" >&2
        exit 64
        ;;
esac
