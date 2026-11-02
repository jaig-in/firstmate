#!/usr/bin/env bash
# Runs inside `unshare -Urm` after a tmpfs is mounted on /tmp: a decoy tmux
# server stands on the namespace's default socket while a real Claude lab is
# brought up and torn down, twice (normal down; down after the lab tmux dir is removed).
set -u
WT=$1; cd "$WT"
LL=bin/fm-live-lab.sh
DEF=/tmp/tmux-$(id -u)/default
say() { printf '\n=== %s ===\n' "$*"; }
decoy_ok() {
  if kill -0 "$DECOY_PID" 2>/dev/null && tmux -S "$DEF" has-session -t decoy 2>/dev/null; then
    echo "DECOY ALIVE pid=$DECOY_PID session=$(tmux -S "$DEF" list-sessions -F '#{session_name}')"
  else echo "DECOY GONE (FAIL)"; fi
}
say "namespace /tmp is private: $(ls -A /tmp | wc -l) entries before decoy; uid=$(id -u)"
env -u TMUX -u TMUX_TMPDIR tmux -f /dev/null new-session -d -s decoy "printf DECOY-PANE; exec sleep 1200"
DECOY_PID=$(tmux -S "$DEF" display-message -p '#{pid}'); echo "decoy server pid=$DECOY_PID on $DEF"

for round in normal missing-dir; do
  say "ROUND $round: up --harness claude"
  ROOT=$(mktemp -d /tmp/fmlab.XXXXXX); rmdir "$ROOT"
  timeout 600 "$LL" up --harness claude --supervision-host none --expect-host no "$ROOT"; echo "up exit=$?"
  TD=$(sed -n 's/^tmux_dir=//p' "$ROOT/.fm-live-lab")
  SOCK="$TD/tmux-$(id -u)/default"
  echo "lab tmux_dir=$TD socket=$SOCK"
  LABPID=$(tmux -S "$SOCK" display-message -p '#{pid}' 2>/dev/null); echo "lab server pid=$LABPID (decoy pid=$DECOY_PID)"
  say "check"; "$LL" check "$ROOT"; echo "check exit=$?"
  say "pane main (tail)"; "$LL" pane "$ROOT" --lines 40 | tail -15
  decoy_ok
  if [ "$round" = missing-dir ]; then
    say "ADVERSARIAL: remove the lab's private tmux directory while the lab runs"
    rm -rf -- "$TD"; ls -ld "$TD" 2>&1
    echo "TMUX_TMPDIR-only form would now reach: $(env -u TMUX TMUX_TMPDIR="$TD" tmux list-sessions -F '#{session_name}' 2>&1)"
    say "pane/say/check against the missing dir"
    out=$("$LL" pane "$ROOT" 2>&1); echo "pane exit=$? decoy-text-seen=$(printf %s "$out" | grep -c DECOY-PANE)"
    "$LL" say "$ROOT" "LAB-TYPED-TEXT" >/dev/null 2>&1; sleep 0.3
    echo "decoy pane has LAB-TYPED-TEXT: $(tmux -S "$DEF" capture-pane -p -t decoy | grep -c LAB-TYPED-TEXT)"
  fi
  say "down"; "$LL" down "$ROOT"; rc=$?; echo "down exit=$rc"
  if [ "$rc" != 0 ] && [ -n "$TD" ] && [ ! -d "$TD" ]; then
    echo "(known pre-existing teardown refusal for a missing dir; recreate and retry)"
    mkdir -m 700 "$TD"; "$LL" down "$ROOT"; echo "down retry exit=$?"
  fi
  kill -0 "$LABPID" 2>/dev/null && echo "LAB SERVER STILL ALIVE (FAIL)" || echo "lab server pid $LABPID gone"
  [ -e "$ROOT" ] && echo "lab root still present" || echo "lab root removed"
  decoy_ok
done
tmux -S "$DEF" kill-server; echo "decoy stopped by its explicit socket"
