# OpenCellID no ZLAN9809M

Serviço leve para OpenWrt que identifica a célula móvel usada pelo roteador ZLAN9809M, consulta sua posição no OpenCellID, obtém o bairro por geocodificação reversa e envia o resultado via MQTT. Inclui uma página LuCI em **Serviços → Cell Location / MQTT**.

## Características

- coleta automática por `ubus`, `uqmi` ou comandos AT, com modo manual para diagnóstico;
- consulta HTTPS à API oficial do OpenCellID;
- bairro/cidade/estado via Nominatim (pode ser desativado);
- MQTT com QoS 1, retain, autenticação e TLS;
- supervisão por `procd`, reinício após falha e recarga ao salvar a configuração;
- estado somente em `/tmp/opencellid-state.json`, sem gravações periódicas na flash;
- código próprio com menos de 50 KB. As dependências são pacotes compartilhados do firmware e não fazem parte desse tamanho.

## Novidades da versão 1.1

- cache por célula, evitando repetir consultas OpenCellID/geocodificação;
- backoff exponencial com jitter quando internet, API ou broker falham;
- fila limitada em RAM e reenvio automático quando o MQTT retorna;
- publicação por mudança de célula/bairro, com heartbeat configurável;
- tópico separado de saúde, contadores e MQTT Last Will;
- diagnóstico de modem e adaptadores Quectel, SIMCom e 3GPP genérico;
- CA personalizada e autenticação mTLS;
- acionamento quando a interface WWAN sobe;
- validação contínua com GitHub Actions.

Veja [CHANGELOG.md](CHANGELOG.md) para a lista completa e [UPGRADING.md](UPGRADING.md) para atualizar uma instalação 1.0.

## Persistência após factory reset

Desde a versão 1.1.1, o pacote inclui `/etc/uci-defaults/99-opencellid`. Quando o pacote é incorporado ao SquashFS da imagem, esse arquivo permanece em `/rom` e recria os padrões do serviço depois que o reset apaga o overlay JFFS2.

Instalar o `.ipk` normalmente não torna o código resistente ao reset: nesse caso os arquivos continuam no overlay. Para preparar um SquashFS extraído, em uma máquina Linux e nunca no rootfs vivo do roteador:

```sh
unsquashfs -d work/rootfs rootfs.bin
scripts/install-into-rootfs.sh work/rootfs \
  packages/libmosquitto-ssl_*.ipk \
  packages/mosquitto-client-ssl_*.ipk
```

O instalador aceita dependências adicionais `.ipk`, copia o payload, corrige permissões e falha se `uci`, `jsonfilter`, `uclient-fetch` ou `mosquitto_pub` não estiverem presentes. Para o ZLAN auditado, os pacotes devem ser compatíveis com OpenWrt 21.02.0 e `mipsel_24kc`.

O script recusa explicitamente `/`, `/rom` e `/overlay`; ele não grava flash. Depois da injeção, a imagem final do ZLAN9809M auditado pode ser criada em Linux com:

```sh
scripts/build-zlan-sysupgrade.sh \
  zlan-kernel.uimage work/rootfs /path/to/fwtool \
  zlan-opencellid-sysupgrade.bin
```

O construtor preserva o kernel fornecido, recria o SquashFS em XZ com blocos de 256 KiB, adiciona metadata `fwtool` para `ZLAN,zlan-cat1` e recusa imagens maiores que a partição de firmware de `0x00fb0000` bytes. Os binários extraídos e gerados não devem ser versionados.

Antes de qualquer gravação, copie a imagem para `/tmp` e execute apenas `sysupgrade -T arquivo.bin`. Esse teste não grava a flash. Tenha uma cópia do firmware original e recuperação por UART disponíveis para a etapa posterior de flash.

Os padrões deixam o serviço desativado até que broker e chave OpenCellID sejam provisionados. Nenhuma credencial é embutida na imagem. Para uma configuração de fábrica diferente, edite `files/etc/uci-defaults/99-opencellid` antes da construção, mantendo segredos fora do firmware.

## Requisitos

