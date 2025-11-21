#!/bin/bash

# MTProto代理部署脚本
# 版本: 1.0.0
# 基于Docker实现的MTProto代理服务器部署和管理工具

# 颜色定义 - 支持不同终端环境
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    # 非交互终端环境下禁用颜色
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# 检查是否为root用户 (仅在Linux/Unix系统)
if [ "$(uname)" != "Darwin" ] && [ "$(uname)" != "MINGW" ] && [ "$(uname)" != "CYGWIN" ]; then
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 请使用root权限运行此脚本${NC}"
        echo -e "使用命令: sudo $0 [选项]"
        exit 1
    fi
fi

# 默认配置
WORKDIR=$(pwd)
DOCKER_IMAGE="telegrammessenger/proxy:latest"
CONTAINER_NAME="mtproto-proxy"
DEFAULT_PORT=443
DEFAULT_SECRET="$(openssl rand -hex 16)"
DEFAULT_TAG=""  # 自定义标签
DEFAULT_AD_TAG=""  # 广告标签
DEFAULT_USERS_TTL=300  # 用户会话超时时间(秒)
LOG_FILE="mtproxy.log"

# 日志函数
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color
    
    case $level in
        "INFO") color=$BLUE ;;
        "SUCCESS") color=$GREEN ;;
        "WARNING") color=$YELLOW ;;
        "ERROR") color=$RED ;;
        *) color=$NC ;;
    esac
    
    # 输出到控制台
    echo -e "${color}[$timestamp] [$level] $message${NC}"
    
    # 输出到日志文件 - 确保不会污染配置文件
    { echo "[$timestamp] [$level] $message"; } >> "$LOG_FILE" 2>/dev/null || true
}

# 检查必要工具
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin

