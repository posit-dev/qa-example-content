# Positron Test Environment

This directory contains Docker configurations for testing Positron on both ARM64 and AMD64 architectures.

## Directory Structure

- `Dockerfile.ubuntu24_04.arm` - Dockerfile for ARM64 architecture
- `Dockerfile.ubuntu24_04.amd` - Dockerfile for AMD64 architecture
- `docker-compose.arm64.yml` - Docker Compose file for ARM64 architecture
- `docker-compose.amd64.yml` - Docker Compose file for AMD64 architecture
- `deps/` - Shared dependencies used by both architectures
  - `startup.sh` - Startup script for the containers
  - `.env` - Environment variables file (not committed to Git)
  - `pdol_rsa` - Private key file for licensing (not committed to Git)
- `init-scripts/` - Database initialization scripts

## Required Configuration Files

Before building or running the Docker containers, you need to set up two important files in the `deps` directory:

1. **`.env` file** - Create this file with:
   ```
   GITHUB_TOKEN=your_github_token_here
   ```
   This token is used to clone the private positron-license repository during the build process.

2. **`pdol_rsa` file** - This is a private key file needed for licensing.

Both files are automatically excluded from git via .gitignore for security reasons.

## Build and Run Instructions

### ARM64 Architecture Build
```bash
docker-compose -f docker-compose.arm64.yml --env-file deps/.env build
OR 
docker-compose -f docker-compose.arm64.yml --env-file deps/.env build --no-cache
```

### ARM64 Architecture Run Electron Tests (No Build)
```bash
docker-compose -f docker-compose.arm64.yml up --no-build 
```

### View Test Report on Host
From a separate terminal:
```bash
docker ps
docker exec -it {TEST_CONTAINER_ID} bash
```
Then inside the container:
```bash
npx playwright show-report --host 0.0.0.0
```
Then go to http://localhost:9323 in your host browser

### Run Browser Tests
```bash
docker-compose -f docker-compose.arm64.yml run --service-ports --use-aliases --entrypoint bash test
```
Then inside the container:
```bash
sudo service xvfb start
export DISPLAY=:10
fluxbox &
sudo x11vnc -forever -nopw -display :10 &
npx playwright test --project "e2e-browser" --workers 2 --retries 1
```

### View UI with VNC
Use RealVNC Viewer and connect to `localhost:5900`

### Logs
To view the logs from the test container when running in detached mode:

```bash
# View logs for the test container (see past logs)
docker-compose -f docker-compose.arm64.yml logs test

# Follow the logs in real-time (most useful option)
docker-compose -f docker-compose.arm64.yml logs -f test
```

## Current Test Results
### Electron all

98% passing


```bash
test-arm64  |   5 failed
test-arm64  |     [e2e-electron] › test/e2e/tests/debug/r-debug.test.ts:49:6 › R Debugging › R - Verify call stack behavior and order @:debug @:web @:win @:ark
test-arm64  |     [e2e-electron] › test/e2e/tests/new-folder-flow/new-folder-flow-jupyter.test.ts:24:6 › New Folder Flow: Jupyter Project › Jupyter Folder Defaults @:modal @:new-folder-flow @:critical @:win
test-arm64  |     [e2e-electron] › test/e2e/tests/new-folder-flow/new-folder-flow-r.test.ts:40:6 › New Folder Flow: R Project › R - Accept Renv install @:modal @:new-folder-flow @:web @:ark @:win
test-arm64  |     [e2e-electron] › test/e2e/tests/plots/plots.test.ts:285:7 › Plots › Python Plots › Python - Verify Plot Zoom works (Fit vs. 200%) @:plots @:editor
test-arm64  |     [e2e-electron] › test/e2e/tests/quarto/quarto-python.test.ts:16:6 › Quarto - Python › Verify Quarto app can render correctly with Python script @:web @:win @:quarto
```

### Browser all

98% passing

```bash
  5 failed
    [e2e-browser] › test/e2e/tests/debug/r-debug.test.ts:49:6 › R Debugging › R - Verify call stack behavior and order @:debug @:web @:win @:ark
    [e2e-browser] › test/e2e/tests/quarto/quarto-python.test.ts:16:6 › Quarto - Python › Verify Quarto app can render correctly with Python script @:web @:win @:quarto
    [e2e-browser] › test/e2e/tests/reticulate/reticulate-restart.test.ts:31:6 › Reticulate › R - Verify Reticulate Restart @:reticulate @:web @:reticulate @:console
    [e2e-browser] › test/e2e/tests/reticulate/reticulate-stop-start.test.ts:32:6 › Reticulate › R - Verify Reticulate Stop/Start Functionality @:reticulate @:web @:ark
    [e2e-browser] › test/e2e/tests/sessions/session-mgmt.test.ts:25:6 › Sessions: Management › Validate active session list in console matches active session list in session picker @:win @:web @:console @:sessions @:critical
```

### Electron All

97% passing

```bash
  2 failed
    [e2e-electron] › test/e2e/tests/data-explorer/data-explorer-python-pandas.test.ts:140:6 › Data Explorer - Python Pandas › Python Pandas - Verify blank spaces in data explorer and disconnect behavior @:web @:win @:critical @:data-explorer
    [e2e-electron] › test/e2e/tests/new-folder-flow/new-folder-flow-jupyter.test.ts:24:6 › New Folder Flow: Jupyter Project › Jupyter Folder Defaults @:modal @:new-folder-flow @:critical @:win
```

### Browser Critical

100% passing

### Electron Critical

99% passing

```bash
    1 failed
    [e2e-electron] › test/e2e/tests/new-folder-flow/new-folder-flow-jupyter.test.ts:24:6 › New Folder Flow: Jupyter Project › Jupyter Folder Defaults @:modal @:new-folder-flow @:critical @:win
```

## Troubleshooting

### Permission Issues with pdol_rsa

If you get "permission denied" errors related to the pdol_rsa file, check its permissions:

```bash
# View current permissions
ls -la deps/pdol_rsa

# Set correct permissions if needed
chmod 600 deps/pdol_rsa
```