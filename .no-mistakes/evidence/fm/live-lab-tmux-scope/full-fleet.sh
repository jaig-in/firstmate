#!/usr/bin/env bash
# Real up --mate --worker beside a decoy default tmux server: check, say, pane, down.
set -u
WT=$1; cd "$WT"
U=$(id -u); DEF=/tmp/tmux-$U/default; LL=bin/fm-live-lab.sh; L=/tmp/ns/fleet
echo "neutral rc in force: $(cat ~/.zshrc)"
tmux -f /dev/null new-session -d -s firstmate -n main "printf 'DECOY-PANE\n'; exec sleep 3000"
DP=$(tmux -S $DEF display-message -p '#{pid}')
decoy() { if kill -0 $DP 2>/dev/null; then echo "[decoy pid $DP alive; windows: $(tmux -S $DEF list-windows -a -F '#{session_name}:#{window_name}' | tr '\n' ' '); lab-text lines: $(tmux -S $DEF capture-pane -p -t firstmate:=main | grep -c 'FLEET-')]"; else echo "[decoy DEAD]"; fi; }
cleanup() { [ ! -f $L/.fm-live-lab ] || timeout 120 $LL down $L >/dev/null 2>&1; timeout 5 tmux -S $DEF kill-server 2>/dev/null; kill -9 $DP 2>/dev/null; }
trap cleanup EXIT
decoy
echo "### up --harness claude --mate --worker"
$LL up --harness claude --mate --worker --timeout 420 $L 2>&1 | cut -c1-220; echo "up exit=${PIPESTATUS[0]}"
decoy
D=$(sed -n 's/^tmux_dir=//p' $L/.fm-live-lab); S=$D/tmux-$U/default
echo "lab socket: $S"; tmux -S $S list-windows -a -F '  #{session_name}:#{window_name} dead=#{pane_dead} cmd=#{pane_current_command} path=#{pane_current_path}' | cut -c1-140
echo "### a lab process reaches the same server through TMUX_TMPDIR"
echo "TMUX_TMPDIR form: $(env -u TMUX TMUX_TMPDIR=$D tmux list-windows -a -F '#{window_name}' | tr '\n' ' ')"
echo "### check"; $LL check $L 2>&1 | cut -c1-200; echo "check exit=${PIPESTATUS[0]}"
echo "### say to primary, read pane"
$LL say $L "Run no tool. Reply with only the word FLEET, a hyphen, and then 77321, with no spaces."; echo "say exit=$?"
for i in $(seq 1 30); do $LL pane $L --lines 400 2>/dev/null | grep -q '^. *FLEET-77321' && break; sleep 5; done
$LL pane $L --lines 400 2>&1 | grep -n 'FLEET-77321' | cut -c1-120
echo "### worker pane"; $LL pane $L --window worker --lines 30 2>&1 | grep -v '^$' | tail -8 | cut -c1-160
decoy
echo "### down"; $LL down $L 2>&1 | cut -c1-200; echo "down exit=${PIPESTATUS[0]}"
decoy
ls -d $L $D 2>&1 | cut -c1-120
pgrep -fa "$L" | grep -v -e full-fleet -e pgrep | head -5 | cut -c1-160; echo "(end of survivor list)"
