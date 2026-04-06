#!/usr/bin/env bash
set -eo pipefail

CONDA_ENV_NAME="${CONDA_ENV_NAME:-ds}"

if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    set +u
    source /opt/conda/etc/profile.d/conda.sh || true
    conda activate "${CONDA_ENV_NAME}" || {
        echo "WARNING: Could not activate conda env '${CONDA_ENV_NAME}', continuing in base." >&2
    }
    set -u
fi

trap 'echo "Received SIGTERM, shutting down gracefully..." >&2; exit 0' SIGTERM

if [ "$#" -eq 0 ]; then
    exec sleep infinity
fi

exec conda run -n "${CONDA_ENV_NAME}" --no-capture-output "$@"