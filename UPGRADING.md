# Atualização para 1.1.0

> A versão 1.1.1 adiciona o payload persistente para imagens SquashFS. Uma atualização comum por `.ipk` continua no overlay e não sobrevive ao factory reset; consulte a seção “Persistência após factory reset” do README.

A configuração 1.0 permanece compatível. Ao reinstalar o pacote, o arquivo UCI existente é preservado por ser declarado como `conffile`.

```sh
opkg install --force-reinstall /tmp/luci-app-opencellid-mqtt_1.1.0-1_all.ipk
uci commit opencellid
/etc/init.d/opencellid enable
/etc/init.d/opencellid restart
```

Para instalação manual, copie novamente `files/` para a raiz, corrija as permissões executáveis e reinicie `rpcd`, `uhttpd` e o serviço.

As opções novas possuem valores padrão no agente, portanto não são obrigatórias. Para materializá-las na configuração existente:

```sh
uci set opencellid.main.cache_ttl='86400'
uci set opencellid.main.publish_on_change='1'
uci set opencellid.main.heartbeat_interval='3600'
uci set opencellid.main.backoff_initial='30'
uci set opencellid.main.backoff_max='900'
uci set opencellid.main.queue_size='10'
uci set opencellid.main.geocode_min_interval='60'
uci set opencellid.main.mqtt_status_topic='zlan9809m/status'
uci set opencellid.main.mqtt_will='1'
uci commit opencellid
/etc/init.d/opencellid restart
```

O arquivo de estado mudou de `/tmp/opencellid-state.json` para `/tmp/opencellid/state.json`. Nada precisa ser migrado porque `/tmp` reside em RAM.