check_dependencies() {
    log_message "INFO" "检查系统依赖..."
    
    # 检查bash版本
    if [ -z "${BASH_VERSINFO}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        log_message "WARNING" "您的bash版本较旧，可能会影响某些功能。建议使用bash 4.0或更高版本。"
    fi
    
    # 检查curl或wget
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        log_message "ERROR" "未找到curl或wget，请先安装其中一个工具"
        exit 1
    fi
}

# 检查Docker是否已安装
check_docker() {
    log_message "INFO" "检查Docker环境..."
    
    # 检查Docker命令是否存在
    if ! command -v docker &> /dev/null; then
        log_message "ERROR" "未找到Docker。请先安装Docker。"
        echo -e "${BLUE}安装Docker的命令:${NC}"
        echo -e "  Ubuntu/Debian: sudo apt update && sudo apt install -y docker.io"
        echo -e "  CentOS/RHEL: sudo yum install -y docker 或 sudo dnf install -y docker"
        echo -e "  macOS: brew install --cask docker"
        echo -e "  Windows: 从Docker官网下载Docker Desktop安装"
        exit 1
    fi
    
    # 检查Docker服务是否运行
    if ! docker info &> /dev/null; then
        log_message "WARNING" "Docker服务未运行。正在尝试启动..."
        
        # 尝试启动Docker服务（兼容不同系统）
        if command -v systemctl &> /dev/null; then
            if systemctl start docker; then
                log_message "INFO" "使用systemctl成功启动Docker服务"
                # 尝试启用开机自启
                if systemctl enable docker; then
                    log_message "INFO" "Docker服务已设置为开机自启"
                fi
            else
                log_message "ERROR" "使用systemctl启动Docker服务失败"
            fi
        elif command -v service &> /dev/null; then
            if service docker start; then
                log_message "INFO" "使用service命令成功启动Docker服务"
            else
                log_message "ERROR" "使用service命令启动Docker服务失败"
            fi
        else
            log_message "ERROR" "无法启动Docker服务。请手动启动Docker。"
            exit 1
        fi
        
        # 等待Docker启动
        sleep 3
        
        # 再次检查Docker服务是否运行
        if ! docker info &> /dev/null; then
            log_message "ERROR" "无法启动Docker服务。请手动启动Docker。"
            echo -e "${BLUE}提示: 您可以尝试以下命令手动启动Docker:${NC}"
            echo -e "  sudo systemctl start docker  # 对于systemd系统"
            echo -e "  sudo service docker start    # 对于SysV系统"
            exit 1
        fi
    fi
    
    log_message "SUCCESS" "Docker环境检查通过"
}

# 生成随机密钥
generate_secret() {
    # 尝试使用openssl生成随机密钥
    if command -v openssl &> /dev/null; then
        # 使用子shell确保日志不会混入返回值
        (
            log_message "INFO" "使用openssl生成随机密钥"
        ) >&2
        openssl rand -hex 16
    else
        # 备选方案：使用/dev/urandom生成随机密钥
        (
            log_message "WARNING" "未找到openssl，使用/dev/urandom生成随机密钥"
        ) >&2
        cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1
    fi
}

# 获取配置文件路径
get_config_path() {
    echo "$WORKDIR/.mtproxy_config"
}

# 检查容器是否存在
check_container_exists() {
    local container_name=${1:-$CONTAINER_NAME}
    docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"
}

# 检查容器是否正在运行
check_container_running() {
    local container_name=${1:-$CONTAINER_NAME}
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"
}

# 确保配置文件存在
ensure_config_exists() {
    local config_file=$(get_config_path)
    if [ ! -f "$config_file" ]; then
        log_message "ERROR" "未找到配置文件，请先运行安装命令: $0 install"
        exit 1
    fi
}

# 读取配置文件
read_config() {
    # 确保CONFIG_FILE变量已设置
    if [ -z "$CONFIG_FILE" ]; then
        CONFIG_FILE="$WORKDIR/.mtproxy_config"
        log_message "INFO" "配置文件路径设置为: $CONFIG_FILE"
    fi
    
    # 检查配置文件是否存在
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "INFO" "配置文件 $CONFIG_FILE 不存在"
        return 1
    fi
    
    # 检查配置文件是否为空
    if [ ! -s "$CONFIG_FILE" ]; then
        log_message "ERROR" "配置文件为空"
        return 1
    fi
    
    # 检查文件权限 (非Windows系统)
    if [ "$(uname)" != "MINGW" ] && [ "$(uname)" != "CYGWIN" ]; then
        # macOS 使用不同的 stat 命令
        if [ "$(uname)" = "Darwin" ]; then
            local file_perm=$(stat -f "%Lp" "$CONFIG_FILE" 2>/dev/null)
        else
            local file_perm=$(stat -c "%a" "$CONFIG_FILE" 2>/dev/null)
        fi
        
        if [ -n "$file_perm" ] && [ "$file_perm" -gt "600" ]; then
            log_message "WARNING" "配置文件权限过于宽松，建议设置为600权限: chmod 600 $CONFIG_FILE"
        fi
    fi
    
    # 读取配置
    log_message "INFO" "从 $CONFIG_FILE 读取配置"
    
    # 简化的配置文件读取：只读取非注释、非空行的变量定义
    # 创建临时文件用于安全加载
    local temp_config="$CONFIG_FILE.tmp.$$"
    
    # 过滤配置文件：移除注释、空行和日志行
    grep -v '^#' "$CONFIG_FILE" 2>/dev/null | \
    grep -v '^[[:space:]]*$' | \
    grep -E '^[A-Za-z_][A-Za-z0-9_]*=' | \
    grep -v '\[20[0-9][0-9]-' > "$temp_config" 2>/dev/null
    
    # 检查是否有有效配置
    if [ ! -s "$temp_config" ]; then
        log_message "ERROR" "配置文件中没有有效的配置项"
        rm -f "$temp_config"
        return 1
    fi
    
    # 加载配置
    if source "$temp_config" 2>/dev/null; then
        rm -f "$temp_config"
    else
        log_message "ERROR" "配置文件格式错误，无法加载"
        rm -f "$temp_config"
        return 1
    fi
    
    # 验证必要的配置项
    if [ -z "$PORT" ] || [ -z "$SECRET" ]; then
        log_message "ERROR" "配置文件缺少必要的PORT或SECRET配置项"
        return 1
    fi
    
    # 验证PORT是数字且在有效范围内
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        log_message "ERROR" "PORT配置无效: $PORT (必须是1-65535之间的数字)"
        return 1
    fi
    
    # 验证SECRET是有效的32字符十六进制字符串（小写）
    if ! [[ "$SECRET" =~ ^[a-f0-9]{32}$ ]]; then
        log_message "WARNING" "SECRET格式可能不正确: $SECRET (应为32位小写十六进制字符串)"
    fi
    
    # 确保关键变量已设置
    if [ -z "$CONTAINER_NAME" ]; then
        CONTAINER_NAME="mtproto-proxy"
        log_message "WARNING" "容器名称未设置，使用默认值: $CONTAINER_NAME"
    fi
    
    if [ -z "$DOCKER_IMAGE" ]; then
        DOCKER_IMAGE="telegrammessenger/proxy:latest"
        log_message "WARNING" "Docker镜像未设置，使用默认值: $DOCKER_IMAGE"
    fi
    
    log_message "INFO" "配置文件读取成功"
    return 0
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}MTProto代理部署脚本 v1.0.0${NC}"
    echo -e "基于Docker的MTProto代理服务器一键部署工具"
    echo -e ""
    echo -e "使用方法: $0 [选项]"
    echo -e ""
    echo -e "选项:"
    echo -e "  install   - 安装MTProto代理"
    echo -e "  start     - 启动MTProto代理"
    echo -e "  stop      - 停止MTProto代理"
    echo -e "  restart   - 重启MTProto代理"
    echo -e "  status    - 查看MTProto代理状态和资源使用情况"
    echo -e "  logs      - 查看MTProto代理日志"
    echo -e "  monitor   - 监控MTProto代理实时日志"
    echo -e "  autostart - 配置MTProto代理开机自启"
    echo -e "  info      - 查看MTProto代理配置信息"
    echo -e "  uninstall - 卸载MTProto代理"
    echo -e "  update    - 更新MTProto代理镜像"
    echo -e "  help      - 显示此帮助信息"
    echo -e ""
    echo -e "示例:"
    echo -e "  安装代理: $0 install"
    echo -e "  查看状态: $0 status"
    echo -e "  查看配置: $0 info"
    echo -e "  重启代理: $0 restart"
    echo -e ""
    echo -e "系统要求:"
    echo -e "  - 安装Docker"
    echo -e "  - Linux系统需要root权限"
    echo -e "  - Windows/MacOS需要以管理员权限运行Docker Desktop"
    echo -e ""
}

