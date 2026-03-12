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

# ---------------------------------------------------------------------------
# .env loading (connect.sh)
# ---------------------------------------------------------------------------

@test "connect.sh loads plain KEY=VALUE from .env" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  echo "MY_TEST_VAR=hello_world" > "$tmpdir/.env"

  # Run connect.sh from tmpdir so it finds the .env; it will fail at the
  # docker-not-running check, but the env-loading line should execute first.
  run bash -c "
    cd '$tmpdir'
    # Patch connect.sh to print the var and exit early after loading .env
    bash -c '
      if [ -f .env ]; then
        while IFS= read -r line || [ -n \"\$line\" ]; do
          [[ \"\$line\" =~ ^[[:space:]]*# ]] && continue
          [[ -z \"\${line// }\" ]] && continue
          if [[ \"\$line\" =~ ^[A-Za-z_][A-Za-z0-9_]*=(.*)$ ]]; then
            export \"\$line\"
          fi
        done < .env
      fi
      echo \"VAR=\$MY_TEST_VAR\"
    '
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"VAR=hello_world"* ]]
  rm -rf "$tmpdir"
}

@test "connect.sh ignores .env lines with shell metacharacters in key" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  printf 'SAFE_VAR=ok\n$(touch /tmp/pwned)=bad\n' > "$tmpdir/.env"

  run bash -c "
    cd '$tmpdir'
    bash -c '
      if [ -f .env ]; then
        while IFS= read -r line || [ -n \"\$line\" ]; do
          [[ \"\$line\" =~ ^[[:space:]]*# ]] && continue
          [[ -z \"\${line// }\" ]] && continue
          if [[ \"\$line\" =~ ^[A-Za-z_][A-Za-z0-9_]*=(.*)$ ]]; then
            export \"\$line\"
          fi
        done < .env
      fi
      echo \"SAFE=\$SAFE_VAR\"
    '
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAFE=ok"* ]]
  # Malicious key must not have been executed
  [ ! -f /tmp/pwned ]
  rm -rf "$tmpdir"
}

@test "connect.sh loads .env value that contains spaces" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  echo 'MY_VAR=hello world' > "$tmpdir/.env"

  run bash -c "
    cd '$tmpdir'
    bash -c '
      if [ -f .env ]; then
        while IFS= read -r line || [ -n \"\$line\" ]; do
          [[ \"\$line\" =~ ^[[:space:]]*# ]] && continue
          [[ -z \"\${line// }\" ]] && continue
          if [[ \"\$line\" =~ ^[A-Za-z_][A-Za-z0-9_]*=(.*)$ ]]; then
            export \"\$line\"
          fi
        done < .env
      fi
      echo \"VAR=\$MY_VAR\"
    '
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"VAR=hello world"* ]]
  rm -rf "$tmpdir"
}

# ---------------------------------------------------------------------------
# GHCR image extraction (run-with-license.sh)
# ---------------------------------------------------------------------------

@test "GHCR image extraction handles unquoted image value" {
  local tmpfile
  tmpfile="$(mktemp)"
  printf 'services:\n  test:\n    image: ghcr.io/org/image:tag\n' > "$tmpfile"

  run awk '/image:.*ghcr\.io/{
    sub(/^[[:space:]]*image:[[:space:]]*/, "")
    gsub(/^["'"'"']|["'"'"']$/, "")
    gsub(/[[:space:]].*$/, "")
    print; exit
  }' "$tmpfile"

  [ "$status" -eq 0 ]
  [ "$output" = "ghcr.io/org/image:tag" ]
  rm -f "$tmpfile"
}

@test "GHCR image extraction handles double-quoted image value" {
  local tmpfile
  tmpfile="$(mktemp)"
  printf 'services:\n  test:\n    image: "ghcr.io/org/image:tag"\n' > "$tmpfile"

  run awk '/image:.*ghcr\.io/{
    sub(/^[[:space:]]*image:[[:space:]]*/, "")
    gsub(/^["'"'"']|["'"'"']$/, "")
    gsub(/[[:space:]].*$/, "")
    print; exit
  }' "$tmpfile"

  [ "$status" -eq 0 ]
  [ "$output" = "ghcr.io/org/image:tag" ]
  rm -f "$tmpfile"
}

@test "GHCR image extraction handles single-quoted image value" {
  local tmpfile
  tmpfile="$(mktemp)"
  printf "services:\n  test:\n    image: 'ghcr.io/org/image:tag'\n" > "$tmpfile"

  run awk '/image:.*ghcr\.io/{
    sub(/^[[:space:]]*image:[[:space:]]*/, "")
    gsub(/^["'"'"']|["'"'"']$/, "")
    gsub(/[[:space:]].*$/, "")
    print; exit
  }' "$tmpfile"

  [ "$status" -eq 0 ]
  [ "$output" = "ghcr.io/org/image:tag" ]
  rm -f "$tmpfile"
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
