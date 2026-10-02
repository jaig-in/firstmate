#!/usr/bin/env bash
# Behavior tests for the tmux isolation the live lab depends on:
# fm_tmux_isolation_gate (tests/lib.sh) and bin/fm-live-lab.sh's explicit lab
# socket. tmux resolves its socket under TMUX_TMPDIR only while that directory
# exists and otherwise silently falls back to /tmp/tmux-<uid>, so a lab command
# aimed at a removed lab directory would reach whatever server lives there.
# Here a decoy server stands on that default socket, and every lab command
# aimed at a missing lab directory must leave it alone.
#
# The suite starts that decoy, so it opens with the gate it tests: it runs only
# where no live tmux server answers on the default socket directory, such as
# under a private /tmp:
#   unshare -Urm sh -c 'mount -t tmpfs tmpfs /tmp && exec bin/fm-test-run.sh tests/fm-live-lab-isolation.test.sh'
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

command -v tmux >/dev/null 2>&1 || { echo "skip: tmux not found"; exit 0; }
# The decoy can never share the default socket with a live server, so the
# opt-in to run beside one does not apply to this suite.
# shellcheck disable=SC2119 # No bases: the gate checks the real default ones.
FM_TMUX_UNISOLATED_OK='' fm_tmux_isolation_gate
unset TMUX TMUX_TMPDIR

TMP_ROOT=$(fm_test_tmproot fm-lab-iso)
LIVE_LAB="$ROOT/bin/fm-live-lab.sh"
GATE_SOCKET="$TMP_ROOT/base/tmux-$(id -u)/default"
DEFAULT_SOCKET="/tmp/tmux-$(id -u)/default"
DECOY_PID=''

isolation_cleanup() {
  # Only the servers this suite started, each by its own explicit socket or
  # its recorded server pid, and only while it is still there.
  [ ! -S "$GATE_SOCKET" ] || tmux -S "$GATE_SOCKET" kill-server 2>/dev/null
  if [ -n "$DECOY_PID" ] && [ "$(ps -o comm= -p "$DECOY_PID" 2>/dev/null)" = tmux ]; then
    kill "$DECOY_PID" 2>/dev/null
  fi
  fm_test_cleanup
}
trap isolation_cleanup EXIT

# gate_run <base> [NAME=VALUE...]: the gate's output and exit, in a subshell,
# followed by RAN when the gate let the script continue.
gate_run() {
  local base=$1
  shift
  (
    for assignment in "$@"; do export "${assignment?}"; done
    fm_tmux_isolation_gate "$base"
    echo RAN
  ) 2>&1
}

# ---- the gate ---------------------------------------------------------------

out=$(gate_run "$TMP_ROOT/base" CI=)
expect_code 0 "$?" "the gate passes with no socket directory: $out"
assert_equals RAN "$out" "the gate runs the suite where no tmux server can answer"

mkdir -p "$TMP_ROOT/base"
mkdir -m 700 "$TMP_ROOT/base/tmux-$(id -u)"
tmux -S "$GATE_SOCKET" -f /dev/null new-session -d -s live 'exec sleep 600' || fail "cannot start the gate's own server"
out=$(gate_run "$TMP_ROOT/base" CI=)
expect_code 0 "$?" "the gate skips cleanly beside a live server: $out"
assert_contains "$(printf '%s\n' "$out" | head -n 1)" "skip: tmux isolation: a live tmux server answers on $GATE_SOCKET" "the skip is the first line and names the live socket"
assert_contains "$out" "unshare -Urm" "the skip names the isolation it needs"
assert_contains "$out" "FM_TMUX_UNISOLATED_OK=1" "the skip names the explicit opt-in"
assert_not_contains "$out" RAN "the gate stops the suite beside a live server"

out=$(gate_run "$TMP_ROOT/base" CI=true)
expect_code 1 "$?" "under CI a live server fails instead of dropping coverage: $out"
assert_contains "$out" "not ok - tmux isolation" "the CI failure says why"
assert_not_contains "$out" RAN "the CI failure stops the suite"

out=$(gate_run "$TMP_ROOT/base" CI= FM_TMUX_UNISOLATED_OK=1)
expect_code 0 "$?" "the explicit opt-in runs beside a live server: $out"
assert_equals RAN "$out" "the explicit opt-in runs the suite"

