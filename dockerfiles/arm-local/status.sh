#!/bin/bash
# status.sh - Show status of arm-local test environment

# Load env so CONTAINER_PREFIX is available if set
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs) 2>/dev/null || true
fi
TEST_CONTAINER="${CONTAINER_PREFIX:-}test"
POSTGRES_CONTAINER="${CONTAINER_PREFIX:-}postgres"

echo "ARM-Local Test Environment Status"
echo "=================================="
echo ""

# Check if containers are running
if ! docker ps --format "{{.Names}}" | grep -qE "^(${TEST_CONTAINER}|${POSTGRES_CONTAINER})$"; then
    echo "Containers: None running"
    echo ""
    echo "Start with: npm run arm:start"
    exit 0
fi

# Show running containers
echo "Containers:"
docker ps --format "  {{.Names}}: {{.Status}}" | grep -E "${TEST_CONTAINER}|${POSTGRES_CONTAINER}"
echo ""

# If test container is running, get more info
if docker ps --format "{{.Names}}" | grep -q "^${TEST_CONTAINER}$"; then
    echo "Test Environment:"

    # Check if repo exists and get branch
    BRANCH=$(docker exec "$TEST_CONTAINER" bash -c 'cd /__w/positron/positron 2>/dev/null && git branch --show-current 2>/dev/null' 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        echo "  Branch: $BRANCH"

        # Get last commit
        COMMIT=$(docker exec "$TEST_CONTAINER" bash -c 'cd /__w/positron/positron 2>/dev/null && git log -1 --format="%h %s" 2>/dev/null' 2>/dev/null)
        if [ -n "$COMMIT" ]; then
            echo "  Commit: $COMMIT"
        fi
    else
        echo "  Repo: Not cloned yet"
        echo "  Run: npm run arm:connect"
    fi

    # Check if Xvfb is running
    XVFB=$(docker exec "$TEST_CONTAINER" bash -c 'pgrep -x Xvfb >/dev/null && echo "running" || echo "not running"' 2>/dev/null)
    echo "  Display (Xvfb): $XVFB"

    # Check if VNC is running
    VNC=$(docker exec "$TEST_CONTAINER" bash -c 'pgrep -f "vnc|x0vnc" >/dev/null && echo "running on localhost:5900" || echo "not running"' 2>/dev/null)
    echo "  VNC: $VNC"

    echo ""
    echo "Ports:"
    echo "  localhost:5900  - VNC"
    echo "  localhost:9323  - Playwright report"
    echo "  localhost:3456  - SSH (if installed)"
fi

echo ""
