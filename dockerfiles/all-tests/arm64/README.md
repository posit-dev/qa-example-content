# Positron Test Environment

## Manual Setup Commands

### Build
```bash
cd dockerfiles/all-tests/arm64
docker build -f Dockerfile.critical.arm -t positron-critical-arm:latest .
OR
docker build --no-cache -f Dockerfile.critical.arm -t positron-critical-arm:latest .
```

### Run Electron Critical Tests
```bash
docker run -it --rm -p 5900:5900 positron-critical-arm
```
Note: `-p 5900:5900` is for VNC access to the Electron app

### Current Pass Rate
- 96% (critical tests)
- 98% (all tests)

### Debug Mode
```bash
docker run -it --rm -p 5900:5900 -p 9323:9323 positron-critical-arm bash
```
Note: `-p 9323:9323` is for the Playwright report viewer

Once inside the container:
```bash
sudo service xvfb start
export DISPLAY=:10
fluxbox &
sudo x11vnc -forever -nopw -display :10 &
npx playwright test --project "e2e-electron" --workers 1 --grep "Verify Basic Dash App"
npx playwright test --project "e2e-electron" --workers 2
npx playwright show-report --host 0.0.0.0
```

### View UI with VNC
Use RealVNC Viewer and connect to `localhost:5900`

### View Test Report on Host
From a separate terminal:
```bash
docker ps
docker exec -it {CONTAINER_ID} bash
npx playwright show-report --host 0.0.0.0
```
Then go to http://localhost:9323 in your host browser

### Manual PostgreSQL Setup
```bash
docker network create mynetwork
docker run --name local-postgres -p 5432:5432 --network mynetwork --name db -e POSTGRES_USER=testuser -e POSTGRES_PASSWORD=testpassword -e POSTGRES_DB=testdb -d postgres:latest
```

Download the SQL file from:
https://github.com/neondatabase-labs/postgres-sample-dbs/blob/main/periodic_table.sql

Then import it:
```bash
psql -h localhost -U testuser -d testdb -f /path/to/periodic_table.sql
```

Run the test container:
```bash
docker run -it --rm -p 5900:5900 -p 9323:9323 --network mynetwork --name test positron-critical-arm 
```

Or for debugging:
```bash
docker run -it --rm -p 5900:5900 -p 9323:9323 --network mynetwork --name test positron-critical-arm bash
sudo service xvfb start
export DISPLAY=:10
fluxbox &
sudo x11vnc -forever -nopw -display :10 &
npx playwright test --project "e2e-electron" --workers 2
```

## Docker Compose Setup (Recommended)

This setup creates two Docker containers:
1. A PostgreSQL database container (`db`) with the periodic table sample database
2. A test container (`test`) based on Dockerfile.critical.arm

### Prerequisites

- Docker and Docker Compose installed
- Git (to clone the repository)

### Running the Setup

To start the containers:

```bash
# Build and start containers in one command (detached mode)
cd /path/to/qa-example-content/dockerfiles/all-tests/arm64
docker-compose up -d

# OR to see container output in terminal (foreground mode)
docker-compose up

# OR build images first
docker-compose build

# THEN start without rebuilding (useful for subsequent runs)
docker-compose up -d --no-build  # detached mode
docker-compose up --no-build     # foreground mode with output visible
```

This will:
1. Start a PostgreSQL container with user `testuser`, password `testpassword`, and database `testdb`
2. Download the periodic_table.sql file and initialize the database with it
3. Build and start the test container based on Dockerfile.critical.arm (or use existing image)
4. Connect both containers to a shared network called `mynetwork`

### Accessing the Containers

#### PostgreSQL Database

You can connect to the PostgreSQL database from your host machine:

```bash
psql -h localhost -U testuser -d testdb
```

When prompted, enter the password: `testpassword`

Inside the test container, you can connect to the database using:
- Host: db
- Port: 5432
- User: testuser
- Password: testpassword
- Database: testdb

#### Test Container

The test container exposes several ports:
- 8080: Main application port
- 5900: VNC server port
- 9323: Additional service port

To view the logs from the test container when running in detached mode:

```bash
# View logs for the test container (see past logs)
docker-compose logs test

# Follow the logs in real-time (most useful option)
docker-compose logs -f test
```

To access a shell in the running container:

```bash
docker-compose exec test bash
```

To start the test container with a bash prompt instead of the default startup script:

```bash
# Override the entrypoint to start with bash and ensure dependencies (db) are started
docker-compose run --service-ports --use-aliases --entrypoint bash test
```

This will:
1. Start the db container if it's not already running (due to the dependency specified in docker-compose.yml)
2. Start a new test container with a bash prompt
3. Set up the network and port mappings correctly (--service-ports)
4. Ensure the container can be reached by its service name (--use-aliases)

Once in the bash shell, you can run commands manually:

### Stopping the Setup

To stop the containers:

```bash
docker-compose down
```

To stop and remove all data (including the PostgreSQL volume):

```bash
docker-compose down -v
```

### Manual Database Setup (Alternative)

If you prefer to set up the database manually:

1. Download the periodic table SQL file:
```bash
./download-periodic-table.sh
```

2. Start only the PostgreSQL container:
```bash
docker-compose up -d db
```

3. Import the SQL file:
```bash
psql -h localhost -U testuser -d testdb -f ~/Downloads/periodic_table.sql
```
