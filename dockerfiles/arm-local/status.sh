#!/bin/bash
# status.sh - Show status of arm-local test environment

echo "ARM-Local Test Environment Status"
echo "=================================="
echo ""

# Check running containers
echo "Containers:"
if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -E "^(NAMES|test|postgres)" ; then
    :
else
    echo "  No containers running"
    echo ""
    echo "Start with: ./run-with-license.sh [ubuntu24|rocky8|...]"
    exit 0
fi

echo ""

# If test container is running, get more info
if docker ps | grep -q "test"; then
    echo "Test Environment:"

    # Check if repo exists and get branch
    BRANCH=$(docker exec test bash -c 'cd /__w/positron/positron 2>/dev/null && git branch --show-current 2>/dev/null' 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        echo "  Branch: $BRANCH"

        # Get last commit
        COMMIT=$(docker exec test bash -c 'cd /__w/positron/positron 2>/dev/null && git log -1 --format="%h %s" 2>/dev/null' 2>/dev/null)
        if [ -n "$COMMIT" ]; then
            echo "  Commit: $COMMIT"
        fi
    else
        echo "  Repo: Not cloned yet"
        echo "  Run ./connect.sh to set up"
    fi

    # Check if Xvfb is running
    XVFB=$(docker exec test bash -c 'pgrep -x Xvfb >/dev/null && echo "running" || echo "not running"' 2>/dev/null)
    echo "  Display (Xvfb): $XVFB"

    # Check if VNC is running
    VNC=$(docker exec test bash -c 'pgrep -f "vnc|x0vnc" >/dev/null && echo "running on localhost:5900" || echo "not running"' 2>/dev/null)
    echo "  VNC: $VNC"

    echo ""
    echo "Ports:"
    echo "  localhost:5900  - VNC"
    echo "  localhost:9323  - Playwright report"
    echo "  localhost:3456  - SSH (if installed)"
fi

echo ""
