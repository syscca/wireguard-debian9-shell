#!/bin/bash
#添加wireguard源
echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable
apt update
# 安全更新
env DEBIAN_FRONTEND=noninteractive apt upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'
#　安装wireguard
apt install -y linux-headers-$(uname -r) qrencode curl iptables wireguard
# 开启BBR
LSBBR=$(sysctl net.ipv4.tcp_congestion_control)
if [[ ${LSBBR} =~ "bbr" ]]; then
echo "已开启BBR"
else
echo "正在开启BBR"
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
fi
# 开启转发
IPNETF=$(cat /proc/sys/net/ipv4/ip_forward)
if [[ ${IPNETF} -eq "1" ]]; then
echo "已开启转发"
else
echo "正在开启转发"
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p
fi
# 创建wireguard文件夹
WGMKDIR=/etc/wireguard
if [[ ! -d ${WGMKDIR} ]]; then
echo "正在创建wireguard文件夹"
mkdir -p ${WGMKDIR}
else
echo "wireguard文件夹已创建"
fi
cd ${WGMKDIR}
# Wireguard 生成密钥对
umask 077 && wg genkey | tee sprivate.key | wg pubkey > spublic.key
umask 077 && wg genkey | tee cprivate.key | wg pubkey > cpublic.key
umask 077 && wg genpsk > preshared.key
# Wireguard服务器私钥
sprivatekey=$(<sprivate.key)
# Wireguard客户端公钥
cpublickey=$(<cpublic.key)
# Wireguard客户端私钥
cprivatekey=$(<cprivate.key)
# Wireguard服务器公钥
spublickey=$(<spublic.key)
# Wireguard 防止量子计算攻击
presharedkey=$(<preshared.key)
# 获取网卡接口
wkjkname=$(ip link | grep ^[2] | awk -F:\  '{print $2}')
# 生成Wireguard服务器配置
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.100.0.1/24
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${wkjkname} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${wkjkname} -j MASQUERADE
ListenPort = 51820
PrivateKey = ${sprivatekey}

[Peer]
PublicKey = ${cpublickey}
PresharedKey = ${presharedkey}
AllowedIPs = 10.100.0.2/32
EOF
# 获取外网IP
wwip=$(curl -s myip.ipip.net |grep -o "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}")
# 生成Wireguard客户端配置
cat > /etc/wireguard/client.conf <<EOF
[Interface]
PrivateKey = $cprivatekey
Address = 10.100.0.2/24
ListenPort = 51820
DNS = 8.8.8.8
MTU = 1350

[Peer]
PublicKey = ${spublickey}
PresharedKey = ${presharedkey}
AllowedIPs = 0.0.0.0/0
Endpoint = ${wwip}:51820
PersistentKeepalive = 25
EOF
# 启动Wireguard
wg-quick up /etc/wireguard/wg0.conf
# 开机自启Wireguard
systemctl enable wg-quick@wg0
# 生成客户端二维码
qrencode -t ansiutf8 < /etc/wireguard/client.conf
# 查看客户端配置文件
cat /etc/wireguard/client.conf
