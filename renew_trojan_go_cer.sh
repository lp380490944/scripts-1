#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

# 检查是否以root运行
[[ $EUID -ne 0 ]] && echo -e "${RED}错误：${PLAIN} 必须使用root用户运行此脚本！\n" && exit 1

# 检查acme.sh是否安装
if [[ ! -f ~/.acme.sh/acme.sh ]]; then
    echo -e "${RED}错误：${PLAIN} acme.sh 未安装，无法更新证书"
    exit 1
fi

# 读取当前的域名和证书路径
CONFIG_FILE="/etc/trojan-go/config.json"
DOMAIN=$(grep sni $CONFIG_FILE | cut -d\" -f4)
CERT_FILE=$(grep cert $CONFIG_FILE | cut -d\" -f4)
KEY_FILE=$(grep key $CONFIG_FILE | cut -d\" -f4)

if [[ -z "$DOMAIN" || -z "$CERT_FILE" || -z "$KEY_FILE" ]]; then
    echo -e "${RED}错误：${PLAIN} 无法从配置文件中读取域名或证书路径"
    exit 1
fi

echo -e "${YELLOW}当前域名：${PLAIN}$DOMAIN"
echo -e "${YELLOW}证书文件：${PLAIN}$CERT_FILE"
echo -e "${YELLOW}私钥文件：${PLAIN}$KEY_FILE"

# 停止相关服务
systemctl stop nginx
systemctl stop trojan-go

# 更新证书
~/.acme.sh/acme.sh --renew -d $DOMAIN --ecc --force

# 安装新证书
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
    --key-file       $KEY_FILE  \
    --fullchain-file $CERT_FILE \
    --reloadcmd     "systemctl force-reload nginx"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}证书更新失败，请检查acme.sh的输出并解决问题${PLAIN}"
    exit 1
fi

# 重启服务
systemctl start nginx
systemctl start trojan-go

echo -e "${GREEN}证书已成功更新并安装${PLAIN}"
echo -e "${YELLOW}请检查trojan-go和nginx服务是否正常运行${PLAIN}"