# 检查端口是否被占用
check_port() {
    local port=$1
    local os_type=$(uname)
    
    # 首先检查Docker容器是否已占用该端口
    if command -v docker &> /dev/null; then
        if docker ps --format '{{.Ports}}' 2>/dev/null | grep -q ":$port->"; then
            log_message "WARNING" "端口 $port 已被Docker容器占用"
            return 1  # 端口被占用
        fi
    fi
    
    # 根据操作系统使用不同的端口检查方法
    if [ "$os_type" = "Darwin" ]; then
        # macOS 系统
        if command -v lsof &> /dev/null; then
            if lsof -i:"$port" &> /dev/null; then
                return 1  # 端口被占用
            fi
        fi
    elif [ "$os_type" = "MINGW" ] || [ "$os_type" = "CYGWIN" ]; then
        # Windows 系统（Git Bash/Cygwin）
        if command -v netstat &> /dev/null; then
            if netstat -ano | grep -q ":$port "; then
                return 1  # 端口被占用
            fi
        fi
    else
        # Linux 系统
        if command -v ss &> /dev/null; then
            # 优先使用 ss 命令（更现代）
            if ss -tuln | grep -q ":$port "; then
                return 1  # 端口被占用
            fi
        elif command -v netstat &> /dev/null; then
            # 备用 netstat 命令
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                return 1  # 端口被占用
            fi
        elif command -v lsof &> /dev/null; then
            # 最后尝试 lsof
            if lsof -i:"$port" &> /dev/null; then
                return 1  # 端口被占用
            fi
        fi
    fi
    
    return 0  # 端口可用
}

# 安装MTProto代理
install_mtproxy() {
    check_docker
    check_dependencies
    
    log_message "INFO" "开始安装MTProto代理..."
    
    # 检查并创建工作目录
    mkdir -p "$WORKDIR"
    
    # 询问用户配置
    while true; do
        read -p "请输入代理端口 (默认: $DEFAULT_PORT): " PORT
        PORT=${PORT:-$DEFAULT_PORT}
        
        # 验证端口格式
        if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
            log_message "ERROR" "端口号无效，请输入1-65535之间的数字"
            continue
        fi
        
        # 检查端口是否被占用
        if ! check_port "$PORT"; then
            log_message "WARNING" "端口 $PORT 已被占用，请选择其他端口"
            continue
        fi
        
        break
    done
    
    read -p "是否使用随机密钥? (y/n，默认: y): " USE_RANDOM_SECRET
    USE_RANDOM_SECRET=${USE_RANDOM_SECRET:-y}
    
    if [ "$USE_RANDOM_SECRET" = "y" ]; then
        SECRET=$(generate_secret)
        log_message "SUCCESS" "已生成随机密钥"
    else
        while true; do
            read -p "请输入自定义密钥 (32位十六进制字符串): " SECRET
            # 验证密钥格式（允许大小写，但会转换为小写）
            if ! [[ "$SECRET" =~ ^[a-fA-F0-9]{32}$ ]]; then
                log_message "ERROR" "密钥格式错误，请输入32位的十六进制字符串 (0-9, a-f)"
                continue
            fi
            # 统一转换为小写
            SECRET=$(echo "$SECRET" | tr '[:upper:]' '[:lower:]')
            log_message "INFO" "密钥已统一转换为小写格式"
            break
        done
    fi
    
    # 高级配置选项
    log_message "INFO" "以下是高级配置选项，可直接回车使用默认值"
    read -p "请输入自定义标签 (可选，用于统计): " TAG
    TAG=${TAG:-$DEFAULT_TAG}
    
    read -p "请输入广告标签 (可选): " AD_TAG
    AD_TAG=${AD_TAG:-$DEFAULT_AD_TAG}
    
    while true; do
        read -p "请输入用户会话超时时间(秒) (默认: $DEFAULT_USERS_TTL): " USERS_TTL
        USERS_TTL=${USERS_TTL:-$DEFAULT_USERS_TTL}
        
        # 验证超时时间格式
        if ! [[ "$USERS_TTL" =~ ^[0-9]+$ ]]; then
            log_message "ERROR" "超时时间必须是数字"
            continue
        fi
        break
    done
    
    # 多端口支持
    read -p "是否配置额外端口? (y/n，默认: n): " USE_MULTI_PORT
    USE_MULTI_PORT=${USE_MULTI_PORT:-n}
    
    EXTRA_PORTS=""
    if [ "$USE_MULTI_PORT" = "y" ]; then
        log_message "INFO" "请输入额外端口，多个端口用空格分隔"
        read -a ADDITIONAL_PORTS
        for extra_port in "${ADDITIONAL_PORTS[@]}"; do
            # 验证端口格式
            if ! [[ "$extra_port" =~ ^[0-9]+$ ]] || [ "$extra_port" -lt 1 ] || [ "$extra_port" -gt 65535 ]; then
                log_message "WARNING" "端口 $extra_port 无效，跳过"
                continue
            fi
            
            # 检查端口是否被占用
            if ! check_port "$extra_port"; then
                log_message "WARNING" "端口 $extra_port 已被占用，跳过"
                continue
            fi
            
            EXTRA_PORTS="$EXTRA_PORTS -p $extra_port:$extra_port"
        done
    fi
    
    # 显示配置摘要
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}配置摘要${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}端口:${NC} $PORT"
    echo -e "${GREEN}密钥:${NC} $SECRET"
    if [ -n "$TAG" ]; then
        echo -e "${GREEN}自定义标签:${NC} $TAG"
    fi
    if [ -n "$AD_TAG" ]; then
        echo -e "${GREEN}广告标签:${NC} $AD_TAG"
    fi
    echo -e "${GREEN}用户会话超时:${NC} ${USERS_TTL}秒"
    if [ -n "$EXTRA_PORTS" ]; then
        echo -e "${GREEN}额外端口:${NC} ${EXTRA_PORTS//-p /}"
    fi
    echo -e "${GREEN}Docker镜像:${NC} $DOCKER_IMAGE"
    echo -e "${GREEN}容器名称:${NC} $CONTAINER_NAME"
    echo -e "${BLUE}========================================${NC}\n"
    
    # 用户确认
    read -p "确认以上配置并继续安装? (y/n，默认: y): " CONFIRM
    CONFIRM=${CONFIRM:-y}
    if [ "$CONFIRM" != "y" ]; then
        log_message "INFO" "安装已取消"
        exit 0
    fi
    
    # 创建配置文件
    CONFIG_FILE="$WORKDIR/.mtproxy_config"
    log_message "INFO" "创建配置文件: $CONFIG_FILE"
    
    # 确保文件为空
    > "$CONFIG_FILE"
    
    # 使用here-document方式创建配置文件，避免重定向问题
    cat > "$CONFIG_FILE" << EOF
