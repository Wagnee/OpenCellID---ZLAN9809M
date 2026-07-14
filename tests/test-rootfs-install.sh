#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/opencellid-rootfs-test-$$
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP/rootfs/etc" "$TMP/rootfs/usr/bin" "$TMP/rootfs/usr/sbin"
for command in uci jsonfilter uclient-fetch; do printf '#!/bin/sh\n' > "$TMP/rootfs/usr/bin/$command"; chmod 755 "$TMP/rootfs/usr/bin/$command"; done
printf '#!/bin/sh\n' > "$TMP/rootfs/usr/bin/mosquitto_pub"; chmod 755 "$TMP/rootfs/usr/bin/mosquitto_pub"

sh "$ROOT/scripts/install-into-rootfs.sh" "$TMP/rootfs"
test -x "$TMP/rootfs/usr/sbin/opencellid-agent"
test -f "$TMP/rootfs/etc/uci-defaults/99-opencellid"
grep -q 'set_default enabled 0' "$TMP/rootfs/etc/uci-defaults/99-opencellid"
grep -q '/etc/init.d/opencellid enable' "$TMP/rootfs/etc/uci-defaults/99-opencellid"
grep -q '^Package: luci-app-opencellid-mqtt$' "$TMP/rootfs/usr/lib/opkg/status"
echo "rootfs persistence install test: OK"
