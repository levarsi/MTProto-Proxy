#!/bin/bash

# MTProto代理脚本测试工具
# 用于验证脚本的关键功能

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 测试结果记录
test_result() {
    local test_name=$1
    local result=$2
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MTProto代理脚本测试${NC}"
echo -e "${BLUE}========================================${NC}\n"

# 测试1: 检查脚本文件是否存在
echo -e "${YELLOW}[测试 1] 检查脚本文件${NC}"
if [ -f "mtproxy.sh" ]; then
    test_result "脚本文件存在" "PASS"
else
    test_result "脚本文件存在" "FAIL"
    echo -e "${RED}错误: 未找到 mtproxy.sh 文件${NC}"
    exit 1
fi

# 测试2: 检查脚本语法
echo -e "\n${YELLOW}[测试 2] 检查脚本语法${NC}"
if bash -n mtproxy.sh 2>/dev/null; then
    test_result "脚本语法正确" "PASS"
else
    test_result "脚本语法正确" "FAIL"
    echo -e "${RED}错误: 脚本存在语法错误${NC}"
    bash -n mtproxy.sh
fi

# 测试3: 检查必要的函数是否存在
echo -e "\n${YELLOW}[测试 3] 检查关键函数${NC}"
functions=(
    "generate_secret"
    "read_config"
    "check_port"
    "install_mtproxy"
    "start_mtproxy"
    "stop_mtproxy"
    "restart_mtproxy"
    "status_mtproxy"
    "show_proxy_info"
    "update_mtproxy"
    "uninstall_mtproxy"
    "get_config_path"
    "check_container_exists"
    "check_container_running"
    "ensure_config_exists"
)

for func in "${functions[@]}"; do
    if grep -q "^${func}()" mtproxy.sh || grep -q "^${func} ()" mtproxy.sh; then
        test_result "函数 $func 存在" "PASS"
    else
        test_result "函数 $func 存在" "FAIL"
    fi
done

# 测试4: 检查密钥生成功能
echo -e "\n${YELLOW}[测试 4] 测试密钥生成${NC}"
source mtproxy.sh 2>/dev/null
SECRET=$(generate_secret 2>/dev/null)
if [[ "$SECRET" =~ ^[a-f0-9]{32}$ ]]; then
    test_result "密钥生成格式正确 (32位小写十六进制)" "PASS"
else
    test_result "密钥生成格式正确" "FAIL"
    echo -e "${RED}生成的密钥: $SECRET${NC}"
fi

# 测试5: 检查配置文件读取逻辑
echo -e "\n${YELLOW}[测试 5] 测试配置文件处理${NC}"

# 创建测试配置文件
TEST_CONFIG="/tmp/test_mtproxy_config_$$"
cat > "$TEST_CONFIG" << 'EOF'
PORT=8443
SECRET=0123456789abcdef0123456789abcdef
TAG=test
CONTAINER_NAME=test-proxy
DOCKER_IMAGE=telegrammessenger/proxy:latest
EOF

# 测试配置文件读取
source mtproxy.sh 2>/dev/null
CONFIG_FILE="$TEST_CONFIG"
if read_config 2>/dev/null; then
    if [ "$PORT" = "8443" ] && [ "$SECRET" = "0123456789abcdef0123456789abcdef" ]; then
        test_result "配置文件读取正确" "PASS"
    else
        test_result "配置文件读取正确" "FAIL"
        echo -e "${RED}PORT=$PORT, SECRET=$SECRET${NC}"
    fi
else
    test_result "配置文件读取正确" "FAIL"
fi

# 清理测试文件
rm -f "$TEST_CONFIG" "${TEST_CONFIG}.tmp"*

# 测试6: 检查帮助信息
echo -e "\n${YELLOW}[测试 6] 测试帮助信息${NC}"
if bash mtproxy.sh help 2>/dev/null | grep -q "MTProto"; then
    test_result "帮助信息显示正常" "PASS"
else
    test_result "帮助信息显示正常" "FAIL"
fi

# 测试7: 检查Docker依赖
echo -e "\n${YELLOW}[测试 7] 检查Docker环境${NC}"
if command -v docker &> /dev/null; then
    test_result "Docker命令可用" "PASS"
    
    # 检查Docker服务
    if docker info &> /dev/null; then
        test_result "Docker服务运行正常" "PASS"
    else
        test_result "Docker服务运行正常" "FAIL"
        echo -e "${YELLOW}提示: Docker服务未运行，某些功能可能无法测试${NC}"
    fi
else
    test_result "Docker命令可用" "FAIL"
    echo -e "${YELLOW}提示: 未安装Docker，跳过相关测试${NC}"
fi

# 测试8: 检查错误处理
echo -e "\n${YELLOW}[测试 8] 测试错误处理${NC}"

# 测试不存在的配置文件
source mtproxy.sh 2>/dev/null
CONFIG_FILE="/tmp/nonexistent_config_$$"
if ! read_config 2>/dev/null; then
    test_result "正确处理不存在的配置文件" "PASS"
else
    test_result "正确处理不存在的配置文件" "FAIL"
fi

# 测试空配置文件
EMPTY_CONFIG="/tmp/empty_config_$$"
touch "$EMPTY_CONFIG"
CONFIG_FILE="$EMPTY_CONFIG"
if ! read_config 2>/dev/null; then
    test_result "正确处理空配置文件" "PASS"
else
    test_result "正确处理空配置文件" "FAIL"
fi
rm -f "$EMPTY_CONFIG"

# 测试9: 检查跨平台兼容性标记
echo -e "\n${YELLOW}[测试 9] 检查跨平台兼容性${NC}"
if grep -q "uname" mtproxy.sh && grep -q "Darwin" mtproxy.sh && grep -q "MINGW" mtproxy.sh; then
    test_result "包含跨平台检测代码" "PASS"
else
    test_result "包含跨平台检测代码" "FAIL"
fi

# 测试10: 检查安全性改进
echo -e "\n${YELLOW}[测试 10] 检查安全性改进${NC}"

# 检查是否使用数组构建Docker命令
if grep -q "docker_args=(" mtproxy.sh; then
    test_result "使用数组构建Docker命令（更安全）" "PASS"
else
    test_result "使用数组构建Docker命令" "FAIL"
fi

# 检查是否有超时设置
if grep -q "\-\-max-time" mtproxy.sh; then
    test_result "curl命令包含超时设置" "PASS"
else
    test_result "curl命令包含超时设置" "FAIL"
fi

# 显示测试总结
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}测试总结${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "总测试数: ${TESTS_TOTAL}"
echo -e "${GREEN}通过: ${TESTS_PASSED}${NC}"
echo -e "${RED}失败: ${TESTS_FAILED}${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ 所有测试通过!${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠ 部分测试失败，请检查上述错误${NC}"
    exit 1
fi