PORT=$PORT
SECRET=$SECRET
TAG=$TAG
AD_TAG=$AD_TAG
USERS_TTL=$USERS_TTL
EXTRA_PORTS='$EXTRA_PORTS'
CONTAINER_NAME=$CONTAINER_NAME
DOCKER_IMAGE=$DOCKER_IMAGE
EOF
    
    # 设置配置文件权限
    chmod 600 "$CONFIG_FILE" || log_message "WARNING" "无法设置配置文件权限为600"
    
    # 拉取镜像
    log_message "INFO" "正在拉取MTProto代理镜像..."
    echo -e "${YELLOW}提示: 首次拉取可能需要几分钟，请耐心等待...${NC}"
    
    if ! docker pull "$DOCKER_IMAGE"; then
        log_message "ERROR" "拉取镜像失败!"
        echo -e "${RED}可能的原因:${NC}"
        echo -e "  1. 网络连接问题"
        echo -e "  2. Docker Hub 访问受限"
        echo -e "  3. Docker 服务未正常运行"
        echo -e "${YELLOW}建议:${NC}"
        echo -e "  - 检查网络连接"
        echo -e "  - 尝试使用代理或镜像加速服务"
        echo -e "  - 稍后重试"
        # 清理配置文件
        rm -f "$CONFIG_FILE"
        exit 1
    fi
    
    log_message "SUCCESS" "镜像拉取成功"
    
    # 停止并删除已存在的容器
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        log_message "INFO" "删除已存在的容器..."
        docker stop "$CONTAINER_NAME" &> /dev/null
        docker rm "$CONTAINER_NAME" &> /dev/null
    fi
    
    # 使用数组构建Docker命令（更安全）
    local docker_args=(
        "run" "-d"
        "--name" "$CONTAINER_NAME"
        "--restart=unless-stopped"
        "-p" "$PORT:$PORT"
        "-e" "SECRET=$SECRET"
        "-e" "PORT=$PORT"
        "-e" "USERS_TTL=$USERS_TTL"
    )
    
    # 添加可选的标签配置
    if [ -n "$TAG" ]; then
        docker_args+=("-e" "TAG=$TAG")
    fi
    
    if [ -n "$AD_TAG" ]; then
        docker_args+=("-e" "AD_TAG=$AD_TAG")
    fi
    
    # 添加额外端口
    if [ -n "$EXTRA_PORTS" ]; then
        # EXTRA_PORTS 格式: "-p 8080:8080 -p 8443:8443"
        # 需要解析并添加到数组中
        local IFS=' '
        local extra_port_array=($EXTRA_PORTS)
        for arg in "${extra_port_array[@]}"; do
            if [ "$arg" != "-p" ] && [ -n "$arg" ]; then
                docker_args+=("-p" "$arg")
            fi
        done
    fi
    
    # 添加镜像名称
    docker_args+=("$DOCKER_IMAGE")
    
    # 运行容器
    log_message "INFO" "正在启动MTProto代理容器..."
    if docker "${docker_args[@]}" > /dev/null 2>&1; then
        # 等待容器启动
        log_message "INFO" "等待容器启动..."
        sleep 3
        
        # 检查容器是否真的在运行
        if docker ps | grep -q "$CONTAINER_NAME"; then
            log_message "SUCCESS" "MTProto代理安装成功!"
            echo -e "\n${GREEN}✔ 安装完成!${NC}\n"
            show_proxy_info
        else
            log_message "ERROR" "MTProto代理容器启动失败"
            echo -e "${RED}容器日志:${NC}"
            docker logs "$CONTAINER_NAME" 2>&1 | tail -n 20
            echo -e "\n${YELLOW}可能的原因:${NC}"
            echo -e "  1. 端口已被占用"
            echo -e "  2. 配置参数错误"
            echo -e "  3. Docker 资源不足"
            # 清理配置文件
            rm -f "$CONFIG_FILE"
            exit 1
        fi
    else
        log_message "ERROR" "MTProto代理安装失败!"
        echo -e "${YELLOW}请检查:${NC}"
        echo -e "  1. Docker 服务是否正常运行"
        echo -e "  2. 端口 $PORT 是否可用"
        echo -e "  3. 系统资源是否充足"
        # 清理配置文件
        rm -f "$CONFIG_FILE"
        exit 1
    fi
}

