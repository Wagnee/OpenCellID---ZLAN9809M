include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-opencellid-mqtt
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=OpenCellID location publisher for ZLAN9809M
  DEPENDS:=+luci-base +jsonfilter +uci +uclient-fetch +ca-bundle +mosquitto-client-ssl
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  Lightweight cell location service with OpenCellID, reverse geocoding and MQTT.
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/opencellid
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d $(1)/usr/sbin
	$(INSTALL_CONF) ./files/etc/config/opencellid $(1)/etc/config/opencellid
	$(INSTALL_BIN) ./files/etc/init.d/opencellid $(1)/etc/init.d/opencellid
	$(INSTALL_BIN) ./files/usr/sbin/opencellid-agent $(1)/usr/sbin/opencellid-agent
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/controller/opencellid.lua $(1)/usr/lib/lua/luci/controller/opencellid.lua
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/model/cbi/opencellid.lua $(1)/usr/lib/lua/luci/model/cbi/opencellid.lua
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

