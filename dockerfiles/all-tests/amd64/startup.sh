#!/bin/bash
set -e

# Start Xvfb
echo "Starting Xvfb..."
sudo service xvfb start
export DISPLAY=:10

# Start fluxbox window manager
echo "Starting Fluxbox window manager..."
fluxbox &
FLUXBOX_PID=$!

# Wait for fluxbox to be ready
echo "Waiting for Fluxbox to initialize..."
sleep 2
if ! ps -p $FLUXBOX_PID > /dev/null; then
    echo "Fluxbox failed to start!"
    exit 1
fi
echo "Fluxbox running with PID $FLUXBOX_PID"

# Start x11vnc
echo "Starting x11vnc server..."
sudo x11vnc -forever -nopw -display :10 &
VNC_PID=$!

# Wait for x11vnc to be ready
sleep 1
if ! ps -p $VNC_PID > /dev/null; then
    echo "x11vnc failed to start!"
    exit 1
fi
echo "x11vnc running with PID $VNC_PID"

# Run playwright tests with list reporter and save HTML report to a specific path
echo "Running Playwright tests..."
DISPLAY=:10 npx playwright test --workers 2 --project e2e-electron --reporter=list,html

