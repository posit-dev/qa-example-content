# Jupyter + Positron Local Development Environment

This directory contains a Docker-based local development environment for testing Positron with JupyterHub using The Littlest JupyterHub (TLJH).

## Overview

- **Base OS**: Ubuntu 24.04
- **JupyterHub**: Installed via The Littlest JupyterHub (TLJH)
- **Positron Server**: Downloaded from [posit-dev/positron-builds](https://github.com/posit-dev/positron-builds)
- **Jupyter Positron Server**: Cloned from [posit-dev/jupyter-positron-server](https://github.com/posit-dev/jupyter-positron-server)

## Prerequisites

1. Docker and Docker Compose installed
2. GitHub Personal Access Token with access to `posit-dev/positron-builds` (private repo)
3. Positron license file (optional, for local development)

## Setup

### 1. Configure Environment Variables

```bash
cp .env.example .env
# Edit .env and add your GITHUB_TOKEN and JUPYTER_PASSWORD
```

### 2. Add License File (Optional)

For local development, place your `positron.lic` file in this directory. The file is git-ignored.

For CI, the license will come from a GitHub secret and will be mounted or copied into the container.

### 3. Start the Container

From the repository root:
```bash
npm run jupyter:start
```

Or from this directory:
```bash
./run.sh
```

This will:
- Pull the base Ubuntu 24 image from GHCR
- Start the container
- Keep it running in the background

### 4. Connect and Install

From the repository root:
```bash
npm run jupyter:connect
```

Or from this directory:
```bash
./connect.sh
```

This will:
- Copy installation scripts into the container
- Copy the license file (if present)
- Show current installation status
- Run the installation script
- Drop you into an interactive shell

For CI mode (non-interactive):
```bash
npm run jupyter:connect:ci
# Or: ./connect.sh --ci
```

### 5. Access JupyterHub

Once installation is complete:
- URL: http://localhost:8888
- Username: `admin`
- Password: `admin`

Or use the configured user:
- Username: `jupyter-user` (or your Q_USER from env)
- Password: (your JUPYTER_PASSWORD from .env)

### 6. Stop and Cleanup

From the repository root:
```bash
npm run jupyter:stop
```

Or from this directory:
```bash
./stop-containers.sh
```

## Scripts

### NPM Scripts (from repository root)

- `npm run jupyter:start` - Start the Docker Compose stack
- `npm run jupyter:connect` - Connect to container and run installation (interactive)
- `npm run jupyter:connect:ci` - Connect and install in CI mode (non-interactive)
- `npm run jupyter:stop` - Stop and remove all containers and volumes

### Shell Scripts (from this directory)

- **run.sh**: Start the Docker Compose stack
- **connect.sh**: Connect to the running container and run installation
- **stop-containers.sh**: Stop and remove all containers and volumes
- **install-jupyter-positron.sh**: Install JupyterHub, Positron, and configure them
- **positronDownload.sh**: Download the latest Positron server from GitHub releases

### Environment Variables

The following environment variables can be set in `.env` or passed directly:

- `GITHUB_TOKEN`: Required. GitHub token for accessing positron-builds
- `JUPYTER_PASSWORD`: Password for the jupyter-user account (default: testpassword)
- `Q_USER`: Username for additional user account (default: jupyter-user)
- `ARCH_SUFFIX`: Architecture suffix (auto-detected: arm64 or amd64)
- `POSITRON_TAG`: Specific Positron release tag (default: latest)
- `LICENSE_FILE`: Path to license file (default: /opt/positron.lic)
- `IMAGE_TAG`: Docker image tag to use (default: latest)

**Note**: The `admin` user is always created with password `admin` for convenience.

## CI Integration

The CI process (running in a different repo) will:

1. Pull the base Ubuntu 24 image from GHCR:
   ```
   ghcr.io/posit-dev/positron-jupyter-ubuntu24-{ARCH}:{TAG}
   ```

2. Run the installation script from this repo:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/{ORG}/{REPO}/{BRANCH}/dockerfiles/jupyter-local/install-jupyter-positron.sh | bash -s -- --ci
   ```

3. The license will be provided via GitHub secret and written to `/opt/positron.lic` before running the install script.

## Architecture

The setup consists of:

1. **Base Image** (Dockerfile):
   - Ubuntu 24.04
   - Basic system dependencies
   - Non-root user (jupyter-user)

2. **Installation Script** (install-jupyter-positron.sh):
   - Installs TLJH
   - Downloads and extracts Positron server
   - Clones jupyter-positron-server
   - Configures JupyterHub to use Positron
   - Applies license

3. **Helper Scripts**:
   - positronDownload.sh: Downloads Positron from GitHub releases
   - connect.sh: Container connection helper
   - run.sh: Docker Compose wrapper
   - stop-containers.sh: Cleanup script

## Differences from wb-local

Unlike the `wb-local` directory which sets up Workbench with Connect and PostgreSQL:

- No Posit Connect container
- No PostgreSQL container
- Simpler architecture focused on Jupyter + Positron
- Uses TLJH instead of Workbench
- Builds Positron server from pre-built releases, not from source

## Troubleshooting

### Container won't start
```bash
./stop-containers.sh
./run.sh
```

### Installation fails
Check that:
- GITHUB_TOKEN is set and valid
- License file exists (if required)
- Architecture is supported (arm64 or amd64/x64)

### Can't access JupyterHub
- Verify the container is running: `docker ps | grep jupyter-test`
- Check JupyterHub status inside container: `systemctl status jupyterhub`
- Check logs: `docker logs jupyter-test`
