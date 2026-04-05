#!/usr/bin/env bash
set -euo pipefail

# Activate the conda environment.
# CONDA_ENV_NAME is baked in at build time via ENV in the Dockerfile,
# but can be overridden at runtime with -e CONDA_ENV_NAME=myenv.
CONDA_ENV_NAME="${CONDA_ENV_NAME:-ds}"

if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    source /opt/conda/etc/profile.d/conda.sh
    conda activate "${CONDA_ENV_NAME}" 2>/dev/null || {
        echo "WARNING: Could not activate conda env '${CONDA_ENV_NAME}', continuing in base." >&2
    }
fi

if [ "$#" -eq 0 ]; then
    exec sleep infinity
fi

trap 'echo "Received SIGTERM, shutting down gracefully..." >&2; exit 0' SIGTERM

exec "$@"