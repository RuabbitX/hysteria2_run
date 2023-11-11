#!/bin/bash

if [ $# -ne 2]; then
    echo "please input port and password"
    echo "usage: $0 <port> <password>"
    exit 1
fi

port = $1
password = $2


get_hostname() {
    curl -4 -s ifconfig.me | tr . - | awk '{print $0".traefik.me"}'
}

if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root."
        exit 1
fi

# read -p "Enter a port number: " port

apt update
apt install -y wget curl openssl docker.io

if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
fi

# password=$(openssl rand -base64 12)
ip=$(get_hostname)
echo "Your IP is $ip"

if [ ! -d "/etc/hysteria" ]; then
  mkdir /etc/hysteria
fi

cat <<EOF > /etc/hysteria/config
listen: :$port 
tls:
    cert: /etc/hysteria/fullchain.pem
    key: /etc/hysteria/privkey.pem
auth:
    type: password
    password: $password 
EOF


if [ ! -d "/etc/cron.daily" ]; then
    mkdir /etc/cron.daily
fi

cat <<EOF > /etc/cron.daily/download_cert
#!/bin/bash
wget https://traefik.me/fullchain.pem -O /etc/hysteria/fullchain.pem 
wget https://traefik.me/privkey.pem -O /etc/hysteria/privkey.pem
openssl x509 -in /etc/hysteria/fullchain.pem -out /etc/hysteria/fullchain.crt
openssl rsa -in /etc/hysteria/privkey.pem -out /etc/hysteria/privkey.key  
EOF
chmod +x /etc/cron.daily/download_cert

/etc/cron.daily/download_cert

systemctl enable docker
systemctl start docker
systemctl enable cron
systemctl start cron

docker stop hysteria
docker rm hysteria
docker run -it -d --restart=always --name hysteria -v /etc/hysteria:/etc/hysteria --net=host tobyxdd/hysteria server

url="hy2://$password@$ip:$port"
echo -e "\e[32mYour Hysteria2 URL is $url\e[0m"
echo -e "\e[32muse it in config file of your client."
echo "========================================="
echo -e "\e[32mserver: $url

socks5:
    listen: 127.0.0.1:1080 

http:
    listen: 127.0.0.1:8080 \e[0m"