O firmware precisa ser baseado em OpenWrt e permitir SSH/opkg. O pacote declara as dependências: `luci-base`, `jsonfilter`, `uci`, `uclient-fetch`, `ca-bundle` e `mosquitto-client-ssl`. Para coleta automática, o firmware deve expor dados celulares no `ubus`, ou ter `uqmi`, ou disponibilizar `microcom` e uma porta AT.

Também são necessários:

1. uma [chave da API OpenCellID](https://opencellid.org/);
2. um broker MQTT acessível pelo roteador;
3. internet e relógio correto para HTTPS/TLS.

O endpoint `cell/get` do OpenCellID pode exigir autorização/whitelist conforme a política da conta. Se a aplicação não contribuir dados, verifique as condições comerciais do serviço.

## Instalação rápida (sem compilar)

Copie o conteúdo de `files/` para a raiz do roteador:

```sh
scp -r files/* root@192.168.1.1:/
ssh root@192.168.1.1
chmod 755 /etc/init.d/opencellid /usr/sbin/opencellid-agent
/etc/init.d/opencellid enable
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

Instale dependências ausentes antes de ativar:

```sh
opkg update
opkg install jsonfilter uclient-fetch ca-bundle mosquitto-client-ssl
```

Em firmwares sem os pacotes nos feeds, use a compilação abaixo ou inclua-os na imagem OpenWrt.

## Compilar um `.ipk`

Dentro do SDK OpenWrt compatível com a arquitetura/versão do firmware:

```sh
mkdir -p package/luci-app-opencellid-mqtt
cp -a Makefile files package/luci-app-opencellid-mqtt/
make package/luci-app-opencellid-mqtt/compile V=s
```

Depois copie e instale o arquivo gerado:

```sh
scp bin/packages/*/*/luci-app-opencellid-mqtt_*.ipk root@192.168.1.1:/tmp/
ssh root@192.168.1.1 'opkg install /tmp/luci-app-opencellid-mqtt_*.ipk'
```

Para gerar diretamente o pacote `all` em Linux, sem SDK:

```sh
scripts/build-ipk.sh
```

O CI anexa esse `.ipk` a cada execução e o workflow de release publica o pacote quando uma tag `vX.Y.Z` é enviada.

## Configuração

Acesse **Serviços → Cell Location / MQTT**, preencha a chave OpenCellID, broker, porta, tópico e intervalo (mínimo de 30 segundos). A página também permite coletar imediatamente, testar o broker e gerar o diagnóstico do modem. Salvar reinicia o serviço.

Também é possível configurar via SSH:

```sh
uci set opencellid.main.opencellid_key='SUA_CHAVE'
uci set opencellid.main.mqtt_host='mqtt.exemplo.com'
uci set opencellid.main.mqtt_port='8883'
uci set opencellid.main.mqtt_topic='frota/roteador-01/localizacao'
uci set opencellid.main.mqtt_client_id='roteador-01'
uci set opencellid.main.interval='300'
uci set opencellid.main.enabled='1'
uci commit opencellid
/etc/init.d/opencellid enable
/etc/init.d/opencellid restart
```

### Fonte da célula

O modo `auto` tenta, nessa ordem:

1. `ubus call network.interface.wwan status` (`data.mcc`, `mnc`, `lac/tac`, `cellid/cid`);
2. `uqmi` em `/dev/cdc-wdm0`;
3. `AT+COPS?` e `AT+CEREG?` em `/dev/ttyUSB2`;
4. valores manuais, se preenchidos.

Como firmwares de fabricante variam, confira primeiro:

```sh
ubus call network.interface.wwan status
uqmi -d /dev/cdc-wdm0 --get-serving-system
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

Se a porta/dispositivo for diferente, ajuste na página. O modo manual é útil para validar OpenCellID e MQTT sem depender da detecção do modem.

O diagnóstico completo está disponível por SSH:

```sh
/usr/sbin/opencellid-diagnose
```

Em portas AT, `auto` tenta Quectel `AT+QENG="servingcell"`, SIMCom `AT+CPSI?` e então o padrão `AT+CEREG?`. A disposição exata dos campos pode variar por firmware do modem; confirme MCC, MNC, TAC e Cell ID no diagnóstico antes de operar em produção.

No firmware ZLAN auditado, o modo automático consulta primeiro `zlan_config.4G_INFO`, preenchido pelo daemon proprietário `zl_usb_serial`. Isso evita abrir a porta AT enquanto o serviço do fabricante a utiliza. O MCC/MNC é derivado do IMSI; selecione MNC de dois ou três dígitos conforme a operadora e marque a opção hexadecimal somente se a tela 4G da ZLAN apresentar LAC/Cell ID nesse formato.

## Cache, fila e política de publicação

Todos os dados transitórios ficam em `/tmp/opencellid`:

- `cache/`: uma resposta por célula, expirada por `cache_ttl`;
- `queue/`: publicações que falharam, limitada por `queue_size`;
- `metrics`: contadores e controle de heartbeat;
- `state.json`: última execução.

Com `publish_on_change=1`, a localização só é enviada quando a célula ou o bairro muda. `heartbeat_interval` força uma atualização periódica mesmo sem movimento. Em falhas, o intervalo cresce de `backoff_initial` até `backoff_max`, com jitter de até 10 segundos.

O Nominatim público exige identificação, cache e uso moderado. O agente usa User-Agent próprio, cache por célula e intervalo mínimo de 60 segundos. Para frotas ou rastreamento comercial, configure um proxy/servidor próprio ou outro provedor; o endpoint pode ser alterado sem atualizar o pacote.

## MQTT de localização e saúde

O tópico principal recebe a localização. `mqtt_status_topic` recebe mensagens retidas de saúde com versão, fonte celular, contadores e tamanho da fila. Quando habilitado, o Last Will marca o dispositivo como offline se uma conexão MQTT for interrompida inesperadamente. O serviço também publica offline durante encerramento normal sempre que houver conectividade.

Para autenticação por certificado, configure `mqtt_ca_file`, `mqtt_cert_file` e `mqtt_key_file`. Proteja chave e configuração:

```sh
chmod 600 /etc/config/opencellid /etc/ssl/private/roteador.key
```

## Operação e diagnóstico

```sh
# Executar e publicar agora
/usr/sbin/opencellid-agent once

# Ver o último estado (fica somente em RAM)
/usr/sbin/opencellid-agent status

# Diagnóstico de hardware/firmware
/usr/sbin/opencellid-agent diagnose

# Teste do tópico MQTT de saúde
/usr/sbin/opencellid-agent test-mqtt

# Logs
logread -e opencellid

# Estado do serviço
/etc/init.d/opencellid status
```

Exemplo de mensagem MQTT:

```json
{"timestamp":"2026-07-14T12:00:00Z","ok":true,"cell":{"mcc":724,"mnc":5,"lac":12345,"cid":67890,"radio":"LTE","signal":"-91"},"location":{"lat":-23.5505,"lon":-46.6333,"range_m":1200,"samples":8,"neighborhood":"Sé","city":"São Paulo","state":"São Paulo"},"error":""}
```

O campo `range_m` é a estimativa fornecida pelo OpenCellID. A posição representa a célula/antena, não a posição GPS exata do roteador; por isso o uso pretendido é identificar aproximadamente o bairro.

## Segurança e privacidade

- Use MQTT com TLS e deixe “ignorar validação do certificado” desativado.
- A senha MQTT e a chave OpenCellID ficam no UCI (`/etc/config/opencellid`); restrinja o acesso SSH/LuCI ao roteador.
- Não publique o tópico em brokers públicos: a mensagem revela a localização aproximada do equipamento.
- A geocodificação reversa envia latitude/longitude ao serviço configurado. Desative-a se quiser publicar apenas coordenadas.
- Para múltiplos roteadores, prefira geocodificação no servidor MQTT ou um proxy com cache, evitando depender da API pública do Nominatim.

## Desenvolvimento e CI

`tests/test-agent.sh` simula UCI, APIs e MQTT para verificar coleta, cache, publicação por mudança, TLS e Last Will. O workflow em `.github/workflows/ci.yml` executa o teste, ShellCheck, validação de sintaxe e bloqueia o build se o projeto superar 1 MB.

## Licença

MIT. Consulte [LICENSE](LICENSE).
