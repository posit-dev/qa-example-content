FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies including systemd
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    systemd \
    systemd-sysv \
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

# Clean up systemd
RUN cd /lib/systemd/system/sysinit.target.wants/ && \
    ls | grep -v systemd-tmpfiles-setup | xargs rm -f && \
    rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/basic.target.wants/* \
    /lib/systemd/system/anaconda.target.wants/* \
    /lib/systemd/system/plymouth* \
    /lib/systemd/system/systemd-update-utmp*

# Enable systemd
STOPSIGNAL SIGRTMIN+3

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

# Use systemd as init
CMD ["/lib/systemd/systemd"]
