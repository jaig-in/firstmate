#!/usr/bin/env bash
# Live drive of the project-local firstmate launcher and fleet scripts in a
# throwaway sandbox (HOME, repos, and harness stubs all under a mktemp dir).
set -u
WT=/home/jb/.no-mistakes/worktrees/9a303e19c024/01M2TDM6HS7N0AE32D126A35TZ
SB=$(mktemp -d /tmp/fm-live.XXXXXX)
export HOME="$SB/home"; mkdir -p "$HOME"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL="$SB/gitconfig"; git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch master
unset FM_HOME FM_ROOT_OVERRIDE FM_PROJECTS_OVERRIDE FM_LAUNCH_DIR FM_PI_HARNESS FM_OMP_HARNESS
BIN="$SB/bin"; mkdir -p "$BIN"
ln -s "$WT/bin/firstmate" "$BIN/firstmate"   # installed the way users install it: a PATH symlink
for h in claude pi-signed kimi sh-evil; do
  cat > "$BIN/$h" <<SH
#!/usr/bin/env bash
echo "[harness $h] FM_HOME=\$FM_HOME"
echo "[harness $h] FM_LAUNCH_DIR=\$FM_LAUNCH_DIR"
echo "[harness $h] cwd=\$(pwd -P)"
echo "[harness $h] FM_PI_HARNESS=\${FM_PI_HARNESS:-<unset>} args=\$*"
SH
  chmod +x "$BIN/$h"
done
export PATH="$BIN:$PATH"
run() { echo; echo "\$ (cd ${PWD/#$SB/\$SB}) $*"; "$@" 2>&1 | sed "s#$SB#\$SB#g; s#$WT#\$WT#g"; echo "[exit ${PIPESTATUS[0]}]"; }
hdr() { echo; echo "=================== $* ==================="; }

hdr "S1 per-project init in a repo"
mkdir -p "$SB/work/app/src/deep"; cd "$SB/work/app"; git init -q -b master; git commit -q --allow-empty -m init
run firstmate init
run git status --porcelain --untracked-files=all
echo "(empty porcelain above = enclosing repo left clean)"
run cat .firstmate/data/projects.md
run cat .firstmate/config/projects-root

hdr "S2 launch from a subdirectory resolves the per-project home"
cd "$SB/work/app/src/deep"; run firstmate --resume abc

hdr "S3 repo with no home refuses to guess"
mkdir -p "$SB/work/other"; cd "$SB/work/other"; git init -q -b master; run firstmate

hdr "S4 outside any repo falls back to the global home"
mkdir -p "$HOME/.firstmate" "$SB/plain"; cd "$SB/plain"; run firstmate
cd "$SB/work/other"; run firstmate --global

hdr "S5 adversarial: committed .firstmate with tracked trust marker is refused"
mkdir -p "$SB/work/hostile"; cd "$SB/work/hostile"; git init -q -b master
mkdir -p .firstmate/config; : > .firstmate/.fm-home; echo sh-evil > .firstmate/config/primary-harness
git add -f .firstmate; git commit -q -m "ship a home"
run firstmate

hdr "S6 adversarial: harness whitelist (config and --harness)"
cd "$SB/work/app"
echo sh-evil > .firstmate/config/primary-harness; run firstmate
echo kimi > .firstmate/config/primary-harness; run firstmate
rm .firstmate/config/primary-harness; run firstmate --harness kimi
ln -s /etc/hostname .firstmate/config/primary-harness; run firstmate; rm .firstmate/config/primary-harness

hdr "S7 pi-signed primary gets its identity marker; a stale shell marker cannot relabel"
echo pi-signed > .firstmate/config/primary-harness; run firstmate; rm .firstmate/config/primary-harness
run env FM_PI_HARNESS=pi-signed firstmate --harness claude