# 启动MTProto代理
start_mtproxy() {
    ensure_config_exists
    CONFIG_FILE=$(get_config_path)
    
    log_message "INFO" "启动MTProto代理..."
    
    # 读取配置
    if ! read_config; then
        log_message "ERROR" "读取配置文件失败"
        exit 1
    fi
    
    # 检查容器是否存在
    if ! check_container_exists; then
        log_message "ERROR" "MTProto代理容器不存在，请先运行安装命令: $0 install"
        exit 1
    fi
    
    # 检查容器是否已经在运行
    if check_container_running; then
        log_message "WARNING" "MTProto代理已经在运行中"
        docker ps | grep "$CONTAINER_NAME"
        return 0
    fi
    
    if docker start "$CONTAINER_NAME"; then
        log_message "SUCCESS" "MTProto代理已启动!"
        # 显示简短状态信息
        docker ps | grep "$CONTAINER_NAME"
    else
        log_message "ERROR" "启动失败，请检查容器状态!"
        docker logs "$CONTAINER_NAME" 2>&1 | tail -n 10
        exit 1
    fi
}

# 停止MTProto代理
stop_mtproxy() {
    ensure_config_exists
    CONFIG_FILE=$(get_config_path)
    
    log_message "INFO" "停止MTProto代理..."
    
    # 读取配置
    if ! read_config; then
        log_message "ERROR" "读取配置文件失败"
        exit 1
    fi
    
    # 检查容器是否存在
    if ! check_container_exists; then
        log_message "ERROR" "MTProto代理容器不存在，请先运行安装命令: $0 install"
        exit 1
    fi
    
    # 检查容器是否已经停止
    if ! check_container_running; then
        log_message "WARNING" "MTProto代理已经停止"
        return 0
    fi
    
    if docker stop "$CONTAINER_NAME"; then
        log_message "SUCCESS" "MTProto代理已停止!"
    else
        log_message "ERROR" "停止失败，请检查容器状态!"
        exit 1
    fi
}

# 重启MTProto代理
restart_mtproxy() {
    ensure_config_exists
    CONFIG_FILE=$(get_config_path)
    
    log_message "INFO" "重启MTProto代理..."
    
    # 读取配置
    if ! read_config; then
        log_message "ERROR" "读取配置文件失败"
        exit 1
    fi
    
    # 检查容器是否存在
    if ! check_container_exists; then
        log_message "ERROR" "MTProto代理容器不存在，请先运行安装命令: $0 install"
        exit 1
    fi
    
    # 停止容器（如果正在运行）
    if check_container_running; then
        log_message "INFO" "停止MTProto代理容器..."
        docker stop "$CONTAINER_NAME" &> /dev/null
        # 等待容器完全停止
        sleep 2
    fi
    
    # 启动容器
    log_message "INFO" "启动MTProto代理容器..."
    if docker start "$CONTAINER_NAME"; then
        log_message "SUCCESS" "MTProto代理已重启!"
        # 显示简短状态信息
        docker ps | grep "$CONTAINER_NAME"
    else
        log_message "ERROR" "重启失败，请检查容器状态!"
        docker logs "$CONTAINER_NAME" 2>&1 | tail -n 10
        exit 1
    fi
}

# 查看MTProto代理状态
status_mtproxy() {
    ensure_config_exists
    CONFIG_FILE=$(get_config_path)
    
    # 读取配置
    if ! read_config; then
        log_message "ERROR" "读取配置文件失败"
        exit 1
    fi
    
    log_message "INFO" "查看MTProto代理状态..."
    
    if check_container_running; then
        log_message "SUCCESS" "MTProto代理正在运行"
        docker ps | grep "$CONTAINER_NAME"
        
        # 显示资源使用情况
        log_message "INFO" "资源使用情况:"
        docker stats --no-stream "$CONTAINER_NAME"
        
        # 显示连接数统计（如果可用）
        log_message "INFO" "最近连接统计:"
        docker logs "$CONTAINER_NAME" 2>&1 | grep -i "connections" | tail -n 5
    elif check_container_exists; then
        log_message "WARNING" "MTProto代理已停止"
        docker ps -a | grep "$CONTAINER_NAME"
    else
        log_message "ERROR" "MTProto代理容器不存在"
        log_message "INFO" "请运行 '$0 install' 来安装代理"
    fi
}

# 查看MTProto代理日志
logs_mtproxy() {
    CONFIG_FILE="$WORKDIR/.mtproxy_config"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERROR" "未找到配置文件，请先运行安装命令!"
        exit 1
    fi
    
    # 读取配置
    if ! read_config; then
        log_message "ERROR" "读取配置文件失败"
        exit 1
    fi
    
    # 检查容器是否存在
    if ! docker ps -a | grep -q "$CONTAINER_NAME"; then
        log_message "ERROR" "MTProto代理容器不存在，请先运行安装命令!"
        exit 1
    fi
    
    log_message "INFO" "查看MTProto代理日志..."
    
    # 询问要显示的日志行数
    while true; do
        read -p "请输入要显示的日志行数 (默认: 100): " LOG_LINES
        LOG_LINES=${LOG_LINES:-100}
        
        # 验证行数格式
        if ! [[ "$LOG_LINES" =~ ^[0-9]+$ ]] || [ "$LOG_LINES" -lt 1 ]; then
            log_message "ERROR" "行数必须是大于0的数字"
            continue
        fi
        break
    done
    
    log_message "INFO" "显示最近 $LOG_LINES 行日志"
    docker logs --tail "$LOG_LINES" "$CONTAINER_NAME"
}

