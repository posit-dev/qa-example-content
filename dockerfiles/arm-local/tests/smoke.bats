#!/usr/bin/env bats
# smoke.bats - Smoke tests for arm-local shell scripts
#
# Requires bats-core: https://github.com/bats-core/bats-core
# Install: brew install bats-core
# Run: bats tests/smoke.bats

SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# ---------------------------------------------------------------------------
# connect.sh
# ---------------------------------------------------------------------------

@test "connect.sh --help exits 0 and prints usage" {
  run "$SCRIPTS_DIR/connect.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "connect.sh unknown flag exits non-zero" {
  run "$SCRIPTS_DIR/connect.sh" --unknown-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "connect.sh --ci requires a branch name" {
  run "$SCRIPTS_DIR/connect.sh" --ci
  [ "$status" -ne 0 ]
  [[ "$output" == *"--ci requires a branch name"* ]]
}

@test "connect.sh --ci with branch parses branch correctly" {
  # No Docker → falls through to container-not-running check.
  # We just verify the argument parsing doesn't abort early.
  run "$SCRIPTS_DIR/connect.sh" --ci some-branch
  # Either exits because Docker/container not found, or succeeds — not an arg-parse error.
  [[ "$output" != *"--ci requires a branch name"* ]]
  [[ "$output" != *"Unknown option"* ]]
}

# ---------------------------------------------------------------------------
# status.sh
# ---------------------------------------------------------------------------

@test "status.sh exits 0 when no containers are running" {
  # Stub docker to report no running containers.
  docker() {
    if [[ "$1 $2" == "ps --format" ]]; then
      echo ""
    else
      command docker "$@"
    fi
  }
  export -f docker

  run "$SCRIPTS_DIR/status.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"None running"* ]]
}

# ---------------------------------------------------------------------------
# setup-test-env.sh
# ---------------------------------------------------------------------------

@test "setup-test-env.sh prints usage when called with no args" {
  run "$SCRIPTS_DIR/setup-test-env.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "setup-test-env.sh prints usage with -h flag" {
  run "$SCRIPTS_DIR/setup-test-env.sh" -h
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "setup-test-env.sh prints usage with --help flag" {
  run "$SCRIPTS_DIR/setup-test-env.sh" --help
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}
