# =============================================================================
# Build-time arguments — override with --build-arg or via CI matrix
# =============================================================================
ARG CUDA_VERSION=13.2.0
ARG UBUNTU_VERSION=22.04

FROM nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu${UBUNTU_VERSION}

# resets after from
ARG CUDA_VERSION=13.2.0
ARG MINIFORGE_VERSION=24.3.0-0
ARG CONDA_ENV_NAME=ds
ARG USERNAME=devuser
ARG UID=1000
ARG GID=1000

# =============================================================================
# Runtime environment — only values that must survive into the container shell
# =============================================================================
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

# Conda
ENV CONDA_DIR=/opt/conda \
    CONDA_AUTO_ACTIVATE_BASE=false
ENV PATH="${CONDA_DIR}/bin:${PATH}"

# CUDA
ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${CUDA_HOME}/extras/CUPTI/lib64"

# NVIDIA container
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Python
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1

# Expose the conda env name so entrypoint.sh can read it without hardcoding
ENV CONDA_ENV_NAME=${CONDA_ENV_NAME}

# User identity (runtime-readable, not used by RUN commands — use the ARGs below)
ENV USERNAME=${USERNAME}



# =============================================================================
# System packages
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        wget \
        git \
        git-lfs \
        unzip \
        zip \
        bzip2 \
        xz-utils \
        vim \
        nano \
        zsh \
        tmux \
        libssl-dev \
        libffi-dev \
        libxml2-dev \
        libxslt1-dev \
        libhdf5-dev \
        libgomp1 \
        htop \
        nvtop \
        sudo \
        rsync \
        jq \
        tree \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Non-root user
# =============================================================================
RUN groupadd --gid ${GID} ${USERNAME} \
    && useradd --uid ${UID} --gid ${GID} -m -s /bin/zsh ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# Oh My Zsh for the new user
RUN su - ${USERNAME} -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended" \
    || true

# =============================================================================
# Miniforge (conda)
# =============================================================================
ARG TARGETARCH
RUN case "${TARGETARCH}" in \
        amd64)  MINIFORGE_ARCH=Linux-x86_64  ;; \
        arm64)  MINIFORGE_ARCH=Linux-aarch64 ;; \
        *)      echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL \
        "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-${MINIFORGE_ARCH}.sh" \
        -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p "${CONDA_DIR}" \
    && rm /tmp/miniforge.sh \
    && chown -R ${USERNAME}:${USERNAME} "${CONDA_DIR}" \
    && conda config --system --set auto_update_conda false \
    && conda config --system --set report_errors false \
    && conda clean -afy

# =============================================================================
# Conda environment
# =============================================================================
COPY environment.yml /tmp/environment.yml
COPY requirements.txt /tmp/requirements.txt

RUN conda env create --name ${CONDA_ENV_NAME} -f /tmp/environment.yml \
    && conda clean -afy \
    && rm /tmp/environment.yml /tmp/requirements.txt

# Auto-activate the env in both zsh and bash for interactive shells
RUN echo "source ${CONDA_DIR}/etc/profile.d/conda.sh" >> /etc/profile.d/conda-init.sh \
    && echo "conda activate ${CONDA_ENV_NAME}" >> /etc/profile.d/conda-init.sh \
    && echo "source /etc/profile.d/conda-init.sh" >> /home/${USERNAME}/.zshrc \
    && echo "source /etc/profile.d/conda-init.sh" >> /home/${USERNAME}/.bashrc

# =============================================================================
# Git global config
# =============================================================================
RUN git config --system core.editor "vim" \
    && git config --system pull.rebase false \
    && git lfs install --system

# =============================================================================
# Claude Code
# =============================================================================
RUN su - ${USERNAME} -c \
    "curl -fsSL https://claude.ai/install.sh | bash" \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/${USERNAME}/.zshrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/${USERNAME}/.bashrc

# =============================================================================
# Entrypoint & workspace
# =============================================================================
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN mkdir -p /workspace /home/${USERNAME}/.jupyter \
    && chown -R ${USERNAME}:${USERNAME} /workspace /home/${USERNAME} \
    && chmod -R 755 /workspace

WORKDIR /workspace
USER ${USERNAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

HEALTHCHECK NONE