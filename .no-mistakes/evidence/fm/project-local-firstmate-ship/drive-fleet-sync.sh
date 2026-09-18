#!/usr/bin/env bash
# Live driver: real bin/fm-fleet-sync.sh and bin/fm-projects.sh against sandbox
# org and legacy homes whose projects are clones of local bare origins.
set -u
WT=/home/jb/.no-mistakes/worktrees/9a303e19c024/01M2S7T9502TSF6YEXZFVQ6PC3
SB=$(mktemp -d /tmp/fm-fleet.XXXXXX)
export HOME=$SB/home; mkdir -p "$HOME"
unset FM_HOME FM_ROOT_OVERRIDE FM_PROJECTS_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE
git config --global user.email t@t; git config --global user.name t; git config --global init.defaultBranch master
run() { echo; echo "\$ $*"; "$@" 2>&1; echo "[exit $?]"; }
sec() { echo; echo "=================== $* ==================="; }
mkclone() { # <bare> <dest>: bare origin with one commit, clone it, then advance origin by one commit
  git init -q --bare "$1"; local w; w=$(mktemp -d); git clone -q "$1" "$w/w" 2>/dev/null
  (cd "$w/w" && git commit -q --allow-empty -m c1 && git push -q origin master)
  git clone -q "$1" "$2"
  (cd "$w/w" && git commit -q --allow-empty -m c2 && git push -q origin master)
}
mkdir -p "$SB/origins"

sec "F1 org home: whole-fleet refresh touches registered projects only"
ORG=$SB/org; mkdir -p "$ORG"
mkclone "$SB/origins/alpha.git" "$ORG/alpha"
mkclone "$SB/origins/beta.git" "$ORG/beta"
mkdir "$ORG/notes"
cd "$ORG" && PATH="$SB/bin:$PATH" "$WT/bin/firstmate" init --org
printf -- '- alpha [no-mistakes-prod-only] - registered\n- notes [direct-PR] - plain dir\n- gone [direct-PR] - renamed away\n' > "$ORG/.firstmate/data/projects.md"
export FM_HOME=$ORG/.firstmate
run "$WT/bin/fm-projects.sh" aliases
run "$WT/bin/fm-projects.sh" discover
beta_before=$(git -C "$ORG/beta" rev-parse --short HEAD)
run "$WT/bin/fm-fleet-sync.sh"
echo "beta HEAD before=$beta_before after=$(git -C "$ORG/beta" rev-parse --short HEAD) (unregistered sibling must be untouched)"

sec "F2 org home single-arg: unregistered sibling refused; registered non-repo / stale reported accurately"
run "$WT/bin/fm-fleet-sync.sh" beta
run "$WT/bin/fm-fleet-sync.sh" "$ORG/beta"
run "$WT/bin/fm-fleet-sync.sh" notes
run "$WT/bin/fm-fleet-sync.sh" gone
run "$WT/bin/fm-fleet-sync.sh" alpha
echo "beta HEAD now=$(git -C "$ORG/beta" rev-parse --short HEAD)"

sec "F3 same-named directory in caller's cwd is never touched by an org single-arg refresh"
mkdir -p "$SB/elsewhere" && mkclone "$SB/origins/beta2.git" "$SB/elsewhere/beta"
cd "$SB/elsewhere"; b=$(git -C beta rev-parse --short HEAD)
run "$WT/bin/fm-fleet-sync.sh" beta
echo "cwd ./beta HEAD before=$b after=$(git -C beta rev-parse --short HEAD)"

sec "F4 malformed data/project-paths.json fails closed with an error: line"
echo '{"alpha": "relative/path"}' > "$FM_HOME/data/project-paths.json"
run "$WT/bin/fm-fleet-sync.sh"
echo '[1,2]' > "$FM_HOME/data/project-paths.json"
run "$WT/bin/fm-fleet-sync.sh"
rm "$FM_HOME/data/project-paths.json"

sec "F5 legacy home (no projects-root): manifest bare alias keeps its label and local-only guard"
LEG=$SB/legacy; mkdir -p "$LEG/data" "$LEG/projects"
mkclone "$SB/origins/ext.git" "$SB/outside/ext"
printf -- '- ext [local-only] - external project\n' > "$LEG/data/projects.md"
printf '{"ext": "%s"}\n' "$SB/outside/ext" > "$LEG/data/project-paths.json"
export FM_HOME=$LEG
e=$(git -C "$SB/outside/ext" rev-parse --short HEAD)
run "$WT/bin/fm-projects.sh" resolve ext
run "$WT/bin/fm-fleet-sync.sh" ext
echo "ext HEAD before=$e after=$(git -C "$SB/outside/ext" rev-parse --short HEAD) (local-only must not fast-forward)"
echo "SANDBOX=$SB"
