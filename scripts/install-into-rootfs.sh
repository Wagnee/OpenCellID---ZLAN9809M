#!/bin/sh
set -eu

usage() {
	echo "Usage: $0 <extracted-rootfs> [dependency.ipk ...]" >&2
	exit 2
}

[ "$#" -ge 1 ] || usage
ROOTFS=$1
shift
PROJECT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)

[ -d "$ROOTFS/etc" ] && [ -d "$ROOTFS/usr" ] || {
	echo "Refusing: target does not look like an extracted OpenWrt rootfs: $ROOTFS" >&2
	exit 1
}
ROOTFS=$(CDPATH='' cd -- "$ROOTFS" && pwd)
case "$ROOTFS" in /|/rom|/overlay) echo "Refusing to modify a live root filesystem: $ROOTFS" >&2; exit 1;; esac

extract_ipk() {
	_ipk=$1
	[ -f "$_ipk" ] || { echo "Dependency package not found: $_ipk" >&2; exit 1; }
	_member=$(ar t "$_ipk" | sed -n '/^data\.tar\./{p;q;}')
	case "$_member" in
		data.tar.gz) ar p "$_ipk" "$_member" | tar -xzf - -C "$ROOTFS";;
		data.tar.xz) ar p "$_ipk" "$_member" | tar -xJf - -C "$ROOTFS";;
		data.tar.zst) ar p "$_ipk" "$_member" | tar --zstd -xf - -C "$ROOTFS";;
		*) echo "Unsupported or invalid IPK: $_ipk" >&2; exit 1;;
	esac
}

for package in "$@"; do extract_ipk "$package"; done
cp -a "$PROJECT/files/." "$ROOTFS/"
chmod 755 "$ROOTFS/etc/init.d/opencellid" "$ROOTFS/usr/sbin/opencellid-agent" "$ROOTFS/usr/sbin/opencellid-diagnose"
chmod 644 "$ROOTFS/etc/config/opencellid" "$ROOTFS/etc/uci-defaults/99-opencellid"

missing=''
for command in uci jsonfilter uclient-fetch mosquitto_pub; do
	find "$ROOTFS" -type f -name "$command" -perm /111 -print -quit 2>/dev/null | grep -q . || missing="$missing $command"
done
[ -z "$missing" ] || {
	echo "Rootfs injected, but required executables are missing:$missing" >&2
	echo "Pass the matching OpenWrt 21.02.0 mipsel_24kc dependency IPKs to this script." >&2
	exit 1
}

echo "OpenCellID factory payload installed into: $ROOTFS"
echo "Defaults will be recreated after every jffs2 factory reset. Secrets were not embedded."

