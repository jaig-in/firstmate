#!/usr/bin/env bash
# say/pane round trip on the primary and the mate, beside a decoy default server.
set -u
WT=$1; cd "$WT"
U=$(id -u); DEF=/tmp/tmux-$U/default; LL=bin/fm-live-lab.sh; L=/tmp/ns/saylab
tmux -f /dev/null new-session -d -s firstmate -n main "exec sleep 3000"; DP=$(tmux -S $DEF display-message -p '#{pid}')
cleanup() { [ ! -f $L/.fm-live-lab ] || timeout 120 $LL down $L >/dev/null 2>&1; timeout 5 tmux -S $DEF kill-server 2>/dev/null; kill -9 $DP 2>/dev/null; }
trap cleanup EXIT
$LL up --harness claude --mate --supervision-host none --timeout 300 $L 2>&1 | grep -E '^(ok|fail|ready)' | cut -c1-120; echo "up exit=${PIPESTATUS[0]}"
for w in main mate; do
  $LL say $L --window $w "Run no tool. Reply with only the word SAYECHO, a hyphen, and then 77321${w:0:1}, with no spaces."; echo "say $w exit=$?"
  for i in $(seq 1 24); do $LL pane $L --window $w --lines 300 2>/dev/null | grep -q "^[^a-z]*SAYECHO-77321${w:0:1}" && break; sleep 5; done
  echo "$w waited $((i*5))s; reply lines:"; $LL pane $L --window $w --lines 300 2>&1 | grep -n "SAYECHO-77321${w:0:1}" | cut -c1-100
done
echo "decoy typed-text lines: $(tmux -S $DEF capture-pane -p -t firstmate:=main | grep -c SAYECHO); decoy alive: $(kill -0 $DP && echo yes)"
$LL down $L 2>&1 | tail -2 | cut -c1-120; echo "down exit=${PIPESTATUS[0]}"
