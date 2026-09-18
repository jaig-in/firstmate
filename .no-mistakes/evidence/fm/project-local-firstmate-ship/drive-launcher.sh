#!/usr/bin/env bash
# Live driver: installs bin/firstmate by symlink onto a sandbox PATH (the documented
# install), with a sandbox $HOME, and drives init / launch / harness selection.
set -u
WT=/home/jb/.no-mistakes/worktrees/9a303e19c024/01M2S7T9502TSF6YEXZFVQ6PC3
SB=$(mktemp -d /tmp/fm-live.XXXXXX)
export HOME=$SB/home; mkdir -p "$HOME" "$SB/bin" "$SB/rec"
unset FM_HOME FM_PI_HARNESS FM_OMP_HARNESS FM_ROOT_OVERRIDE FM_LAUNCH_DIR
ln -s "$WT/bin/firstmate" "$SB/bin/firstmate"
# Recorder harnesses: stand in for pi / pi-signed / omp so the exec'd process's
# environment and cwd can be observed. Real claude/codex/pi stay on PATH after.
for h in pi pi-signed omp kimi; do
cat > "$SB/rec/$h" <<R
#!/usr/bin/env bash
echo "[exec'd \$(basename "\$0")] cwd=\$(pwd -P) args=\$*"
echo "  FM_HOME=\${FM_HOME:-} FM_LAUNCH_DIR=\${FM_LAUNCH_DIR:-} FM_ROOT_OVERRIDE=\${FM_ROOT_OVERRIDE:-}"
echo "  FM_PI_HARNESS=\${FM_PI_HARNESS:-<unset>} FM_OMP_HARNESS=\${FM_OMP_HARNESS:-<unset>}"
if [ "\$(basename "\$0")" != omp ]; then echo "  fm-harness.sh (PI_CODING_AGENT=true) => \$(PI_CODING_AGENT=true bin/fm-harness.sh 2>&1)"; fi
R
chmod +x "$SB/rec/$h"; done
export PATH="$SB/bin:$PATH"
REC_PATH="$SB/rec:$PATH"
git config --global user.email t@t 2>/dev/null; git config --global user.name t 2>/dev/null
run() { echo; echo "\$ $*"; "$@" 2>&1; echo "[exit $?]"; }
sec() { echo; echo "=================== $* ==================="; }

sec "S1 firstmate init in a git repo (per-project home)"
mkdir -p "$SB/work/app/src" && git -C "$SB/work/app" init -q -b master && (cd "$SB/work/app" && git commit -q --allow-empty -m init)
cd "$SB/work/app/src"
run firstmate init
run find "$SB/work/app/.firstmate" -maxdepth 2
run cat "$SB/work/app/.firstmate/data/projects.md"
run cat "$SB/work/app/.firstmate/config/projects-root"
run git -C "$SB/work/app" status --porcelain --ignored
run firstmate init

sec "S2 launch from a subdir resolves nearest home (real claude, --version passthrough)"
run firstmate --harness claude --version
PATH=$REC_PATH run firstmate --harness pi --flag-for-harness x

sec "S3 repo without a .firstmate refuses to guess"
mkdir -p "$SB/work/other" && git -C "$SB/work/other" init -q -b master
cd "$SB/work/other"
PATH=$REC_PATH run firstmate --harness pi
sec "S3b --global in that repo, and a non-repo cwd, fall back to global home"
PATH=$REC_PATH run firstmate --global --harness pi
mkdir -p "$HOME/.firstmate" "$SB/plain"; cd "$SB/plain"
PATH=$REC_PATH run firstmate --harness pi

sec "S4 trust marker: missing, tracked (committed with clone), symlinked"
mkdir -p "$SB/work/cloned" && cd "$SB/work/cloned" && git init -q -b master
mkdir -p .firstmate/config && echo kimi > .firstmate/config/primary-harness
PATH=$REC_PATH run firstmate
touch .firstmate/.fm-home && git add -f .firstmate && git commit -q -m 'committed home'
PATH=$REC_PATH run firstmate
git rm -q --cached .firstmate/.fm-home && rm .firstmate/.fm-home && ln -s /dev/null .firstmate/.fm-home
PATH=$REC_PATH run firstmate

sec "S5 config/primary-harness selection and whitelist"
H="$SB/work/app/.firstmate"; cd "$SB/work/app"
echo omp > "$H/config/primary-harness";   PATH=$REC_PATH run firstmate
echo pi-signed > "$H/config/primary-harness"; PATH=$REC_PATH run firstmate
echo kimi > "$H/config/primary-harness";  PATH=$REC_PATH run firstmate
echo 'rm' > "$H/config/primary-harness";  PATH=$REC_PATH run firstmate
echo gemini > "$H/config/primary-harness"; PATH=$REC_PATH run firstmate
rm "$H/config/primary-harness"; echo pi > "$SB/ph"; ln -s "$SB/ph" "$H/config/primary-harness"; PATH=$REC_PATH run firstmate
rm "$H/config/primary-harness"

sec "S6 --harness flag held to the same primary-capable set"
PATH=$REC_PATH run firstmate --harness kimi
PATH=$REC_PATH run firstmate --harness=kimi
PATH=$REC_PATH run firstmate --harness bash -c 'echo pwned'
PATH=$REC_PATH run firstmate --harness=/bin/sh
echo kimi > "$H/config/primary-harness"; PATH=$REC_PATH run firstmate --harness pi; rm "$H/config/primary-harness"

sec "S7 pi / pi-signed / omp identity markers set per launch"
PATH=$REC_PATH run firstmate --harness pi-signed
PATH=$REC_PATH FM_PI_HARNESS=pi-signed run firstmate --harness pi
PATH=$REC_PATH run firstmate --harness=omp
run firstmate --harness pi --version

sec "S8 explicit FM_HOME wins; relative FM_HOME canonicalized"
mkdir -p "$SB/explicit"; cd "$SB/work/app/src"
PATH=$REC_PATH FM_HOME=../../../explicit run firstmate --harness pi

sec "S9 firstmate init --org lists discoverable siblings without registering them"
mkdir -p "$SB/org" && cd "$SB/org"
for p in alpha beta; do git init -q -b master "$p"; done; mkdir notrepo
run firstmate init --org
run cat "$SB/org/.firstmate/data/projects.md"
run env FM_HOME="$SB/org/.firstmate" "$WT/bin/fm-projects.sh" discover
run env FM_HOME="$SB/org/.firstmate" "$WT/bin/fm-projects.sh" root
echo "SANDBOX=$SB"
