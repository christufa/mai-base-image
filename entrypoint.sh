#!/usr/bin/env bash
set -euo pipefail

if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    source /opt/conda/etc/profile.d/conda.sh
    conda activate ds 2>/dev/null || true
fi

if [ "$#" -eq 0 ]; then
    exec sleep infinity
fi

trap 'echo "Received SIGTERM, shutting down..."; exit 0' SIGTERM

exec "$@"