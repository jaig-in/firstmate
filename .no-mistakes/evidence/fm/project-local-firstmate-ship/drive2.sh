#!/usr/bin/env bash
# Follow-up live drive: bootstrap network phase on a malformed projects-root
# home, and the pi identity marker overriding a stale shell export.
set -u
WT=/home/jb/.no-mistakes/worktrees/9a303e19c024/01M2TDM6HS7N0AE32D126A35TZ
SB=$(mktemp -d /tmp/fm-live2.XXXXXX)
export HOME="$SB/home"; mkdir -p "$HOME"
unset FM_HOME FM_ROOT_OVERRIDE FM_PROJECTS_OVERRIDE FM_LAUNCH_DIR FM_PI_HARNESS CLAUDECODE CLAUDE_CODE_ENTRYPOINT
MH="$SB/malformed"; mkdir -p "$MH/config" "$MH/data" "$MH/state"; printf 'a\nb\n' > "$MH/config/projects-root"
echo "\$ printf 'a\\nb\\n' > \$SB/malformed/config/projects-root"
echo "\$ FM_HOME=\$SB/malformed FM_BOOTSTRAP_NETWORK=only fm-bootstrap.sh   (network phase, where fleet_sync runs)"
FM_HOME="$MH" FM_BOOTSTRAP_NETWORK=only timeout 300 "$WT/bin/fm-bootstrap.sh" 2>&1 | sed "s#$SB#\$SB#g"; echo "[exit ${PIPESTATUS[0]}]"
echo
echo "\$ FM_HOME=\$SB/malformed fm-bootstrap.sh lavish-compatible"
FM_HOME="$MH" timeout 60 "$WT/bin/fm-bootstrap.sh" lavish-compatible 2>&1 | sed "s#$SB#\$SB#g"; echo "[exit ${PIPESTATUS[0]}]"
echo
BIN="$SB/bin"; mkdir -p "$BIN"; ln -s "$WT/bin/firstmate" "$BIN/firstmate"
cat > "$BIN/pi" <<'SH'
#!/usr/bin/env bash
echo "[harness pi] FM_PI_HARNESS=$FM_PI_HARNESS"
SH
chmod +x "$BIN/pi"
mkdir -p "$SB/plain"; mkdir -p "$HOME/.firstmate"; cd "$SB/plain"
echo "\$ FM_PI_HARNESS=pi-signed firstmate --harness pi   (stale signed marker exported in the shell)"
PATH="$BIN:$PATH" FM_PI_HARNESS=pi-signed firstmate --harness pi 2>&1; echo "[exit $?]"
