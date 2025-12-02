#!/bin/bash

# Shadowsocks-libev 一键安装配置脚本
# 支持自定义端口和密码

set -e  # 出错时自动退出

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否以root用户运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 此脚本必须以root权限运行${NC}"
   exit 1
fi

# 函数：显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -p, --port PORT     设置Shadowsocks端口 (默认: 8388)"
    echo "  -w, --password PASS 设置Shadowsocks密码 (默认: 随机生成)"
    echo "  -m, --method METHOD 设置加密方法 (默认: chacha20-ietf-poly1305)"
    echo "  -h, --help          显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -p 8888 -w MyPassword123"
    echo "  $0 --port 9000 --method aes-256-gcm"
}

# 默认值
PORT="8388"
PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 16)
METHOD="chacha20-ietf-poly1305"
SERVER="0.0.0.0"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -w|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -m|--method)
            METHOD="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 验证端口号
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo -e "${RED}错误: 端口号必须在1-65535之间${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Shadowsocks-libev 一键安装配置脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "配置参数:"
echo -e "  端口: ${YELLOW}${PORT}${NC}"
echo -e "  密码: ${YELLOW}${PASSWORD}${NC}"
echo -e "  加密: ${YELLOW}${METHOD}${NC}"
echo ""
read -p "按 Enter 继续安装，或 Ctrl+C 取消..."

# 安装 Shadowsocks-libev
echo -e "\n${GREEN}[1/6] 安装 Shadowsocks-libev...${NC}"
apt update
apt install -y shadowsocks-libev

# 停止服务（如果已运行）
systemctl stop shadowsocks-libev 2>/dev/null || true

# 创建配置文件
echo -e "\n${GREEN}[2/6] 创建配置文件...${NC}"
CONFIG_FILE="/etc/shadowsocks-libev/config.json"
cat > "$CONFIG_FILE" << EOF
{
    "server": "${SERVER}",
    "server_port": ${PORT},
    "password": "${PASSWORD}",
    "method": "${METHOD}",
    "timeout": 300,
    "fast_open": false,
    "mode": "tcp_and_udp",
    "plugin": "",
    "plugin_opts": ""
}
EOF

echo -e "配置文件已创建: ${CONFIG_FILE}"
echo -e "配置内容:"
cat "$CONFIG_FILE"

# 防火墙设置
echo -e "\n${GREEN}[3/6] 配置防火墙...${NC}"
# 检查UFW是否安装
if command -v ufw &> /dev/null; then
    echo "检测到UFW防火墙，配置端口..."
    ufw allow ${PORT}/tcp
    ufw allow ${PORT}/udp
    echo "已开放TCP和UDP端口: ${PORT}"
else
    echo "未检测到UFW，跳过防火墙配置"
    echo "如需配置防火墙，请手动运行以下命令:"
    echo "  ufw allow ${PORT}/tcp"
    echo "  ufw allow ${PORT}/udp"
fi

# 启动服务
echo -e "\n${GREEN}[4/6] 启动Shadowsocks服务...${NC}"
systemctl daemon-reload
systemctl enable shadowsocks-libev
systemctl restart shadowsocks-libev

# 检查服务状态
echo -e "\n${GREEN}[5/6] 检查服务状态...${NC}"
sleep 2
if systemctl is-active --quiet shadowsocks-libev; then
    echo -e "${GREEN}✓ Shadowsocks服务运行正常${NC}"
else
    echo -e "${RED}✗ Shadowsocks服务启动失败${NC}"
    echo "查看详细日志: journalctl -u shadowsocks-libev -f"
    exit 1
fi

# 显示连接信息
echo -e "\n${GREEN}[6/6] 安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Shadowsocks 配置信息${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "服务器地址: ${YELLOW}你的服务器IP地址${NC}"
echo -e "端口: ${YELLOW}${PORT}${NC}"
echo -e "密码: ${YELLOW}${PASSWORD}${NC}"
echo -e "加密方法: ${YELLOW}${METHOD}${NC}"
echo -e "传输协议: ${YELLOW}tcp_and_udp${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "管理命令:"
echo -e "  查看状态: ${YELLOW}systemctl status shadowsocks-libev${NC}"
echo -e "  查看日志: ${YELLOW}journalctl -u shadowsocks-libev -f${NC}"
echo -e "  重启服务: ${YELLOW}systemctl restart shadowsocks-libev${NC}"
echo -e "  停止服务: ${YELLOW}systemctl stop shadowsocks-libev${NC}"
echo ""
echo -e "防火墙命令:"
echo -e "  查看状态: ${YELLOW}ufw status${NC}"
echo -e "  关闭防火墙: ${YELLOW}ufw disable${NC}"
echo -e "  启动防火墙: ${YELLOW}ufw enable${NC}"
echo -e "${GREEN}========================================${NC}"