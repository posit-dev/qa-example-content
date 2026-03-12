#!/bin/bash
# status.sh - Show status of wb-local test environment

echo "WB-Local Test Environment Status"
echo "================================="
echo ""

# Check running containers
echo "Containers:"
if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -E "^(NAMES|test|postgres|connect)" ; then
    :
else
    echo "  No containers running"
    echo ""
    echo "Start with: ./run.sh [ubuntu24|rocky8]"
    exit 0
fi

echo ""

# If test container is running, get more info
if docker ps | grep -q "test"; then
    echo "Versions:"

    # Get Workbench version
    WB_VERSION=$(docker exec test bash -c 'rstudio-server version 2>/dev/null | head -1 | awk "{print \$1}"' 2>/dev/null)
    if [ -n "$WB_VERSION" ] && [ "$WB_VERSION" != "" ]; then
        echo "  Workbench: $WB_VERSION"
    else
        echo "  Workbench: Not installed"
        echo "  Run ./connect.sh to install"
    fi

    # Get Positron version
    POSITRON_VERSION=$(docker exec test bash -c '
        for dir in /usr/lib/rstudio-server/bin/positron-server/new /usr/lib/rstudio-server/bin/positron-server; do
            if [ -f "$dir/product.json" ]; then
                VER=$(grep "positronVersion" "$dir/product.json" 2>/dev/null | sed "s/.*\"positronVersion\": *\"\([^\"]*\)\".*/\1/")
                BUILD=$(grep "positronBuildNumber" "$dir/product.json" 2>/dev/null | sed "s/.*\"positronBuildNumber\": *\"\([^\"]*\)\".*/\1/")
                echo "${VER}-${BUILD}"
                exit 0
            fi
        done
        echo ""
    ' 2>/dev/null)
    if [ -n "$POSITRON_VERSION" ] && [ "$POSITRON_VERSION" != "-" ]; then
        echo "  Positron:  $POSITRON_VERSION"
    else
        echo "  Positron:  Not installed"
    fi

    # Check RStudio server status
    RS_STATUS=$(docker exec test bash -c 'rstudio-server status 2>/dev/null | head -1 || echo "unknown"' 2>/dev/null)
    echo "  Server:    $RS_STATUS"

    echo ""
    echo "Access:"
    echo "  http://localhost:8787  - Workbench (user1 / your WB_PASSWORD)"
    echo "  http://localhost:3939  - Connect"
fi

echo ""
