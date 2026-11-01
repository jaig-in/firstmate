#!/usr/bin/env bash
# Real bin/fm-live-lab.sh with real Claude sessions beside a decoy default tmux server.
set -u
WT=$1; cd "$WT"
U=$(id -u); DEF=/tmp/tmux-$U/default; LL=bin/fm-live-lab.sh
L1=/tmp/ns/fmlab1; L2=/tmp/ns/fmlab2
tmux -f /dev/null new-session -d -s firstmate -n main "printf 'DECOY-PANE\n'; exec sleep 3000"
DP=$(tmux -S $DEF display-message -p '#{pid}')
decoy_state() { if kill -0 $DP 2>/dev/null; then echo "[decoy pid $DP alive; windows: $(tmux -S $DEF list-windows -a -F '#{session_name}:#{window_name}' | tr '\n' ' '); typed-lab-text lines: $(tmux -S $DEF capture-pane -p -t firstmate:=main | grep -c 'LAB-')]"; else echo "[decoy DEAD]"; fi; }
cleanup() { for l in $L1 $L2; do [ ! -f $l/.fm-live-lab ] || timeout 120 $LL down $l >/dev/null 2>&1; done; timeout 5 tmux -S $DEF kill-server 2>/dev/null; kill -9 $DP 2>/dev/null; }
trap cleanup EXIT
echo "### decoy on default socket"; decoy_state

echo "### LAB 1: up --harness claude --mate --worker"
$LL up --harness claude --mate --worker --timeout 420 $L1 2>&1 | cut -c1-240; echo "up exit=${PIPESTATUS[0]}"
decoy_state
D1=$(sed -n 's/^tmux_dir=//p' $L1/.fm-live-lab); S1=$D1/tmux-$U/default
echo "lab socket: $S1"; ls -la $S1
echo "lab windows:"; tmux -S $S1 list-windows -a -F '  #{session_name}:#{window_name} dead=#{pane_dead} cmd=#{pane_current_command}'
echo "### a lab process sees the same socket through TMUX_TMPDIR"
echo "TMUX_TMPDIR form: $(env -u TMUX TMUX_TMPDIR=$D1 tmux list-windows -a -F '#{window_name}' | tr '\n' ' ')"
echo "### check"; $LL check $L1 2>&1 | cut -c1-200; echo "check exit=${PIPESTATUS[0]}"
echo "### say + pane"
$LL say $L1 "Run no tool. Reply with only the word SAYECHO, a hyphen, and then 77321, with no spaces."; echo "say exit=$?"
for i in $(seq 1 24); do $LL pane $L1 --lines 400 2>/dev/null | grep -q 'SAYECHO-77321$\|SAYECHO-77321 ' && break; sleep 5; done
$LL pane $L1 --lines 40 2>&1 | cut -c1-160 | tail -22
$LL pane $L1 --lines 400 2>&1 | grep -c 'SAYECHO-77321' | sed 's/^/SAYECHO lines in lab pane: /'
echo "lab trust entries in overlaid ~/.claude.json: $(node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.HOME+"/.claude.json"));console.log(Object.keys(j.projects).filter(k=>k.startsWith("/tmp/ns/")).length)')"
decoy_state
echo "### down lab 1"
$LL down $L1 2>&1 | cut -c1-200; echo "down exit=${PIPESTATUS[0]}"
decoy_state
ls -d $L1 $D1 2>&1 | cut -c1-120
pgrep -fa "$L1" | grep -v -e live-claude -e pgrep | head -5 | cut -c1-160; echo "(end of lab-1 survivor list)"

echo "### LAB 2: primary only, then its tmux directory disappears under it"
$LL up --harness claude --timeout 240 $L2 2>&1 | cut -c1-240; echo "up exit=${PIPESTATUS[0]}"
D2=$(sed -n 's/^tmux_dir=//p' $L2/.fm-live-lab); S2=$D2/tmux-$U/default
tmux -S $S2 kill-server; sleep 1; rm -rf "$D2"; ls -d $D2 2>&1 | cut -c1-120
echo "### control: the TMUX_TMPDIR-only form now reaches the decoy"
env -u TMUX TMUX_TMPDIR=$D2 tmux list-windows -a -F '  fell through to: #{session_name}:#{window_name}'
for c in "pane $L2" "say $L2 LAB-TYPED-TEXT" "check $L2"; do
  echo "--- $c"; $LL $c 2>&1 | cut -c1-200 | grep -vE '^(ok|fail) (trust|treehouse|host|watcher)' ; echo "exit=${PIPESTATUS[0]}"; sleep 0.3
done
decoy_state
echo "--- down $L2"; $LL down $L2 2>&1 | cut -c1-200; echo "down exit=${PIPESTATUS[0]}"
decoy_state
tmux -S $DEF has-session -t firstmate && echo "default server still holds its session"
