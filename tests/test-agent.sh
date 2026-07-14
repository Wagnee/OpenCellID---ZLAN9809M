#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/opencellid-test-$$
mkdir -p "$TMP/bin"
trap 'rm -rf "$TMP" /tmp/opencellid-state.json /tmp/opencellid-response.*' EXIT INT TERM

cat > "$TMP/bin/uci" <<'EOF'
#!/bin/sh
key=${3##*.}
case "$key" in
manual_mcc) echo 724;; manual_mnc) echo 5;; manual_lac) echo 12345;; manual_cid) echo 67890;; manual_radio) echo LTE;;
cell_source) echo manual;; opencellid_key) echo test-key;; opencellid_url) echo https://example.test/cell/get;;
reverse_geocode) echo 1;; geocode_url) echo https://example.test/reverse;; mqtt_host) echo broker.test;; mqtt_port) echo 8883;;
mqtt_topic) echo test/location;; mqtt_client_id) echo test-router;; mqtt_tls) echo 1;; mqtt_insecure) echo 0;; mqtt_retain) echo 1;;
*) exit 1;; esac
EOF
cat > "$TMP/bin/uclient-fetch" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do [ "$1" = -O ] && { out=$2; shift 2; continue; }; url=$1; shift; done
case "$url" in
*reverse*) printf '%s' '{"address":{"suburb":"Centro","city":"Curitiba","state":"Parana"}}' > "$out";;
*) printf '%s' '{"lat":-25.43,"lon":-49.27,"range":900,"samples":7}' > "$out";; esac
EOF
cat > "$TMP/bin/jsonfilter" <<'EOF'
#!/bin/sh
file= expr=
while [ "$#" -gt 0 ]; do case "$1" in -i) file=$2; shift 2;; -e) expr=$2; shift 2;; *) shift;; esac; done
data=$(cat "$file")
case "$expr" in
@.lat) echo "$data" | sed -n 's/.*"lat":\([^,}]*\).*/\1/p';; @.lon) echo "$data" | sed -n 's/.*"lon":\([^,}]*\).*/\1/p';;
@.range) echo 900;; @.samples) echo 7;; @.address.suburb) echo Centro;; @.address.city) echo Curitiba;; @.address.state) echo Parana;;
esac
EOF
cat > "$TMP/bin/mosquitto_pub" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$MQTT_ARGS"
EOF
cat > "$TMP/bin/logger" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$TMP/bin/"*

MQTT_ARGS="$TMP/mqtt.args" PATH="$TMP/bin:$PATH" sh "$ROOT/files/usr/sbin/opencellid-agent" once
grep -q '"ok":true' /tmp/opencellid-state.json
grep -q '"neighborhood":"Centro"' /tmp/opencellid-state.json
grep -q -- '-t test/location' "$TMP/mqtt.args"
grep -q -- '--capath /etc/ssl/certs' "$TMP/mqtt.args"
echo "agent integration test: OK"

