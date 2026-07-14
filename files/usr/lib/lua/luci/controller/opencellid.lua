module("luci.controller.opencellid", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/opencellid") then return end
	entry({"admin", "services", "opencellid"}, cbi("opencellid"), _("Cell Location / MQTT"), 70).dependent = true
	entry({"admin", "services", "opencellid", "status"}, call("action_status")).leaf = true
	entry({"admin", "services", "opencellid", "run"}, call("action_run")).leaf = true
end

function action_status()
	local http = require "luci.http"
	http.prepare_content("application/json")
	local f = io.open("/tmp/opencellid-state.json", "r")
	if f then http.write(f:read("*a")); f:close() else http.write('{"ok":false,"error":"Nenhuma localização coletada"}') end
end

function action_run()
	local http = require "luci.http"
	if http.getenv("REQUEST_METHOD") ~= "POST" then http.status(405, "Method Not Allowed"); return end
	os.execute("/usr/sbin/opencellid-agent once >/dev/null 2>&1 &")
	http.prepare_content("application/json")
	http.write('{"started":true}')
end

