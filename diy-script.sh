#!/bin/bash

# ==========================================
# 1. 基础定制（根据需要取消注释）
# ==========================================
# 修改默认IP（AP模式建议改掉避免跟主路由冲突，比如改为 192.168.10.1）
# sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 修改默认主机名
# sed -i 's/OpenWrt/My-AP/g' package/base-files/files/bin/config_generate

# ==========================================
# 2. 删除所有第三方插件源码（AP不需要任何额外功能）
# ==========================================
# 清理 feeds 中可能带入的多余主题
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-netgear

# 清理可能存在的多余包（防止后续被编译进去）
rm -rf package/luci-app-adguardhome
rm -rf package/luci-app-smartdns
rm -rf package/smartdns
rm -rf package/luci-app-mosdns
rm -rf package/luci-app-alist
rm -rf package/luci-app-msd_lite
rm -rf package/msd_lite
rm -rf package/luci-app-poweroff
rm -rf package/OpenAppFilter
rm -rf package/luci-app-netdata
rm -rf package/luci-theme-*
rm -rf package/openwrt-passwall*
rm -rf package/luci-app-amlogic

# ==========================================
# 3. 保留官方必要的修复补丁（不添加任何新功能）
# ==========================================
# 修复 hostapd 编译报错（WiFi必须）
cp -f $GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch package/network/services/hostapd/patches/011-fix-mbo-modules-build.patch 2>/dev/null || true

# 修复文件系统工具报错（保留底层兼容性）
sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile 2>/dev/null || true

# 通用 Makefile 修复
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {} 2>/dev/null || true
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {} 2>/dev/null || true

# 修改版本号为日期（可选）
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}' 2>/dev/null)
if [ -n "$orig_version" ]; then
    sed -i "s/${orig_version}/AP-R${date_version}/g" package/lean/default-settings/files/zzz-default-settings
fi

# ==========================================
# 4. 更新 Feeds（必须步骤）
# ==========================================
./scripts/feeds update -a
./scripts/feeds install -a

# ==========================================
# 5. 终极裁剪与核心强制锁定（针对 AP 固件）
# ==========================================
# 5.1 删除所有 USB、存储、下载、共享、打印驱动
sed -i '/CONFIG_PACKAGE_kmod-usb/d' .config
sed -i '/CONFIG_PACKAGE_usbutils/d' .config
sed -i '/CONFIG_PACKAGE_block-mount/d' .config
sed -i '/CONFIG_PACKAGE_fdisk/d' .config
sed -i '/CONFIG_PACKAGE_lsblk/d' .config
sed -i '/CONFIG_PACKAGE_e2fsprogs/d' .config
sed -i '/CONFIG_PACKAGE_ntfs-3g/d' .config
sed -i '/CONFIG_PACKAGE_kmod-fs-/d' .config
sed -i '/CONFIG_PACKAGE_aria2/d' .config
sed -i '/CONFIG_PACKAGE_transmission/d' .config
sed -i '/CONFIG_PACKAGE_samba4/d' .config
sed -i '/CONFIG_PACKAGE_vsftpd/d' .config
sed -i '/CONFIG_PACKAGE_kmod-usb-printer/d' .config
sed -i '/CONFIG_PACKAGE_p910nd/d' .config

# 5.2 删除多余的第三方 Luci 插件（只保留官方核心）
sed -i '/CONFIG_PACKAGE_luci-app-adblock/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-ddns/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-upnp/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-sqm/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-nlbwmon/d' .config

# ==========================================
# 5.3 强制写入最终配置（确保 AP 核心功能 100% 在）
# ==========================================
cat >> .config <<EOF
# ----- 核心网络协议（全保留） -----
CONFIG_IPV6=y
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_odhcpd-full=y
CONFIG_PACKAGE_ppp=y
CONFIG_PACKAGE_ppp-mod-pppoe=y
CONFIG_PACKAGE_luci-proto-ppp=y
CONFIG_PACKAGE_firewall=y

# ----- VLAN 支持 -----
CONFIG_PACKAGE_vlan=y
CONFIG_PACKAGE_swconfig=y

# ----- NSS 高通硬件加速（IPQ60xx 必选） -----
CONFIG_PACKAGE_kmod-qca-nss-dp=y
CONFIG_PACKAGE_kmod-qca-nss-ecm=y
CONFIG_PACKAGE_kmod-qca-nss-crypto=y

# ----- WiFi 无线驱动与加密 -----
CONFIG_PACKAGE_kmod-ath11k=y
CONFIG_PACKAGE_kmod-ath11k-ahb=y
CONFIG_PACKAGE_hostapd-openssl=y
CONFIG_PACKAGE_wpad-openssl=y
CONFIG_PACKAGE_iw=y

# ----- LuCI Web 管理界面（配 VLAN 和 WiFi 必备） -----
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-mod-admin-full=y
CONFIG_PACKAGE_luci-mod-network=y
CONFIG_PACKAGE_luci-mod-status=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-app-opkg=y

# ----- 基础工具（保持调试能力） -----
CONFIG_PACKAGE_tcpdump-mini=y
CONFIG_PACKAGE_iperf3=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_vim-fuller=y
EOF

# 去除可能重复的 CONFIG_ 行（避免冲突）
sort -u -o .config .config