tmux -S "$GATE_SOCKET" kill-server 2>/dev/null
out=$(gate_run "$TMP_ROOT/base" CI=)
assert_equals RAN "$out" "the gate runs again once only a dead socket is left"
pass "fm_tmux_isolation_gate runs isolated, skips beside a live server, and fails under CI"

# ---- a lab aimed at a missing tmux directory --------------------------------

# The gate above passed for /tmp, so no live server answers on the default
# socket; the decoy is a fresh server of this suite's own.
! tmux -S "$DEFAULT_SOCKET" list-sessions >/dev/null 2>&1 || fail "refusing to start a decoy beside a live server on $DEFAULT_SOCKET"
env -u TMUX -u TMUX_TMPDIR tmux -f /dev/null new-session -d -s firstmate -n main \
  "printf 'DECOY-PANE\n'; exec sleep 600" || fail "cannot start the decoy default server"
DECOY_PID=$(tmux -S "$DEFAULT_SOCKET" display-message -p '#{pid}')
[ -n "$DECOY_PID" ] || fail "the decoy is not on the default socket"

# shellcheck disable=SC2119 # No bases: the gate checks the real default ones.
out=$( (CI=; unset FM_TMUX_UNISOLATED_OK; fm_tmux_isolation_gate; echo RAN) 2>&1)
assert_contains "$out" "skip: tmux isolation: a live tmux server answers on $DEFAULT_SOCKET" "the gate's default bases see a server on the default socket"
assert_not_contains "$out" RAN "the gate stops a suite beside the default server"

HOME="$TMP_ROOT/home"
mkdir -p "$HOME/.pi/agent" "$HOME/.treehouse"
printf '{}\n' > "$HOME/.pi/agent/trust.json"
printf '{"projects":{}}\n' > "$HOME/.claude.json"
LAB_ROOT="$TMP_ROOT/lab"
MISSING_DIR=$(mktemp -d /tmp/fml.XXXXXX) || fail "cannot name a missing lab tmux directory"
rmdir "$MISSING_DIR" || fail "cannot remove the lab tmux directory"
mkdir -p "$LAB_ROOT/home/state"
: > "$LAB_ROOT/.treehouse-before"
{
  echo 'fm-live-lab v1'
  echo "harness=claude"
  echo "home=$LAB_ROOT/home"
  echo "expect_host=no"
  echo "host_off=no"
  echo "mate=no"
  echo "worker=no"
  echo "nonce=deadbeef0000"
  echo "mate_id=labdeadbeef0000-mate"
  echo "worker_id=labdeadbeef0000-worker"
  echo "pi_trust=$(shasum -a 256 "$HOME/.pi/agent/trust.json" | awk '{print $1}')"
  echo "claude_config_dir="
  echo "claude_store=$HOME/.claude.json"
  echo "pi_trust_store=$HOME/.pi/agent/trust.json"
  echo "treehouse_dir=$HOME/.treehouse"
  echo "tmux_dir=$MISSING_DIR"
} > "$LAB_ROOT/.fm-live-lab"

# The divergence this suite exists for: the TMUX_TMPDIR-only form reaches the
# decoy once the lab directory is gone.
env -u TMUX TMUX_TMPDIR="$MISSING_DIR" tmux has-session -t firstmate 2>/dev/null \
  || fail "this tmux no longer falls back to the default socket; the decoy cases would prove nothing"

out=$("$LIVE_LAB" pane "$LAB_ROOT" 2>&1)
assert_not_contains "$out" DECOY-PANE "pane never reads the default server's window"
"$LIVE_LAB" say "$LAB_ROOT" "LAB-TYPED-TEXT" >/dev/null 2>&1
sleep 0.2
assert_not_contains "$(tmux -S "$DEFAULT_SOCKET" capture-pane -p -t firstmate:=main)" LAB-TYPED-TEXT "say never types into the default server"
out=$("$LIVE_LAB" check "$LAB_ROOT" 2>&1)
assert_not_contains "$out" "ok primary" "check never reads the default server as the lab"
out=$("$LIVE_LAB" down "$LAB_ROOT" 2>&1)
expect_code 0 "$?" "down cleans a lab whose tmux directory is gone: $out"
assert_absent "$LAB_ROOT" "down removed the lab root"
kill -0 "$DECOY_PID" 2>/dev/null || fail "down killed the default tmux server"
tmux -S "$DEFAULT_SOCKET" has-session -t firstmate 2>/dev/null || fail "the default server lost its session"
pass "a lab aimed at a missing tmux directory never reaches the default tmux server"
