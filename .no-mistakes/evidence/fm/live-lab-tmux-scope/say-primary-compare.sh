#!/usr/bin/env bash
# Primary-only lab: pane before/after say, from BASE and from HEAD.
set -u
WT=$1; BASE=$2; cd "$WT"
U=$(id -u); mkdir -p /tmp/ns/base; git archive "$BASE" | tar -x -C /tmp/ns/base
run() { local label=$1 ll=$2 L=$3; shift 3
  echo "=================== $label"
  $ll up --harness claude --timeout 200 "$@" $L 2>&1 | grep -E '^(ready|fail|tree)' | cut -c1-120; echo "up exit=${PIPESTATUS[0]}"
  echo "--- before say"; $ll pane $L --lines 40 2>&1 | grep -v '^$' | tail -8 | cut -c1-130
  $ll say $L "Run no tool. Reply with only the word SAYECHO, a hyphen, and then 77321, with no spaces."; echo "say exit=$?"
  for i in $(seq 1 18); do $ll pane $L --lines 300 2>/dev/null | grep -q '^[^a-z]*SAYECHO-77321' && break; sleep 5; done
  echo "$label waited $((i*5))s"; echo "--- after say"; $ll pane $L --lines 40 2>&1 | grep -v '^$' | tail -12 | cut -c1-130
  $ll down $L 2>&1 | tail -1 | cut -c1-100
}
run BASE /tmp/ns/base/bin/fm-live-lab.sh /tmp/ns/sb --source "$WT" --ref "$BASE"
run HEAD bin/fm-live-lab.sh /tmp/ns/sh
