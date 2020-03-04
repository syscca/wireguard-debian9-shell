# wireguard-debian9-shell

首先安全更新系统

apt update && env DEBIAN_FRONTEND=noninteractive apt upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'

全自动一键wireguard搭建脚本

wget https://raw.githubusercontent.com/vinyo/wireguard-debian9-shell/master/wg.sh && chmod +x wg.sh &&./wg.sh