hdr "S8 org home: init --org, discovery is not authority, refresh only registered"
mkdir -p "$SB/up"; git init -q --bare -b master "$SB/up/api.git"; git init -q --bare -b master "$SB/up/web.git"
mkdir -p "$SB/org"
for p in api web; do git clone -q "$SB/up/$p.git" "$SB/org/$p" 2>/dev/null; (cd "$SB/org/$p" && git commit -q --allow-empty -m c1 && git push -q origin master); done
for p in api web; do git clone -q "$SB/up/$p.git" "$SB/seedpush-$p" && (cd "$SB/seedpush-$p" && git commit -q --allow-empty -m "upstream c2" && git push -q origin master); done
cd "$SB/org"; run firstmate init --org
printf -- '- api [direct-PR] - registered\n' > .firstmate/data/projects.md
run env FM_HOME="$SB/org/.firstmate" "$WT/bin/fm-projects.sh" discover
run env FM_HOME="$SB/org/.firstmate" "$WT/bin/fm-projects.sh" aliases
run env FM_HOME="$SB/org/.firstmate" "$WT/bin/fm-projects.sh" resolve api
echo "before: api=$(git -C api log -1 --format=%s) web=$(git -C web log -1 --format=%s)"
run env FM_HOME="$SB/org/.firstmate" "$WT/bin/fm-fleet-sync.sh"
echo "after:  api=$(git -C api log -1 --format=%s) web=$(git -C web log -1 --format=%s)"
run env FM_HOME="$SB/org/.firstmate" "$WT/bin/fm-fleet-sync.sh" web
mkdir -p notes; printf -- '- api [direct-PR]\n- notes [direct-PR]\n' > .firstmate/data/projects.md
run env FM_HOME="$SB/org/.firstmate" "$WT/bin/fm-fleet-sync.sh" notes
cd "$SB/org/web"; run firstmate

hdr "S9 malformed config/projects-root: snapshot, home-summary refresh, bootstrap survive"
MH="$SB/malformed"; mkdir -p "$MH/config" "$MH/data" "$MH/state"; printf 'a\nb\n' > "$MH/config/projects-root"
run env FM_HOME="$MH" "$WT/bin/fm-fleet-sync.sh"
echo "\$ FM_HOME=\$SB/malformed fm-fleet-snapshot.sh --json | jq '{schema, projects: .roots.projects, backlog_type: (.backlog|type)}'"
FM_HOME="$MH" "$WT/bin/fm-fleet-snapshot.sh" --json 2>&1 | jq '{schema, projects: .roots.projects, backlog_type: (.backlog|type)}'; echo "[exit ${PIPESTATUS[0]}]"
run env FM_HOME="$MH" "$WT/bin/fm-home-summary-refresh.sh" --best-effort
run ls -a "$MH/state"
[ -f "$MH/state/home-summary.json" ] && { echo "\$ jq keys state/home-summary.json"; jq -c 'keys' "$MH/state/home-summary.json"; }
[ -f "$MH/state/.home-summary-refresh.log" ] && run cat "$MH/state/.home-summary-refresh.log"
echo "\$ FM_HOME=\$SB/malformed FM_BOOTSTRAP_NETWORK=skip fm-bootstrap.sh | grep -E 'FLEET_SYNC|error'"
FM_HOME="$MH" FM_BOOTSTRAP_NETWORK=skip timeout 120 "$WT/bin/fm-bootstrap.sh" 2>&1 | sed "s#$SB#\$SB#g" | grep -E 'FLEET_SYNC|^error|projects-root'; echo "[bootstrap exit ${PIPESTATUS[0]}]"

hdr "S10 session-start digest shows the launch directory"
echo "\$ FM_HOME=\$SB/work/app/.firstmate FM_LAUNCH_DIR=\$SB/work/app/src/deep fm-session-start.sh | head"
FM_HOME="$SB/work/app/.firstmate" FM_ROOT_OVERRIDE="$WT" FM_LAUNCH_DIR="$SB/work/app/src/deep" timeout 180 "$WT/bin/fm-session-start.sh" 2>&1 | sed "s#$SB#\$SB#g; s#$WT#\$WT#g" | head -8
echo "SANDBOX=$SB"
