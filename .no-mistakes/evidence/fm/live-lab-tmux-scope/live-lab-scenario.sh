#!/usr/bin/env bash
# Runs inside: unshare -Ucm sh -c 'mount -t tmpfs tmpfs /tmp && exec bash <this>'
set -u
cd "$1"
U=$(id -u); DEF=/tmp/tmux-$U/default
unset TMUX TMUX_TMPDIR
echo "== private /tmp contents before: [$(ls -A /tmp)]"
mkdir -m 700 /tmp/tmux-$U; tmux -S "$DEF" -f /dev/null new-session -d -s decoy 'sleep 900'
DECOY=$(tmux -S "$DEF" display-message -p '#{pid}')
echo "== decoy default server pid=$DECOY socket=$DEF"
decoy() { if kill -0 "$DECOY" 2>/dev/null && tmux -S "$DEF" has-session -t decoy 2>/dev/null; then echo "decoy ALIVE ($1)"; else echo "decoy GONE ($1)"; fi; }

echo; echo "######## Scenario A: up/check/down with decoy default server"
A=/tmp/fmlab-A
bin/fm-live-lab.sh up --harness claude --timeout 300 "$A"; echo "up exit=$?"
TD=$(sed -n 's/^tmux_dir=//p' "$A"/.fm-live-lab* 2>/dev/null | head -1); echo "lab tmux_dir=$TD"
ls -la "$TD/tmux-$U" 2>&1
tmux -S "$TD/tmux-$U/default" list-windows -t firstmate 2>&1
decoy "after up A"
bin/fm-live-lab.sh down "$A"; echo "down exit=$?"
decoy "after down A"
[ -e "$A" ] && echo "lab A root still exists" || echo "lab A root removed"
[ -S "$TD/tmux-$U/default" ] && echo "lab A socket still exists" || echo "lab A socket gone"

echo; echo "######## Scenario B: lab tmux directory removed before down"
B=/tmp/fmlab-B
bin/fm-live-lab.sh up --harness claude --timeout 300 "$B"; echo "up exit=$?"
TD=$(sed -n 's/^tmux_dir=//p' "$B"/.fm-live-lab* 2>/dev/null | head -1); echo "lab tmux_dir=$TD"
LABSRV=$(tmux -S "$TD/tmux-$U/default" display-message -p '#{pid}'); echo "lab server pid=$LABSRV"
decoy "after up B"
rm -rf "$TD"; echo "removed lab tmux dir $TD"
bin/fm-live-lab.sh down "$B"; echo "down#1 exit=$?"
decoy "after down#1 B (tmux dir missing)"
kill -0 "$LABSRV" 2>/dev/null && echo "lab server STILL RUNNING" || echo "lab server stopped"
mkdir -m 700 "$TD"; bin/fm-live-lab.sh down "$B"; echo "down#2 exit=$?"
decoy "after down#2 B"
[ -e "$B" ] && echo "lab B root still exists" || echo "lab B root removed"

echo; echo "== final: stopping decoy on its explicit socket"
tmux -S "$DEF" kill-server
ps -eo pid,args | grep -E "fmlab-|tmux -S /tmp" | grep -v grep || echo "no lab tmux/claude processes left"
