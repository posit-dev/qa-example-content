FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    sudo \
    vim \
    jq \
    libsecret-1-0 \
    libkrb5-3 \
    python3 \
    python3-pip \
    python3-venv \
    python-is-python3 \
    openssh-server \
    acl \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for jupyter
ARG Q_USER=jupyter-user
ARG Q_UID=1100
ARG Q_GID=1100
ARG Q_GROUP=jupyter-group

RUN groupadd -g ${Q_GID} ${Q_GROUP} && \
    useradd --create-home --shell /bin/bash --home-dir /home/${Q_USER} -u ${Q_UID} -g ${Q_GROUP} ${Q_USER} && \
    echo "${Q_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up working directory
WORKDIR /opt

# Keep container running
CMD ["/bin/bash", "-c", "while true; do sleep 3600; done"]
