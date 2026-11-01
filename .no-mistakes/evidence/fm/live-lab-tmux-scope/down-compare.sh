#!/usr/bin/env bash
# Real marked Claude lab; its tmux directory vanishes; down from BASE and from HEAD.
set -u
WT=$1; BASE=$2; cd "$WT"
U=$(id -u); DEF=/tmp/tmux-$U/default
mkdir -p /tmp/ns/base; git archive "$BASE" | tar -x -C /tmp/ns/base
decoy_up() { tmux -f /dev/null new-session -d -s firstmate -n main "exec sleep 3000"; DP=$(tmux -S $DEF display-message -p '#{pid}'); echo "decoy pid $DP on $DEF"; }
decoy_down() { [ ! -S $DEF ] || timeout 5 tmux -S $DEF kill-server 2>/dev/null; kill -9 ${DP:-0} 2>/dev/null; rm -f $DEF; true; }
trap decoy_down EXIT
run() { # <label> <script> <lab> [up args]
  local label=$1 ll=$2 L=$3; shift 3
  echo "=================== $label"
  decoy_up
  $ll up --harness claude --timeout 240 "$@" $L 2>&1 | cut -c1-160 | grep -E '^(ready|tree|fail|fm-live)' ; echo "up exit=${PIPESTATUS[0]}"
  D=$(sed -n 's/^tmux_dir=//p' $L/.fm-live-lab); S=$D/tmux-$U/default
  echo "marker present: $([ -f $L/home/.fm-lab-home ] && echo yes || echo no)"
  tmux -S $S kill-server; sleep 1; rm -rf "$D"; ls -d $D 2>&1 | cut -c1-100
  echo "--- down"; $ll down $L 2>&1 | cut -c1-200; echo "down exit=${PIPESTATUS[0]}"; sleep 0.5
  if kill -0 $DP 2>/dev/null; then echo "$label: decoy default server SURVIVED"; else echo "$label: decoy default server KILLED by down"; fi
  echo "lab root still present: $([ -e $L ] && echo yes || echo no); trust entries left in overlaid store: $(node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.HOME+"/.claude.json"));console.log(Object.keys(j.projects).filter(k=>k.startsWith(process.argv[1])).length)' $L)"
  echo "--- retry down"; $ll down $L 2>&1 | cut -c1-200; echo "retry exit=${PIPESTATUS[0]}"
  echo "--- operator recovery: recreate the recorded empty 0700 directory, retry"
  mkdir -m 700 "$D"; $ll down $L 2>&1 | cut -c1-200; echo "recovery exit=${PIPESTATUS[0]}"; ls -d $L 2>&1 | cut -c1-100
  decoy_down
}
run BASE /tmp/ns/base/bin/fm-live-lab.sh /tmp/ns/labb --source "$WT" --ref "$BASE"
run HEAD bin/fm-live-lab.sh /tmp/ns/labh
