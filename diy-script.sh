#!/bin/bash
# ==============================================
# 纯净 AP 固件编译脚本 (24.10-6.12 分支)
# 保留：VLAN + NSS + WiFi + 完整网络协议 + LuCI
# ==============================================

# 1. 删除所有可能引入的第三方插件源码
rm -rf package/luci-app-athena-led
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-netgear
rm -rf package/luci-app-adguardhome package/luci-app-smartdns package/smartdns package/luci-app-mosdns
rm -rf package/luci-app-alist package/luci-app-msd_lite package/msd_lite package/luci-app-poweroff
rm -rf package/OpenAppFilter package/luci-app-netdata package/luci-theme-* package/openwrt-passwall*
rm -rf package/luci-app-amlogic package/luci-app-dockerman package/luci-app-samba4 package/luci-app-zerotier

# 2. 修复必要的补丁（保持 WiFi 稳定）
cp -f $GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch package/network/services/hostapd/patches/ 2>/dev/null || true
sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile 2>/dev/null || true

# 3. 通用 Makefile 修复
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {} 2>/dev/null || true
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {} 2>/dev/null || true

# 4. 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# ==============================================
# 5. 裁剪 .config – 删除所有无关包
# ==============================================
# Docker
sed -i '/CONFIG_DOCKER/d; /CONFIG_PACKAGE_docker/d; /CONFIG_PACKAGE_dockerd/d; /CONFIG_PACKAGE_runc/d; /CONFIG_PACKAGE_containerd/d; /CONFIG_PACKAGE_cgroupfs-mount/d' .config

# Samba / 文件共享
sed -i '/CONFIG_PACKAGE_samba4/d; /CONFIG_PACKAGE_wsdd2/d; /CONFIG_PACKAGE_luci-app-samba4/d; /CONFIG_SAMBA4/d' .config

# 科学上网 / 代理
sed -i '/CONFIG_PACKAGE_luci-app-passwall/d; /CONFIG_PACKAGE_luci-app-homeproxy/d; /CONFIG_PACKAGE_sing-box/d; /CONFIG_PACKAGE_xray-core/d; /CONFIG_PACKAGE_microsocks/d; /CONFIG_PACKAGE_dns2socks/d; /CONFIG_PACKAGE_ipt2socks/d; /CONFIG_PACKAGE_hysteria/d; /CONFIG_PACKAGE_chinadns-ng/d; /CONFIG_PACKAGE_tcping/d' .config
sed -i '/CONFIG_SING_BOX/d' .config

# DDNS / UPnP / ZeroTier / 唤醒
sed -i '/CONFIG_PACKAGE_ddns-scripts/d; /CONFIG_PACKAGE_luci-app-ddns/d; /CONFIG_PACKAGE_miniupnpd/d; /CONFIG_PACKAGE_luci-app-upnp/d; /CONFIG_PACKAGE_zerotier/d; /CONFIG_PACKAGE_luci-app-zerotier/d; /CONFIG_PACKAGE_etherwake/d; /CONFIG_PACKAGE_luci-app-wol/d' .config

# USB 存储 / 文件系统
sed -i '/CONFIG_PACKAGE_kmod-usb/d; /CONFIG_PACKAGE_block-mount/d; /CONFIG_PACKAGE_kmod-fs-/d; /CONFIG_PACKAGE_kmod-scsi/d; /CONFIG_PACKAGE_btrfs-progs/d; /CONFIG_PACKAGE_ntfs/d; /CONFIG_PACKAGE_mount-utils/d' .config

# 多余网络内核模块（VXLAN、MACVLAN、Bonding、VETH、TUN、WireGuard）
sed -i '/CONFIG_PACKAGE_kmod-vxlan/d; /CONFIG_PACKAGE_kmod-macvlan/d; /CONFIG_PACKAGE_kmod-bonding/d; /CONFIG_PACKAGE_kmod-veth/d; /CONFIG_PACKAGE_kmod-tun/d; /CONFIG_PACKAGE_kmod-wireguard/d' .config

# SQM 流量整形
sed -i '/CONFIG_PACKAGE_sqm-scripts/d; /CONFIG_PACKAGE_luci-app-sqm/d' .config

# Argon 主题（只保留 bootstrap）
sed -i '/CONFIG_PACKAGE_luci-theme-argon/d; /CONFIG_PACKAGE_luci-app-argon-config/d' .config

# 其他杂项（若需保留 curl/iperf 可注释对应行）
sed -i '/CONFIG_PACKAGE_geoview/d; /CONFIG_PACKAGE_coremark/d' .config

# 删除可能残留的 netspeedtest
sed -i '/CONFIG_PACKAGE_luci-app-netspeedtest/d; /CONFIG_PACKAGE_speedtest-cli/d' .config

# ==============================================
# 6. 强制保留核心功能（适配 24.10 分支）
# ==============================================
cat >> .config <<EOF
# ----- 网络协议（完整） -----
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

# ----- NSS 硬件加速 (24.10 分支包名可能略有变化) -----
CONFIG_PACKAGE_kmod-qca-nss-dp=y
CONFIG_PACKAGE_kmod-qca-nss-ecm=y
CONFIG_PACKAGE_kmod-qca-nss-crypto=y
CONFIG_PACKAGE_kmod-qca-mcs=y

# ----- WiFi 驱动 -----
CONFIG_PACKAGE_kmod-ath11k=y
CONFIG_PACKAGE_kmod-ath11k-ahb=y
CONFIG_PACKAGE_hostapd-openssl=y
CONFIG_PACKAGE_wpad-openssl=y
CONFIG_PACKAGE_iw=y

# ----- LuCI Web 界面 -----
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-mod-admin-full=y
CONFIG_PACKAGE_luci-mod-network=y
CONFIG_PACKAGE_luci-mod-status=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-app-opkg=y

# ----- 基础调试工具（可保留） -----
CONFIG_PACKAGE_tcpdump-mini=y
CONFIG_PACKAGE_iperf3=y
CONFIG_PACKAGE_curl=y
EOF

# 去重并重新生成依赖
sort -u -o .config .config
make defconfig > /dev/null 2>&1
