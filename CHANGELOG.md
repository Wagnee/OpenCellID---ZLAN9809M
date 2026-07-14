# Changelog

## 1.1.0 — 2026-07-14

### Adicionado

- cache de localização por célula com TTL configurável;
- backoff exponencial com jitter após falhas de rede/API/MQTT;
- fila limitada em `/tmp` para mensagens não publicadas;
- publicação somente por mudança, com heartbeat máximo configurável;
- tópico de saúde, contadores operacionais e MQTT Last Will;
- certificados CA e autenticação mTLS personalizados;
- diagnóstico automático de comandos, interfaces e dispositivos celulares;
- adaptadores AT para Quectel (`QENG`), SIMCom (`CPSI`) e 3GPP (`CEREG`);
- reinício reativo quando a interface WWAN sobe;
- botões LuCI para coleta, teste MQTT e diagnóstico;
- GitHub Actions para sintaxe, integração, ShellCheck e limite de tamanho.

### Alterado

- estado, cache, métricas e fila foram consolidados em `/tmp/opencellid`;
- requisições HTTP agora identificam a versão no User-Agent;
- geocodificação reversa possui cache e intervalo mínimo de 60 segundos;
- documentação foi ampliada com migração, arquitetura e operação de frota.

## 1.0.0 — 2026-07-14

- primeira versão do agente OpenCellID, MQTT, procd e LuCI.

