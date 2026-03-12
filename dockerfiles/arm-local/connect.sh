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

# Copy scripts to container
echo "Copying scripts to container..."

if [ -f "./setup-test-env.sh" ]; then
  docker cp ./setup-test-env.sh test:/tmp/setup-test-env.sh
  docker exec test chmod +x /tmp/setup-test-env.sh
fi

if [ -f "./start-vnc.sh" ]; then
  docker cp ./start-vnc.sh test:/tmp/start-vnc.sh
  docker exec test chmod +x /tmp/start-vnc.sh
fi

if [ -f "./ssh-install.sh" ]; then
  docker cp ./ssh-install.sh test:/tmp/ssh-install.sh
  docker exec test chmod +x /tmp/ssh-install.sh
fi

# Connect to the container and run setup
if [ "$CI_MODE" = true ]; then
  echo "Running in CI mode with branch: $CI_BRANCH"
  docker exec -it test /bin/bash -c "/tmp/setup-test-env.sh '$CI_BRANCH' && exec /bin/bash -l"
else
  # Interactive mode - show status and menu
  docker exec -it test /bin/bash -c '
    echo ""
    echo "=== Current Status ==="
    if [ -d "/__w/positron/positron/.git" ]; then
        BRANCH=$(cd /__w/positron/positron && git branch --show-current 2>/dev/null)
        COMMIT=$(cd /__w/positron/positron && git log -1 --format="%h %s" 2>/dev/null)
        echo "Branch: $BRANCH"
        echo "Commit: $COMMIT"
        SETUP_DONE=true
    else
        echo "Repo: Not cloned yet"
        SETUP_DONE=false
    fi

    # Check Xvfb
    if pgrep -x Xvfb >/dev/null 2>&1; then
        echo "Display: running"
    else
        echo "Display: not running"
    fi

    echo ""
    echo "=== Options ==="
    if [ "$SETUP_DONE" = true ]; then
        echo "1) Update environment        [pull + reinstall deps]"
    else
        echo "1) Setup environment         [clone + install deps]"
    fi
    echo "2) Skip to shell             [quick reconnect, no changes]"
    echo ""
    read -p "Enter your choice [1-2, default=2 if setup done, else 1]: " choice

    # Smart default: skip to shell if already set up
    if [ -z "$choice" ]; then
        if [ "$SETUP_DONE" = true ]; then
            choice=2
        else
            choice=1
        fi
    fi

    case ${choice:-1} in
      1)
        read -p "Enter branch name [default=main]: " branch
        branch=${branch:-main}
        /tmp/setup-test-env.sh "$branch"
        ;;
      2)
        echo "Skipping setup. Going to shell..."
        echo ""
        echo "Available commands:"
        echo "  /tmp/setup-test-env.sh <branch>  - Set up test environment"
        echo "  /tmp/start-vnc.sh                - Start VNC server"
        echo "  /tmp/ssh-install.sh              - Install and start SSH server"
        ;;
      *)
        echo "Invalid choice. Going to shell..."
        ;;
    esac
    exec /bin/bash -l
  '
fi