# 监控MTProto代理实时日志
monitor_mtproxy() {
    CONFIG_FILE="$WORKDIR/.mtproxy_config"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERROR" "未找到配置文件，请先运行安装命令!"
        exit 1
    fi
    
    # 读取配置
    if ! read_config; then
        log_message "ERROR" "读取配置文件失败"
        exit 1
    fi
    
    # 检查容器是否存在
    if ! docker ps -a | grep -q "$CONTAINER_NAME"; then
        log_message "ERROR" "MTProto代理容器不存在，请先运行安装命令!"
        exit 1
    fi
    
    # 检查容器是否在运行
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        log_message "WARNING" "MTProto代理当前未运行，将显示历史日志并持续监控"
    fi
    
    log_message "INFO" "开始监控MTProto代理实时日志 (按 Ctrl+C 停止)"
    log_message "INFO" "显示最近20行历史日志..."
    
    # 先显示最近几行日志，然后开始实时监控
    docker logs --tail 20 "$CONTAINER_NAME"
    echo -e "${YELLOW}===========================================${NC}"
    echo -e "${YELLOW}开始实时监控... (按 Ctrl+C 停止)${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    
    docker logs -f "$CONTAINER_NAME"
}

# 配置MTProto代理开机自启
setup_autostart() {
    CONFIG_FILE="$WORKDIR/.mtproxy_config"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERROR" "未找到配置文件，请先运行安装命令!"
        exit 1
    fi
    
    # 读取配置
    if ! read_config; then
        log_message "ERROR" "读取配置文件失败"
        exit 1
    fi
    
    # 检查容器是否存在
    if ! docker ps -a | grep -q "$CONTAINER_NAME"; then
        log_message "ERROR" "MTProto代理容器不存在，请先运行安装命令!"
        exit 1
    fi
    
    log_message "INFO" "配置MTProto代理开机自启..."
    
    # 检查当前的重启策略
    current_policy=$(docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' "$CONTAINER_NAME")
    
    if [ "$current_policy" = "unless-stopped" ]; then
        log_message "SUCCESS" "MTProto代理已经配置为开机自启"
        return 0
    fi
    
    log_message "INFO" "当前重启策略: $current_policy"
    
    # 更新容器的重启策略
    if docker update --restart=unless-stopped "$CONTAINER_NAME"; then
        log_message "SUCCESS" "MTProto代理开机自启配置成功"
        log_message "INFO" "重启策略已更新为 'unless-stopped'"
    else
        log_message "ERROR" "MTProto代理开机自启配置失败"
        log_message "INFO" "请确保您有足够的权限修改Docker容器配置"
        exit 1
    fi
}

# 显示MTProto代理信息
show_proxy_info() {
    CONFIG_FILE="$WORKDIR/.mtproxy_config"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERROR" "未找到配置文件，请先运行安装命令!"
        exit 1
    fi
    
    # 读取配置
    if ! read_config; then
        log_message "ERROR" "读取配置文件失败"
        exit 1
    fi
    
    # 确保SECRET变量不为空
    if [ -z "$SECRET" ] || [ "$SECRET" = "" ]; then
        log_message "WARNING" "密钥为空或未设置，尝试从Docker容器获取"
        
        # 尝试从容器日志获取密钥（更宽松的正则表达式）
        if docker ps | grep -q "$CONTAINER_NAME"; then
            log_message "INFO" "尝试从容器日志提取密钥"
            # 尝试多种可能的密钥格式
            CONTAINER_SECRET=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -o -E 'secret=[a-zA-Z0-9]{32}' | head -n 1 | cut -d'=' -f2)
            
            # 如果没找到，尝试另一种格式
            if [ -z "$CONTAINER_SECRET" ]; then
                log_message "INFO" "尝试另一种密钥格式"
                CONTAINER_SECRET=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -o -E '[a-zA-Z0-9]{32}' | head -n 1)
            fi
            
            if [ -n "$CONTAINER_SECRET" ] && [ ${#CONTAINER_SECRET} -eq 32 ]; then
                SECRET="$CONTAINER_SECRET"
                log_message "SUCCESS" "从容器日志获取到密钥: $SECRET"
            else
                log_message "ERROR" "无法从容器获取有效的密钥"
                # 生成一个临时密钥用于显示
                SECRET=$(generate_secret)
                log_message "INFO" "生成新的临时密钥: $SECRET"
            fi
        else
            log_message "ERROR" "容器未运行，无法获取密钥"
            # 生成一个临时密钥用于显示
            SECRET=$(generate_secret)
            log_message "INFO" "生成新的临时密钥: $SECRET"
        fi
    else
        log_message "INFO" "从配置文件读取到密钥: $SECRET"
    fi
    
    log_message "INFO" "正在获取MTProto代理信息..."
    
    # 获取公网IP的多种方式尝试（添加超时设置）
    PUBLIC_IP=$(curl -s --max-time 10 ipinfo.io/ip 2>/dev/null)
    if [ -z "$PUBLIC_IP" ]; then
        log_message "WARNING" "无法通过ipinfo.io获取公网IP，尝试备用方法"
        PUBLIC_IP=$(curl -s --max-time 10 icanhazip.com 2>/dev/null)
    fi
    
    if [ -z "$PUBLIC_IP" ]; then
        log_message "WARNING" "无法通过icanhazip.com获取公网IP，尝试最后一种方法"
        PUBLIC_IP=$(curl -s --max-time 10 api.ipify.org 2>/dev/null)
    fi
    
    if [ -z "$PUBLIC_IP" ]; then
        log_message "ERROR" "无法获取公网IP，请确保您的服务器可以访问互联网"
        PUBLIC_IP="未检测到公网IP"
    fi
    
    # 显示代理信息
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}MTProto代理信息${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}代理地址: ${NC}${PUBLIC_IP}"
    echo -e "${GREEN}主要端口: ${NC}${PORT}"
    
    # 如果有额外端口，显示额外端口信息
    if [ -n "$EXTRA_PORTS" ]; then
        echo -e "${GREEN}额外端口: ${NC}${EXTRA_PORTS}"
    fi
    
    # 确保显示的密钥不为空
    DISPLAY_SECRET="$SECRET"
    if [ -z "$DISPLAY_SECRET" ] || [ "$DISPLAY_SECRET" = "" ]; then
        DISPLAY_SECRET="(空密钥)"
    fi
    echo -e "${GREEN}密钥: ${NC}${DISPLAY_SECRET}"
    
    # 显示高级配置选项
    if [ -n "$TAG" ]; then
        echo -e "${GREEN}自定义标签: ${NC}${TAG}"
    fi
    
    if [ -n "$AD_TAG" ]; then
        echo -e "${GREEN}广告标签: ${NC}${AD_TAG}"
    fi
    
    if [ -n "$USERS_TTL" ]; then
        echo -e "${GREEN}用户会话超时: ${NC}${USERS_TTL} 秒"
    fi
    
    echo -e "${GREEN}容器名称: ${NC}${CONTAINER_NAME}"
    
    # 确保密钥不为空再构建链接
    if [ -z "$SECRET" ] || [ "$SECRET" = "" ]; then
        log_message "ERROR" "密钥为空，无法构建有效的代理链接"
        MTProto_LINK="tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=密钥缺失"
        TELEGRAM_PROXY_LINK="https://t.me/proxy?server=$PUBLIC_IP&port=$PORT&secret=密钥缺失"
    else
        # 确保密钥格式正确
        if [ ${#SECRET} -ne 32 ]; then
            log_message "WARNING" "密钥长度不是32字符，可能无效"
        fi
        # 构建MTProto链接
        MTProto_LINK="tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$SECRET"
        # 构建Telegram代理链接
        TELEGRAM_PROXY_LINK="https://t.me/proxy?server=$PUBLIC_IP&port=$PORT&secret=$SECRET"
    fi
    
    echo -e "${GREEN}MTProto链接: ${NC}$MTProto_LINK"
    echo -e "${GREEN}Telegram代理链接: ${NC}$TELEGRAM_PROXY_LINK"
    echo -e "${BLUE}========================================${NC}"
    
    log_message "INFO" "代理信息显示完成"
    
    # 使用说明
    echo -e "\n${YELLOW}使用说明:${NC}"
    echo -e "1. 在Telegram客户端中，点击设置 -> 数据与存储 -> 代理"
    echo -e "2. 点击 '添加代理' -> 'MTProto'"
    echo -e "3. 输入服务器地址、端口和密钥"
    echo -e "4. 点击 '保存' 完成设置"
}

# 卸载MTProto代理
uninstall_mtproxy() {
    CONFIG_FILE="$WORKDIR/.mtproxy_config"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERROR" "未找到配置文件，MTProto代理可能未安装"
        exit 1
    fi
    
    # 读取配置
    if ! read_config; then
        log_message "ERROR" "读取配置文件失败"
        exit 1
    fi
    
    log_message "WARNING" "警告: 这将完全卸载MTProto代理，包括所有配置和数据!"
    
    # 二次确认卸载
    while true; do
        read -p "确定要继续吗？(y/N): " CONFIRM
        CONFIRM=${CONFIRM:-N}
        
        if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
            break
        elif [ "$CONFIRM" = "n" ] || [ "$CONFIRM" = "N" ]; then
            log_message "INFO" "卸载已取消"
            exit 0
        else
            log_message "ERROR" "请输入 y 或 N"
        fi
    done
    
    log_message "INFO" "开始卸载MTProto代理..."
    
    # 停止并删除容器
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        log_message "INFO" "停止并删除容器..."
        
        # 停止容器
        if docker stop "$CONTAINER_NAME" > /dev/null; then
            log_message "SUCCESS" "容器已停止"
        else
            log_message "WARNING" "容器停止失败，但将继续卸载过程"
        fi
        
        # 删除容器
        if docker rm "$CONTAINER_NAME" > /dev/null; then
            log_message "SUCCESS" "容器已删除"
        else
            log_message "WARNING" "容器删除失败，但将继续卸载过程"
        fi
    else
        log_message "WARNING" "容器不存在，将继续清理配置"
    fi
    
    # 删除配置文件
    log_message "INFO" "删除配置文件..."
    if rm -f "$CONFIG_FILE"; then
        log_message "SUCCESS" "配置文件已删除"
    else
        log_message "ERROR" "配置文件删除失败"
        log_message "WARNING" "请手动删除配置文件: $CONFIG_FILE"
    fi
    
    # 删除日志文件
    if [ -f "$LOG_FILE" ]; then
        log_message "INFO" "删除日志文件..."
        if rm -f "$LOG_FILE"; then
            log_message "SUCCESS" "日志文件已删除"
        else
            log_message "WARNING" "日志文件删除失败"
        fi
    fi
    
    log_message "SUCCESS" "MTProto代理卸载成功!"
}

# 更新MTProto代理
update_mtproxy() {
    CONFIG_FILE="$WORKDIR/.mtproxy_config"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERROR" "未找到配置文件，请先运行安装命令!"
        exit 1
    fi
    
    # 读取配置
    if ! read_config; then
        log_message "ERROR" "读取配置文件失败"
        exit 1
    fi
    
    log_message "INFO" "更新MTProto代理..."
    
    # 检查容器是否存在
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        log_message "INFO" "停止并删除旧容器..."
        
        # 停止容器
        if docker stop "$CONTAINER_NAME" > /dev/null 2>&1; then
            log_message "SUCCESS" "容器已停止"
        else
            log_message "WARNING" "容器停止失败或已停止"
        fi
        
        # 删除容器
        if docker rm "$CONTAINER_NAME" > /dev/null 2>&1; then
            log_message "SUCCESS" "容器已删除"
        else
            log_message "ERROR" "容器删除失败"
            exit 1
        fi
    else
        log_message "WARNING" "容器不存在，将直接创建新容器"
    fi
    
    log_message "INFO" "拉取最新镜像..."
    if docker pull "$DOCKER_IMAGE" > /dev/null 2>&1; then
        log_message "SUCCESS" "镜像更新成功"
    else
        log_message "WARNING" "镜像更新失败，将使用本地现有镜像"
    fi
    
    # 使用数组构建Docker命令（更安全）
    local docker_args=(
        "run" "-d"
        "--name" "$CONTAINER_NAME"
        "--restart=unless-stopped"
        "-p" "$PORT:$PORT"
        "-e" "SECRET=$SECRET"
        "-e" "PORT=$PORT"
    )
    
    # 添加用户会话超时参数
    if [ -n "$USERS_TTL" ]; then
        log_message "INFO" "使用用户会话超时: $USERS_TTL 秒"
        docker_args+=("-e" "USERS_TTL=$USERS_TTL")
    fi
    
    # 添加标签参数
    if [ -n "$TAG" ]; then
        log_message "INFO" "使用自定义标签: $TAG"
        docker_args+=("-e" "TAG=$TAG")
    fi
    
    # 添加广告标签参数
    if [ -n "$AD_TAG" ]; then
        log_message "INFO" "使用广告标签: $AD_TAG"
        docker_args+=("-e" "AD_TAG=$AD_TAG")
    fi
    
    # 添加额外端口
    if [ -n "$EXTRA_PORTS" ]; then
        log_message "INFO" "添加额外端口配置: $EXTRA_PORTS"
        # EXTRA_PORTS 格式: "-p 8080:8080 -p 8443:8443"
        local IFS=' '
        local extra_port_array=($EXTRA_PORTS)
        for arg in "${extra_port_array[@]}"; do
            if [ "$arg" != "-p" ] && [ -n "$arg" ]; then
                docker_args+=("-p" "$arg")
            fi
        done
    fi
    
    # 添加镜像名称
    docker_args+=("$DOCKER_IMAGE")
    
    log_message "INFO" "启动新的MTProto代理容器..."
    
    # 执行Docker命令
    if docker "${docker_args[@]}"; then
        log_message "SUCCESS" "MTProto代理更新成功!"
        # 等待容器启动
        sleep 2
        # 显示代理信息
        show_proxy_info
    else
        log_message "ERROR" "MTProto代理更新失败!"
        log_message "INFO" "请检查Docker是否正常运行，以及端口是否被占用"
        docker logs "$CONTAINER_NAME" 2>&1 | tail -n 20
        exit 1
    fi
}

# 主函数
main() {
    local command=$1
    local os_type=$(uname)
    
    log_message "INFO" "MTProto代理脚本 v1.0.0 启动，操作系统: $os_type"
    
    # 检查命令参数
    if [ $# -eq 0 ]; then
        log_message "WARNING" "未指定命令，显示帮助信息"
        show_help
        exit 1
    fi
    
    # 根据操作系统显示提示信息
    if [ "$os_type" = "MINGW" ] || [ "$os_type" = "CYGWIN" ]; then
        log_message "INFO" "在Windows环境下运行，请确保已启动Docker Desktop"
    elif [ "$os_type" = "Darwin" ]; then
        log_message "INFO" "在macOS环境下运行，请确保已启动Docker Desktop"
    else
        log_message "INFO" "在Linux/Unix环境下运行"
    fi
    
    # 确保工作目录存在
    if [ ! -d "$WORKDIR" ]; then
        log_message "INFO" "创建工作目录: $WORKDIR"
        mkdir -p "$WORKDIR" || {
            log_message "ERROR" "无法创建工作目录: $WORKDIR"
            exit 1
        }
    fi
    
    case "$command" in
        install)
            install_mtproxy
            ;;
        start)
            start_mtproxy
            ;;
        stop)
            stop_mtproxy
            ;;
        restart)
            restart_mtproxy
            ;;
        status)
            status_mtproxy
            ;;
        info)
            show_proxy_info
            ;;
        logs)
            logs_mtproxy
            ;;
        monitor)
            monitor_mtproxy
            ;;
        autostart)
            setup_autostart
            ;;
        uninstall)
            uninstall_mtproxy
            ;;
        update)
            update_mtproxy
            ;;
        help)
            show_help
            ;;
        *)
            log_message "ERROR" "无效的选项: $command"
            show_help
            exit 1
            ;;
    esac
    
    log_message "INFO" "命令 '$command' 执行完成"
}

# 执行主函数
main "$@"
