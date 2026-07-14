#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
VERSION=$(sed -n 's/^PKG_VERSION:=//p' "$ROOT/Makefile")
RELEASE=$(sed -n 's/^PKG_RELEASE:=//p' "$ROOT/Makefile")
NAME=luci-app-opencellid-mqtt
WORK=${TMPDIR:-/tmp}/${NAME}-$$
OUT=${1:-$ROOT/bin}
trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/control" "$WORK/data" "$OUT"
cp -a "$ROOT/files/." "$WORK/data/"
chmod 755 "$WORK/data/etc/init.d/opencellid" "$WORK/data/usr/sbin/opencellid-agent" "$WORK/data/usr/sbin/opencellid-diagnose"
chmod 600 "$WORK/data/etc/config/opencellid"
chmod 644 "$WORK/data/etc/uci-defaults/99-opencellid" "$WORK/data/usr/lib/lua/luci/controller/opencellid.lua" "$WORK/data/usr/lib/lua/luci/model/cbi/opencellid.lua"
size=$(du -sk "$WORK/data" | awk '{print $1}')
cat > "$WORK/control/control" <<EOF
Package: $NAME
Version: $VERSION-$RELEASE
Architecture: all
Maintainer: Wagnee
Depends: libc, luci-base, jsonfilter, uci, uclient-fetch, ca-bundle, mosquitto-client-ssl
Section: luci
Priority: optional
Installed-Size: $size
Description: Lightweight OpenCellID location, reverse geocoding and MQTT service for ZLAN9809M.
EOF
cat > "$WORK/control/conffiles" <<'EOF'
/etc/config/opencellid
EOF
cat > "$WORK/control/postinst" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT:-}" ] || { /etc/init.d/opencellid enable; /etc/init.d/rpcd restart; /etc/init.d/uhttpd restart; }
exit 0
EOF
chmod 755 "$WORK/control/postinst"
printf '2.0\n' > "$WORK/debian-binary"
(cd "$WORK/control" && tar --format=gnu --owner=0 --group=0 --numeric-owner -czf "$WORK/control.tar.gz" .)
(cd "$WORK/data" && tar --format=gnu --owner=0 --group=0 --numeric-owner -czf "$WORK/data.tar.gz" .)
(cd "$WORK" && tar --format=gnu --owner=0 --group=0 --numeric-owner -czf "$OUT/${NAME}_${VERSION}-${RELEASE}_all.ipk" ./debian-binary ./control.tar.gz ./data.tar.gz)
echo "$OUT/${NAME}_${VERSION}-${RELEASE}_all.ipk"
