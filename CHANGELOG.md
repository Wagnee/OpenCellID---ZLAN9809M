# Changelog

## 1.1.4 — 2026-07-14

- normaliza proprietários e permissões dos arquivos no `.ipk` para `root:root`;
- adiciona fonte celular nativa `zlan_config`, reutilizando os dados publicados pelo processo `zl_usb_serial` sem concorrer pela porta AT;
- adiciona configuração para MNC de dois/três dígitos e valores LAC/Cell ID hexadecimais.

## 1.1.3 — 2026-07-14

- gera `.ipk` no formato `tar.gz` esperado pelo `opkg` do OpenWrt 21.02;
- mantém o instalador offline compatível tanto com IPKs OpenWrt em `tar.gz` quanto com pacotes no formato `ar` mais recente.

## 1.1.2 — 2026-07-14

- corrige a validação POSIX/ShellCheck do instalador offline;
- faz o workflow de release executar testes e ShellCheck antes de publicar o `.ipk`.

## 1.1.1 — 2026-07-14

### Adicionado

- `99-opencellid` em `/etc/uci-defaults` para recriar configurações seguras e habilitar o serviço após factory reset quando o pacote estiver incorporado ao SquashFS;
- instalador offline `scripts/install-into-rootfs.sh` para injetar o payload em um rootfs OpenWrt extraído;
- suporte do instalador à extração de dependências `.ipk` gzip, xz ou zstd;
- proteções contra uso acidental do instalador em `/`, `/rom` ou `/overlay` de um equipamento ativo;
- teste de integração específico para persistência no rootfs.

O script preserva valores UCI já existentes e não incorpora chaves de API, senhas MQTT ou chaves privadas.

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
