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

if [ ! -d "$ROOTFS/etc" ] || [ ! -d "$ROOTFS/usr" ]; then
	echo "Refusing: target does not look like an extracted OpenWrt rootfs: $ROOTFS" >&2
	exit 1
fi
ROOTFS=$(CDPATH='' cd -- "$ROOTFS" && pwd)
case "$ROOTFS" in /|/rom|/overlay) echo "Refusing to modify a live root filesystem: $ROOTFS" >&2; exit 1;; esac

register_status() {
	_control=$1
	_pkg=$(sed -n 's/^Package: //p' "$_control" | head -n1)
	[ -n "$_pkg" ] || { echo "Package control has no name: $_control" >&2; exit 1; }
	mkdir -p "$ROOTFS/usr/lib/opkg"
	_status=$ROOTFS/usr/lib/opkg/status
	if [ -f "$_status" ]; then
		awk -v package="$_pkg" 'BEGIN { RS=""; ORS="\n\n" } $0 !~ ("(^|\\n)Package: " package "(\\n|$)") { print }' "$_status" > "$_status.new"
	else : > "$_status.new"; fi
	grep -E '^(Package|Version|Depends|Architecture|Installed-Size):' "$_control" >> "$_status.new" || true
	printf 'Status: install user installed\nInstalled-Time: %s\n\n' "$(date +%s)" >> "$_status.new"
	mv "$_status.new" "$_status"
}

extract_ipk() {
	_ipk=$1
	[ -f "$_ipk" ] || { echo "Dependency package not found: $_ipk" >&2; exit 1; }
	if tar -tzf "$_ipk" >/dev/null 2>&1; then
		_member=$(tar -tzf "$_ipk" | sed -n '\|data\.tar\.|{p;q;}')
		_control_member=$(tar -tzf "$_ipk" | sed -n '\|control\.tar\.|{p;q;}')
		_ipk_data() { tar -xOzf "$_ipk" "$_member"; }
		_ipk_control() { tar -xOzf "$_ipk" "$_control_member"; }
	else
		_member=$(ar t "$_ipk" | sed -n '/^data\.tar\./{p;q;}')
		_control_member=$(ar t "$_ipk" | sed -n '/^control\.tar\./{p;q;}')
		_ipk_data() { ar p "$_ipk" "$_member"; }
		_ipk_control() { ar p "$_ipk" "$_control_member"; }
	fi
	case "$_member" in
		*data.tar.gz) _ipk_data | tar -xzf - -C "$ROOTFS";;
		*data.tar.xz) _ipk_data | tar -xJf - -C "$ROOTFS";;
		*data.tar.zst) _ipk_data | tar --zstd -xf - -C "$ROOTFS";;
		*) echo "Unsupported or invalid IPK: $_ipk" >&2; exit 1;;
	esac
	_control_tmp=$(mktemp)
	case "$_control_member" in
		*control.tar.gz) _ipk_control | tar -xzO ./control > "$_control_tmp";;
		*control.tar.xz) _ipk_control | tar -xJO ./control > "$_control_tmp";;
		*control.tar.zst) _ipk_control | tar --zstd -xO ./control > "$_control_tmp";;
		*) echo "Unsupported control archive: $_ipk" >&2; rm -f "$_control_tmp"; exit 1;;
	esac
	register_status "$_control_tmp"
	rm -f "$_control_tmp"
}

for package in "$@"; do extract_ipk "$package"; done
cp -a "$PROJECT/files/." "$ROOTFS/"
chmod 755 "$ROOTFS/etc/init.d/opencellid" "$ROOTFS/usr/sbin/opencellid-agent" "$ROOTFS/usr/sbin/opencellid-diagnose"
chmod 644 "$ROOTFS/etc/config/opencellid" "$ROOTFS/etc/uci-defaults/99-opencellid"

payload_control=$(mktemp)
version=$(sed -n 's/^PKG_VERSION:=//p' "$PROJECT/Makefile")
release=$(sed -n 's/^PKG_RELEASE:=//p' "$PROJECT/Makefile")
cat > "$payload_control" <<EOF
Package: luci-app-opencellid-mqtt
Version: $version-$release
Depends: libc, luci-base, jsonfilter, uci, uclient-fetch, ca-bundle, mosquitto-client-ssl
Architecture: all
Installed-Size: 64
EOF
register_status "$payload_control"
rm -f "$payload_control"

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
