ARG CUDA_VERSION=13.2.0
ARG UBUNTU_VERSION=22.04

FROM nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

ENV CONDA_DIR=/opt/conda
ENV PATH="${CONDA_DIR}/bin:${PATH}"
ENV CONDA_AUTO_ACTIVATE_BASE=false

ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${CUDA_HOME}/extras/CUPTI/lib64:${LD_LIBRARY_PATH}"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONFAULTHANDLER=1

ENV USERNAME=devuser
ENV UID=1000
ENV GID=1000

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

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

RUN groupadd --gid ${GID} ${USERNAME} \
    && useradd --uid ${UID} --gid ${GID} -m -s /bin/zsh ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

ARG MINIFORGE_VERSION=24.3.0-0
ARG MINIFORGE_ARCH=Linux-x86_64

RUN curl -fsSL "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-${MINIFORGE_ARCH}.sh" \
    -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p "${CONDA_DIR}" \
    && rm /tmp/miniforge.sh \
    && chown -R ${USERNAME}:${USERNAME} "${CONDA_DIR}" \
    && conda config --system --set auto_update_conda false \
    && conda config --system --set report_errors false \
    && conda clean -afy

COPY environment.yml /tmp/environment.yml
COPY requirements.txt /tmp/requirements.txt

RUN conda env create -f /tmp/environment.yml \
    && conda clean -afy \
    && rm /tmp/environment.yml

RUN echo "conda activate ds" >> /opt/conda/etc/profile.d/conda.sh \
    && echo "source /opt/conda/etc/profile.d/conda.sh" >> /home/${USERNAME}/.zshrc \
    && echo "conda activate ds" >> /home/${USERNAME}/.zshrc \
    && echo "source /opt/conda/etc/profile.d/conda.sh" >> /home/${USERNAME}/.bashrc \
    && echo "conda activate ds" >> /home/${USERNAME}/.bashrc

SHELL ["/bin/bash", "-c"]

RUN git config --system core.editor "vim" \
    && git config --system pull.rebase false \
    && git lfs install --system

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN mkdir -p /workspace /home/${USERNAME}/.jupyter \
    && chown -R ${USERNAME}:${USERNAME} /workspace /home/${USERNAME} \
    && chmod -R 755 /workspace

WORKDIR /workspace
USER ${USERNAME}

HEALTHCHECK NONE