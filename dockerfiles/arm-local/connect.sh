#!/bin/bash

# This script connects to the running test container and optionally sets up the test environment

# Parse command line arguments
CI_MODE=false
CI_BRANCH=""
while [ $# -gt 0 ]; do
  case $1 in
    -h|--help)
      echo "Usage: ./connect.sh [OPTIONS]"
      echo ""
      echo "Connects to the running test container and sets up the Positron test environment"
      echo ""
      echo "OPTIONS:"
      echo "  --ci <branch>  CI mode: skip prompts and setup specified branch automatically"
      echo "  -h, --help     Show this help message"
      exit 0
      ;;
    --ci)
      CI_MODE=true
      shift
      if [ -n "$1" ] && [ "${1:0:1}" != "-" ]; then
        CI_BRANCH="$1"
        shift
      else
        echo "Error: --ci requires a branch name"
        echo "Usage: ./connect.sh --ci <branch_name>"
        exit 1
      fi
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  export $(grep -v '^#' .env | xargs)
fi

# Check if the container is running
if ! docker ps | grep -q "test"; then
  echo "Error: test container is not running!"
  echo "Please start it first with: ./run-with-license.sh [ubuntu24|rocky8|opensuse156|sles156|debian12]"
  exit 1
fi

# Copy scripts to container (quietly)
for script in setup-test-env.sh start-vnc.sh ssh-install.sh; do
  if [ -f "./$script" ]; then
    docker cp "./$script" "test:/tmp/$script" >/dev/null 2>&1
    docker exec test chmod +x "/tmp/$script" 2>/dev/null
  fi
done

# Connect to the container and run setup
if [ "$CI_MODE" = true ]; then
  echo "Running in CI mode with branch: $CI_BRANCH"
  docker exec -it test /bin/bash -c "/tmp/setup-test-env.sh '$CI_BRANCH' && exec /bin/bash -l"
else
  # Interactive mode - show status and menu
  docker exec -it test /bin/bash -c '
    # Check setup status
    if [ -d "/__w/positron/positron/.git" ]; then
        BRANCH=$(cd /__w/positron/positron && git branch --show-current 2>/dev/null)
        COMMIT=$(cd /__w/positron/positron && git log -1 --format="%h %s" 2>/dev/null)
        SETUP_DONE=true
    else
        SETUP_DONE=false
    fi

    # Check Xvfb
    if pgrep -x Xvfb >/dev/null 2>&1; then
        DISPLAY_STATUS="running"
    else
        DISPLAY_STATUS="not running"
    fi

    echo ""
    echo "=== Status ==="
    if [ "$SETUP_DONE" = true ]; then
        echo "Branch:  $BRANCH"
        echo "Commit:  $COMMIT"
        echo "Display: $DISPLAY_STATUS"
    else
        echo "Setup:   Not complete"
        echo "Display: $DISPLAY_STATUS"
    fi

    echo ""
    echo "=== Options ==="
    if [ "$SETUP_DONE" = true ]; then
        echo "1) Update environment  [git pull + reinstall]"
    else
        echo "1) Setup environment   [clone + install]"
    fi
    echo "2) Skip to shell"
    echo ""

    if [ "$SETUP_DONE" = true ]; then
        read -p "Choice [1-2, default=2]: " choice
        choice=${choice:-2}
    else
        read -p "Choice [1-2, default=1]: " choice
        choice=${choice:-1}
    fi

    case $choice in
      1)
        echo ""
        read -p "Branch [default=main]: " branch
        branch=${branch:-main}
        /tmp/setup-test-env.sh "$branch"
        ;;
      2)
        ;;
      *)
        echo "Invalid choice."
        ;;
    esac

    # Always show quick reference before dropping to shell
    echo ""
    if [ -d "/__w/positron/positron/.git" ]; then
        echo "=== Quick Reference ==="
        echo "Example test commands:"
        echo "  npx playwright test --project e2e-electron --workers 2 --grep @:connections"
        echo "  npx playwright test --project e2e-browser --workers 2 --grep @:data-explorer"
        echo ""
        echo "Other commands:"
        echo "  /tmp/start-vnc.sh    - Start VNC server"
        echo "  /tmp/ssh-install.sh  - Install SSH server"
        echo ""
        cd /__w/positron/positron
    else
        echo "=== Quick Reference ==="
        echo "To set up, run:"
        echo "  /tmp/setup-test-env.sh <branch>"
        echo ""
        echo "Other commands:"
        echo "  /tmp/start-vnc.sh    - Start VNC server"
        echo "  /tmp/ssh-install.sh  - Install SSH server"
        echo ""
    fi
    exec /bin/bash -l
  '
fi
