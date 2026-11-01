#!/usr/bin/env bash
# up --worker on HEAD, then show why the gated worker's treehouse get did not enter a worktree.
set -u
WT=$1; cd "$WT"
U=$(id -u); LL=bin/fm-live-lab.sh; L=/tmp/ns/fmw1
tmux -f /dev/null new-session -d -s firstmate -n main "exec sleep 3000"
DEF=/tmp/tmux-$U/default; DP=$(tmux -S $DEF display-message -p '#{pid}')
cleanup() { [ ! -f $L/.fm-live-lab ] || timeout 120 $LL down $L 2>&1 | tail -3; timeout 5 tmux -S $DEF kill-server 2>/dev/null; kill -9 $DP 2>/dev/null; }
trap cleanup EXIT
timeout 300 $LL up --harness claude --worker --timeout 240 $L 2>&1 | cut -c1-300; echo "up exit=${PIPESTATUS[0]}"
D=$(sed -n 's/^tmux_dir=//p' $L/.fm-live-lab); S=$D/tmux-$U/default
tmux -S $S list-windows -a -F '#{window_name} cmd=#{pane_current_command} path=#{pane_current_path}'
W=$(tmux -S $S list-windows -a -F '#{window_name}' | grep worker)
echo "--- worker pane"; tmux -S $S capture-pane -p -S -60 -t firstmate:=$W | cut -c1-200 | grep -v '^$' | tail -40
echo "--- env in pane"; tmux -S $S show-environment -t firstmate 2>/dev/null | grep -E '^(SHELL|PATH|HOME|TREEHOUSE|TMUX_TMPDIR)' | cut -c1-200
echo "--- status file"; ls -la $L/home/state/ | head -20
echo "--- direct treehouse get from the project"
(cd $L/home/projects/notes && TREEHOUSE_ROOT=$L/treehouse timeout 30 treehouse get --lease --lease-holder diag 2>&1 | tail -5; echo "rc=${PIPESTATUS[0]}"; git -C . worktree list | head; cat treehouse.toml 2>/dev/null | head -20)
