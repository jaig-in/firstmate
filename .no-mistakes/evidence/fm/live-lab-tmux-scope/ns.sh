#!/usr/bin/env bash
# ns.sh <inner-script> [args]: run an inner script in a private mount namespace.
# /tmp is a fresh tmpfs, so the operator's default tmux socket is unreachable.
# $HOME is overlaid, so ~/.claude.json, ~/.treehouse and ~/.pi writes are discarded.
# The real ~/.claude is bound back so a Claude token refresh reaches the real store.
# The inner script runs as the real uid via a nested user namespace.
set -eu
if [ "${1:-}" != --stage2 ]; then
  exec unshare -Urm bash "$0" --stage2 "$(id -u)" "$(id -g)" "$HOME" "$@"
fi
shift; uid=$1 gid=$2 home=$3; shift 3
mount -t tmpfs tmpfs /tmp
mkdir -p /tmp/.ov/up /tmp/.ov/work /tmp/.ov/real
mount --bind "$home" /tmp/.ov/real
mount -t overlay overlay -o "lowerdir=$home,upperdir=/tmp/.ov/up,workdir=/tmp/.ov/work,userxattr" "$home"
mount --bind /tmp/.ov/real/.claude "$home/.claude"
umount -l /tmp/.ov/real
mkdir -p /tmp/ns
chown -R "$uid:$gid" /tmp/ns 2>/dev/null || true
exec unshare -U --map-user="$uid" --map-group="$gid" env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u TMUX -u TMUX_TMPDIR -u TMPDIR -u TMP "$@"
