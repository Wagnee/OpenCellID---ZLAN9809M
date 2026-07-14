module("luci.controller.opencellid", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/opencellid") then return end
	entry({"admin", "services", "opencellid"}, cbi("opencellid"), _("Cell Location / MQTT"), 70).dependent = true
	entry({"admin", "services", "opencellid", "status"}, call("action_status")).leaf = true
end

function action_status()
	local http = require "luci.http"
	http.prepare_content("application/json")
	local f = io.open("/tmp/opencellid/state.json", "r")
	if f then http.write(f:read("*a")); f:close() else http.write('{"ok":false,"error":"Nenhuma localização coletada"}') end
end
