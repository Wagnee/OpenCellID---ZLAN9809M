#!/bin/sh
set -eu

usage() {
	echo "Usage: $0 <kernel.uImage> <rootfs-directory> <fwtool> <output.bin>" >&2
	exit 2
}

[ "$#" -eq 4 ] || usage
KERNEL=$1
ROOTFS=$2
FWTOOL=$3
OUTPUT=$4

PARTITION_SIZE=$((0x00fb0000))
BLOCK_SIZE=262144
OUTPUT_DIR=$(CDPATH='' cd -- "$(dirname "$OUTPUT")" && pwd)
OUTPUT=$OUTPUT_DIR/$(basename "$OUTPUT")
WORK=$(mktemp -d "$OUTPUT_DIR/.zlan-firmware.XXXXXX")
trap 'rm -rf "$WORK"' EXIT INT TERM

[ -f "$KERNEL" ] || { echo "Kernel image not found: $KERNEL" >&2; exit 1; }
[ -d "$ROOTFS/etc" ] && [ -d "$ROOTFS/usr" ] || {
	echo "Rootfs directory is invalid: $ROOTFS" >&2
	exit 1
}
[ -x "$FWTOOL" ] || { echo "fwtool is not executable: $FWTOOL" >&2; exit 1; }
command -v mksquashfs >/dev/null || { echo "mksquashfs is required" >&2; exit 1; }

ROOTFS_IMAGE=$WORK/rootfs.squashfs
METADATA=$WORK/metadata.json
CANDIDATE=$WORK/sysupgrade.bin

mksquashfs "$ROOTFS" "$ROOTFS_IMAGE" \
	-noappend -all-root -no-progress -comp xz -b "$BLOCK_SIZE" -no-xattrs

cat "$KERNEL" "$ROOTFS_IMAGE" > "$CANDIDATE"
cat > "$METADATA" <<'EOF'
{"metadata_version":"1.1","compat_version":"1.0","supported_devices":["ZLAN,zlan-cat1"],"version":{"dist":"OpenWrt","version":"21.02.0","revision":"r16279-5cc0535800+opencellid-1.1.4","target":"ramips/mt76x8","board":"ZLAN,zlan-cat1"}}
EOF
"$FWTOOL" -I "$METADATA" "$CANDIDATE"

SIZE=$(wc -c < "$CANDIDATE" | tr -d ' ')
if [ "$SIZE" -gt "$PARTITION_SIZE" ]; then
	echo "Firmware is too large: $SIZE bytes (partition: $PARTITION_SIZE bytes)" >&2
	exit 1
fi

mv "$CANDIDATE" "$OUTPUT"
cp "$ROOTFS_IMAGE" "$OUTPUT.rootfs.squashfs"
"$FWTOOL" -i "$WORK/extracted-metadata.json" "$OUTPUT"
cmp -s "$METADATA" "$WORK/extracted-metadata.json" || {
	echo "Firmware metadata verification failed" >&2
	exit 1
}

echo "Firmware: $OUTPUT"
echo "Size: $SIZE bytes"
echo "Partition headroom: $((PARTITION_SIZE - SIZE)) bytes"
sha256sum "$OUTPUT" "$OUTPUT.rootfs.squashfs"
