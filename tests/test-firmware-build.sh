#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
grep -q 'supported_devices.*ZLAN,zlan-cat1' "$ROOT/scripts/build-zlan-sysupgrade.sh"
grep -q 'PARTITION_SIZE=.*0x00fb0000' "$ROOT/scripts/build-zlan-sysupgrade.sh"
grep -q 'mksquashfs.*ROOTFS' "$ROOT/scripts/build-zlan-sysupgrade.sh"
grep -q 'FWTOOL.*-I' "$ROOT/scripts/build-zlan-sysupgrade.sh"
grep -q 'cmp -s.*METADATA' "$ROOT/scripts/build-zlan-sysupgrade.sh"
echo "firmware build guard test: OK"
