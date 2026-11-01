#!/usr/bin/env bash
# No Claude: the isolation gate, the fail-before on the base script, and the owning suites.
set -u
WT=$1; BASE=$2
U=$(id -u); DEF=/tmp/tmux-$U/default
cd "$WT"
decoy_up() { tmux -f /dev/null new-session -d -s firstmate -n main "printf 'DECOY-PANE\n'; exec sleep 900"; DP=$(tmux -S $DEF display-message -p '#{pid}'); echo "decoy pid $DP on $DEF"; }
decoy_down() { [ ! -S $DEF ] || timeout 5 tmux -S $DEF kill-server 2>/dev/null; kill -9 ${DP:-0} 2>/dev/null; rm -f $DEF; true; }
trap decoy_down EXIT

echo "=== A. suite beside a live default server: the gate must skip, decoy must survive"
decoy_up
for t in tests/fm-live-lab.test.sh tests/fm-live-lab-up-mate.test.sh; do
  echo "--- $t"; bash $t 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"
  echo "--- $t CI=true"; CI=true bash $t 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"
done
kill -0 $DP && tmux -S $DEF has-session -t firstmate && echo "decoy alive with its session"

echo "=== B. stopped server: gate gives up at its deadline"
kill -STOP $DP; s=$(date +%s)
FM_TMUX_ISOLATION_PROBE_SECONDS=1 timeout 30 bash tests/fm-live-lab.test.sh 2>&1 | tail -2; echo "exit=${PIPESTATUS[0]} elapsed=$(( $(date +%s)-s ))s"
kill -CONT $DP

mk_record() { # <root> <tmuxdir>
  mkdir -p "$1/home/state"; : > "$1/.treehouse-before"
  { echo 'fm-live-lab v1'; echo harness=claude; echo "home=$1/home"; echo expect_host=no; echo host_off=no; echo mate=no; echo worker=no; echo nonce=deadbeef0000
    echo mate_id=labdeadbeef0000-mate; echo worker_id=labdeadbeef0000-worker; echo pi_trust=absent; echo claude_config_dir=; echo "claude_store=/tmp/ns/none.json"; echo pi_trust_store=/tmp/ns/none-pi; echo "treehouse_dir=/tmp/ns/th"; echo "tmux_dir=$2"; } > "$1/.fm-live-lab"
}
echo "=== C. FAIL-BEFORE: base commit's fm-live-lab.sh down, tmux dir gone"
mkdir -p /tmp/ns/base; git archive "$BASE" bin | tar -x -C /tmp/ns/base
mk_record /tmp/ns/lab-base /tmp/fml.gone1
/tmp/ns/base/bin/fm-live-lab.sh down /tmp/ns/lab-base 2>&1 | tail -3
sleep 0.5
if kill -0 $DP 2>/dev/null; then echo "BASE: decoy survived"; else echo "BASE: decoy server KILLED by down"; fi
decoy_down

echo "=== D. HEAD: the same call, plus say/pane/check"
decoy_up
mk_record /tmp/ns/lab-head /tmp/fml.gone2
bin/fm-live-lab.sh pane /tmp/ns/lab-head 2>&1 | tail -2; echo "pane exit=${PIPESTATUS[0]}"
bin/fm-live-lab.sh say /tmp/ns/lab-head LAB-TYPED-TEXT 2>&1 | tail -2; echo "say exit=${PIPESTATUS[0]}"
sleep 0.3
tmux -S $DEF capture-pane -p -t firstmate:=main | grep -c LAB-TYPED-TEXT | sed 's/^/typed-into-decoy lines: /'
bin/fm-live-lab.sh check /tmp/ns/lab-head 2>&1 | grep -E 'primary' ; 
bin/fm-live-lab.sh down /tmp/ns/lab-head 2>&1 | tail -3; echo "down exit=${PIPESTATUS[0]}"
kill -0 $DP && tmux -S $DEF has-session -t firstmate && echo "HEAD: decoy alive with its session"
tmux -S $DEF list-windows -t firstmate -F 'decoy window: #{window_name}'
decoy_down

echo "=== E. namespace unavailable: isolation suite skips decoy cases"
mkdir -p /tmp/ns/shim; printf '#!/bin/sh\nexit 1\n' > /tmp/ns/shim/unshare; chmod +x /tmp/ns/shim/unshare
PATH=/tmp/ns/shim:$PATH bash tests/fm-live-lab-isolation.test.sh 2>&1 | tail -4; echo "exit=${PIPESTATUS[0]}"

echo "=== F. owning suites, no live server on the private /tmp"
for t in tests/fm-live-lab-isolation.test.sh tests/fm-live-lab-up-mate.test.sh tests/fm-gate-refuse.test.sh tests/fm-live-lab.test.sh; do
  echo "--- $t"; s=$(date +%s); bin/fm-test-run.sh $t 2>&1 | tail -4; echo "exit=${PIPESTATUS[0]} elapsed=$(( $(date +%s)-s ))s"
done
