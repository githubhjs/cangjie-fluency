#!/usr/bin/env bash
# Forward to release.sh
exec "$(dirname "$0")/release.sh" "$@"
