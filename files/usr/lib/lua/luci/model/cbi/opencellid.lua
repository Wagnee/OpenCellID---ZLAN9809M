local util = require "luci.util"
local m = Map("opencellid", translate("Localização por célula / MQTT"),
	translate("Obtém a célula móvel atual, consulta o OpenCellID e publica a localização no broker MQTT. O estado temporário não ocupa a flash."))
local s = m:section(NamedSection, "main", "opencellid", translate("Configuração"))
s.addremove = false

local status = s:option(DummyValue, "_status", translate("Último estado"))
status.rawhtml = true
function status.cfgvalue()
	local f = io.open("/tmp/opencellid/state.json", "r")
	if not f then return "<em>" .. translate("Nenhuma localização coletada ainda") .. "</em>" end
	local value = f:read("*a"); f:close()
	return "<pre style='white-space:pre-wrap;max-width:100%;overflow:auto'>" .. util.pcdata(value) .. "</pre>"
end
local run = s:option(Button, "_run", translate("Coletar e publicar agora")); run.inputtitle = translate("Executar"); run.inputstyle = "apply"
function run.write() luci.sys.call("/usr/sbin/opencellid-agent once >/dev/null 2>&1 &") end
local test = s:option(Button, "_test", translate("Testar MQTT/status")); test.inputtitle = translate("Testar broker"); test.inputstyle = "apply"
function test.write() luci.sys.call("/usr/sbin/opencellid-agent test-mqtt >/dev/null 2>&1 &") end
local diag = s:option(Button, "_diag", translate("Atualizar diagnóstico do modem")); diag.inputtitle = translate("Diagnosticar"); diag.inputstyle = "apply"
function diag.write() luci.sys.call("/usr/sbin/opencellid-diagnose > /tmp/opencellid-diagnose.json 2>/dev/null") end
local diagout = s:option(DummyValue, "_diagout", translate("Diagnóstico")); diagout.rawhtml = true
function diagout.cfgvalue()
	local f = io.open("/tmp/opencellid-diagnose.json", "r"); if not f then return "-" end
	local value = f:read("*a"); f:close(); return "<pre style='white-space:pre-wrap;max-width:100%;overflow:auto'>" .. util.pcdata(value) .. "</pre>"
end

local e = s:option(Flag, "enabled", translate("Ativar serviço")); e.rmempty = false
local i = s:option(Value, "interval", translate("Intervalo de envio (segundos)")); i.datatype = "range(30,86400)"; i.default = 300
local hb = s:option(Value, "heartbeat_interval", translate("Heartbeat máximo (segundos)")); hb.datatype = "range(60,86400)"; hb.default = 3600
local pc = s:option(Flag, "publish_on_change", translate("Publicar somente quando a célula/bairro mudar")); pc.default = 1
local ct = s:option(Value, "cache_ttl", translate("Validade do cache por célula (segundos)")); ct.datatype = "range(60,604800)"; ct.default = 86400
local bi = s:option(Value, "backoff_initial", translate("Espera inicial após falha")); bi.datatype = "range(30,3600)"; bi.default = 30
local bm = s:option(Value, "backoff_max", translate("Espera máxima após falha")); bm.datatype = "range(60,86400)"; bm.default = 900
local qs = s:option(Value, "queue_size", translate("Máximo de mensagens na fila RAM")); qs.datatype = "range(0,100)"; qs.default = 10
local k = s:option(Value, "opencellid_key", translate("Chave da API OpenCellID")); k.password = true; k.rmempty = false
local u = s:option(Value, "opencellid_url", translate("URL da API OpenCellID")); u.default = "https://opencellid.org/cell/get"
local rg = s:option(Flag, "reverse_geocode", translate("Converter coordenadas em bairro")); rg.default = 1
local gu = s:option(Value, "geocode_url", translate("URL de geocodificação reversa")); gu:depends("reverse_geocode", "1"); gu.default = "https://nominatim.openstreetmap.org/reverse"
local gi = s:option(Value, "geocode_min_interval", translate("Intervalo mínimo do geocodificador")); gi:depends("reverse_geocode", "1"); gi.datatype = "range(60,86400)"; gi.default = 60

local h = s:option(Value, "mqtt_host", translate("Broker MQTT")); h.rmempty = false
local p = s:option(Value, "mqtt_port", translate("Porta MQTT")); p.datatype = "port"; p.default = 8883
local t = s:option(Value, "mqtt_topic", translate("Tópico")); t.default = "zlan9809m/location"
local id = s:option(Value, "mqtt_client_id", translate("Client ID")); id.default = "zlan9809m"
s:option(Value, "mqtt_username", translate("Usuário MQTT"))
local pw = s:option(Value, "mqtt_password", translate("Senha MQTT")); pw.password = true
local tls = s:option(Flag, "mqtt_tls", translate("Usar TLS")); tls.default = 1
local ins = s:option(Flag, "mqtt_insecure", translate("Ignorar validação do certificado")); ins:depends("mqtt_tls", "1"); ins.default = 0
local ret = s:option(Flag, "mqtt_retain", translate("Mensagem retida")); ret.default = 1
local st = s:option(Value, "mqtt_status_topic", translate("Tópico de saúde/status")); st.default = "zlan9809m/status"
local will = s:option(Flag, "mqtt_will", translate("Configurar MQTT Last Will")); will.default = 1
local ca = s:option(Value, "mqtt_ca_file", translate("Certificado CA personalizado")); ca:depends("mqtt_tls", "1"); ca.placeholder = "/etc/ssl/certs/ca-certificates.crt"
local cert = s:option(Value, "mqtt_cert_file", translate("Certificado cliente mTLS")); cert:depends("mqtt_tls", "1")
local key = s:option(Value, "mqtt_key_file", translate("Chave privada mTLS")); key:depends("mqtt_tls", "1"); key.password = true

local cs = s:option(ListValue, "cell_source", translate("Fonte dos dados da célula"))
cs:value("auto", translate("Automática")); cs:value("ubus", "ubus/wwan"); cs:value("uqmi", "QMI/uqmi"); cs:value("at", translate("Comandos AT")); cs:value("manual", translate("Manual (diagnóstico)")); cs.default = "auto"
local qd = s:option(Value, "qmi_device", translate("Dispositivo QMI")); qd:depends("cell_source", "uqmi"); qd.default = "/dev/cdc-wdm0"
local md = s:option(Value, "modem_device", translate("Porta AT")); md:depends("cell_source", "at"); md.default = "/dev/ttyUSB2"
local aa = s:option(ListValue, "at_adapter", translate("Adaptador AT")); aa:depends("cell_source", "at")
aa:value("auto", translate("Detectar automaticamente")); aa:value("quectel", "Quectel QENG"); aa:value("simcom", "SIMCom CPSI"); aa:value("generic", "3GPP CEREG"); aa.default = "auto"
local wi = s:option(Value, "wwan_interface", translate("Interface móvel OpenWrt")); wi.default = "wwan"
for _, v in ipairs({{"manual_mcc","MCC"},{"manual_mnc","MNC"},{"manual_lac","LAC/TAC"},{"manual_cid","Cell ID"}}) do
	local o = s:option(Value, v[1], v[2]); o:depends("cell_source", "manual"); o.datatype = "uinteger"
end
local mr = s:option(ListValue, "manual_radio", translate("Tecnologia manual")); mr:depends("cell_source", "manual")
for _, r in ipairs({"GSM","UMTS","LTE","NR","NBIOT"}) do mr:value(r) end

function m.on_after_commit(self)
	luci.sys.call("/etc/init.d/opencellid restart >/dev/null 2>&1")
end

return m
