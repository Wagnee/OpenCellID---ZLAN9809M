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

## Configuração

Acesse **Serviços → Cell Location / MQTT**, preencha a chave OpenCellID, broker, porta, tópico e intervalo (mínimo de 30 segundos). Salvar a página reinicia o serviço.

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

## Operação e diagnóstico

```sh
# Executar e publicar agora
/usr/sbin/opencellid-agent once

# Ver o último estado (fica somente em RAM)
/usr/sbin/opencellid-agent status

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

## Licença

MIT. Consulte [LICENSE](LICENSE).
