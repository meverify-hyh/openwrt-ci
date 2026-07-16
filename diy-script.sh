#!/bin/bash
# ============================================
# 自动裁剪配置，仅保留 AP 核心功能
# ============================================

# 基础定制（按需取消注释）
  sed -i 's/192.168.1.1/192.168.2.253/g' package/base-files/files/bin/config_generate

# 删除所有第三方插件源码（杜绝编译）
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-netgear
rm -rf package/luci-app-adguardhome package/luci-app-smartdns package/smartdns package/luci-app-mosdns
rm -rf package/luci-app-alist package/luci-app-msd_lite package/msd_lite package/luci-app-poweroff
rm -rf package/OpenAppFilter package/luci-app-netdata package/luci-theme-* package/openwrt-passwall*
rm -rf package/luci-app-amlogic package/luci-app-dockerman package/luci-app-samba4 package/luci-app-zerotier

# 修复补丁（保留）
cp -f $GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch package/network/services/hostapd/patches/ 2>/dev/null || true
sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile 2>/dev/null || true

# 通用 Makefile 修复
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {} 2>/dev/null || true
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {} 2>/dev/null || true

# 更新 feeds（必须）
./scripts/feeds update -a
./scripts/feeds install -a

# ============================================
# 核心：删除所有多余的包配置（基于你给出的 .config）
# ============================================
# 删除 Docker 相关
sed -i '/CONFIG_DOCKER/d' .config
sed -i '/CONFIG_PACKAGE_docker/d' .config
sed -i '/CONFIG_PACKAGE_dockerd/d' .config
sed -i '/CONFIG_PACKAGE_runc/d' .config
sed -i '/CONFIG_PACKAGE_containerd/d' .config
sed -i '/CONFIG_PACKAGE_docker-compose/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-dockerman/d' .config
sed -i '/CONFIG_PACKAGE_cgroupfs-mount/d' .config

# 删除 Samba / 文件共享
sed -i '/CONFIG_PACKAGE_samba4/d' .config
sed -i '/CONFIG_PACKAGE_wsdd2/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-samba4/d' .config
sed -i '/CONFIG_SAMBA4/d' .config

# 删除科学上网 / 代理插件
sed -i '/CONFIG_PACKAGE_luci-app-passwall/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-homeproxy/d' .config
sed -i '/CONFIG_PACKAGE_sing-box/d' .config
sed -i '/CONFIG_PACKAGE_xray-core/d' .config
sed -i '/CONFIG_PACKAGE_microsocks/d' .config
sed -i '/CONFIG_PACKAGE_dns2socks/d' .config
sed -i '/CONFIG_PACKAGE_ipt2socks/d' .config
sed -i '/CONFIG_PACKAGE_hysteria/d' .config
sed -i '/CONFIG_PACKAGE_chinadns-ng/d' .config
sed -i '/CONFIG_PACKAGE_tcping/d' .config
sed -i '/CONFIG_SING_BOX/d' .config

# 删除 DDNS / UPnP / ZeroTier / 唤醒等
sed -i '/CONFIG_PACKAGE_ddns-scripts/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-ddns/d' .config
sed -i '/CONFIG_PACKAGE_miniupnpd/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-upnp/d' .config
sed -i '/CONFIG_PACKAGE_zerotier/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-zerotier/d' .config
sed -i '/CONFIG_PACKAGE_etherwake/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-wol/d' .config

# 删除 USB 存储 / 文件系统 / SCSI
sed -i '/CONFIG_PACKAGE_kmod-usb/d' .config
sed -i '/CONFIG_PACKAGE_block-mount/d' .config
sed -i '/CONFIG_PACKAGE_kmod-fs-/d' .config
sed -i '/CONFIG_PACKAGE_kmod-scsi/d' .config
sed -i '/CONFIG_PACKAGE_btrfs-progs/d' .config
sed -i '/CONFIG_PACKAGE_ntfs/d' .config
sed -i '/CONFIG_PACKAGE_mount-utils/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-netspeedtest/d' .config

# 删除多余网络工具（保留基础）
sed -i '/CONFIG_PACKAGE_iperf3/d' .config   # 如果不需要测速可删，但建议保留
sed -i '/CONFIG_PACKAGE_tcpdump/d' .config  # 如需排错可保留

# 删除不用的内核模块（如 vxlan、macvlan、bonding 等，AP 不需要）
sed -i '/CONFIG_PACKAGE_kmod-vxlan/d' .config
sed -i '/CONFIG_PACKAGE_kmod-macvlan/d' .config
sed -i '/CONFIG_PACKAGE_kmod-bonding/d' .config
sed -i '/CONFIG_PACKAGE_kmod-veth/d' .config
sed -i '/CONFIG_PACKAGE_kmod-tun/d' .config
sed -i '/CONFIG_PACKAGE_kmod-wireguard/d' .config

# 删除 SQM（流量整形，AP 可不要）
sed -i '/CONFIG_PACKAGE_sqm-scripts/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-sqm/d' .config

# 删除 argon 主题（只保留 bootstrap）
sed -i '/CONFIG_PACKAGE_luci-theme-argon/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-argon-config/d' .config

# 删除其他杂项
sed -i '/CONFIG_PACKAGE_geoview/d' .config
sed -i '/CONFIG_PACKAGE_curl/d' .config   # 若需要可保留
sed -i '/CONFIG_PACKAGE_coremark/d' .config

# ============================================
# 强制保留绝对核心（覆盖可能被误删的）
# ============================================
cat >> .config <<EOF
# ----- 网络协议（全保留） -----
CONFIG_IPV6=y
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_odhcpd-full=y
CONFIG_PACKAGE_ppp=y
CONFIG_PACKAGE_ppp-mod-pppoe=y
CONFIG_PACKAGE_luci-proto-ppp=y
CONFIG_PACKAGE_firewall=y
CONFIG_PACKAGE_ip-tiny=y

# ----- VLAN -----
CONFIG_PACKAGE_vlan=y
CONFIG_PACKAGE_swconfig=y

# ----- NSS 硬件加速（IPQ60xx）-----
CONFIG_PACKAGE_kmod-qca-nss-dp=y
CONFIG_PACKAGE_kmod-qca-nss-ecm=y
CONFIG_PACKAGE_kmod-qca-nss-crypto=y

# ----- WiFi 驱动 -----
CONFIG_PACKAGE_kmod-ath11k=y
CONFIG_PACKAGE_kmod-ath11k-ahb=y
CONFIG_PACKAGE_hostapd-openssl=y
CONFIG_PACKAGE_wpad-openssl=y
CONFIG_PACKAGE_iw=y

# ----- LuCI Web 界面（保留配置）-----
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-mod-admin-full=y
CONFIG_PACKAGE_luci-mod-network=y
CONFIG_PACKAGE_luci-mod-status=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-app-opkg=y

# ----- 基础工具（保留调试）-----
CONFIG_PACKAGE_tcpdump-mini=y
CONFIG_PACKAGE_iperf3=y
CONFIG_PACKAGE_curl=y
EOF

# 去重
sort -u -o .config .config
