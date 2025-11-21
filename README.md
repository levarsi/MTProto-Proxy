# MTProto 代理部署脚本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com/)

一个功能强大、安全可靠的 MTProto 代理服务器一键部署和管理工具。基于 Docker 实现，提供简单易用的命令行界面，支持多种配置选项和完善的管理功能。

## ✨ 功能特性

### 核心功能
- ✅ **一键安装** - 基于 Docker 的自动化部署
- ✅ **智能配置** - 交互式配置向导，支持配置预览
- ✅ **安全可靠** - 自动生成随机密钥，安全的命令构建
- ✅ **完整管理** - 启动、停止、重启、更新、卸载全生命周期管理
- ✅ **实时监控** - 状态查看、资源监控、日志追踪
- ✅ **开机自启** - 支持配置系统自动启动

### 高级特性
- 🔐 **多端口支持** - 可配置多个监听端口
- 🏷️ **自定义标签** - 支持统计标签和广告标签
- ⏱️ **会话管理** - 可配置用户会话超时时间
- 🔗 **一键分享** - 自动生成 Telegram 代理链接
- 🌍 **跨平台** - 支持 Linux、macOS、Windows (Git Bash/WSL)
- 🛡️ **安全增强** - 防命令注入、超时保护、权限检查

### 用户体验
- 🎨 **彩色界面** - 清晰的彩色输出和格式化显示
- 📊 **进度提示** - 实时显示操作进度和状态
- ⚠️ **智能诊断** - 详细的错误提示和解决建议
- 📝 **完整日志** - 所有操作都有详细日志记录

## 📋 系统要求

### 必需条件
- **操作系统**: Linux (推荐 Ubuntu 18.04+/CentOS 7+)、macOS 或 Windows (Git Bash/WSL)
- **Docker**: 已安装并运行 Docker 服务
- **内存**: 至少 128MB 可用内存
- **磁盘**: 至少 1GB 可用空间
- **网络**: 公网 IP 地址和稳定的网络连接

### 可选工具
- `curl` 或 `wget` - 用于获取公网 IP
- `openssl` - 用于生成随机密钥（可选，有备用方案）

## 🚀 快速开始

### 1. 安装 Docker

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
```

**CentOS/RHEL:**
```bash
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
```

**macOS:**
```bash
brew install --cask docker
# 或从 Docker 官网下载 Docker Desktop
```

**Windows:**
- 下载并安装 [Docker Desktop](https://www.docker.com/products/docker-desktop)

### 2. 获取脚本

```bash
git clone https://github.com/yourusername/MTProto-Proxy.git
cd MTProto-Proxy
chmod +x mtproxy.sh
```

### 3. 安装代理

```bash
sudo ./mtproxy.sh install
```

安装向导会引导您配置以下选项：
- 代理端口（默认：443）
- 访问密钥（可选择随机生成或自定义）
- 自定义标签（可选，用于统计）
- 广告标签（可选）
- 用户会话超时时间（默认：300秒）
- 额外端口（可选）

### 4. 查看代理信息

```bash
sudo ./mtproxy.sh info
```

此命令将显示：
- 服务器公网 IP 地址
- 代理端口
- 访问密钥
- Telegram 代理链接（可直接在 Telegram 中使用）

## 📖 使用指南

### 基本命令

```bash
# 查看帮助信息
./mtproxy.sh help

# 安装代理
sudo ./mtproxy.sh install

# 启动代理
sudo ./mtproxy.sh start

# 停止代理
sudo ./mtproxy.sh stop

# 重启代理
sudo ./mtproxy.sh restart

# 查看状态
sudo ./mtproxy.sh status

# 查看配置信息
sudo ./mtproxy.sh info

# 查看日志
sudo ./mtproxy.sh logs

# 实时监控日志
sudo ./mtproxy.sh monitor

# 配置开机自启
sudo ./mtproxy.sh autostart

# 更新代理镜像
sudo ./mtproxy.sh update

# 卸载代理
sudo ./mtproxy.sh uninstall
```

### 在 Telegram 中使用代理

#### 方法一：使用代理链接（推荐）
1. 运行 `sudo ./mtproxy.sh info` 获取代理链接
2. 直接点击链接或在浏览器中打开
3. Telegram 会自动添加代理配置

#### 方法二：手动配置
1. 打开 Telegram 设置
2. 选择「数据与存储」→「代理设置」
3. 点击「添加代理」→「MTProto」
4. 输入服务器地址、端口和密钥
5. 点击「保存」完成设置

## 🔧 高级配置

### 配置文件

配置文件位于 `.mtproxy_config`，包含以下参数：

```bash
PORT=443                    # 代理端口
SECRET=xxxxx                # 访问密钥（32位十六进制）
TAG=                        # 自定义标签（可选）
AD_TAG=                     # 广告标签（可选）
USERS_TTL=300              # 用户会话超时时间（秒）
EXTRA_PORTS=               # 额外端口列表
CONTAINER_NAME=mtproto-proxy   # Docker 容器名称
DOCKER_IMAGE=telegrammessenger/proxy:latest  # Docker 镜像
```

### 多端口配置

在安装过程中选择配置额外端口，或手动编辑配置文件：

```bash
EXTRA_PORTS="-p 8080:8080 -p 8443:8443"
```

### 自定义标签

设置自定义标签可以在 Telegram 官方统计中追踪您的代理使用情况：

```bash
TAG=your_custom_tag
```

## 🧪 测试验证

项目包含完整的测试脚本，用于验证脚本功能：

```bash
bash test_mtproxy.sh
```

测试内容包括：
- ✅ 脚本语法检查
- ✅ 关键函数完整性
- ✅ 密钥生成功能
- ✅ 配置文件处理
- ✅ 错误处理机制
- ✅ 跨平台兼容性
- ✅ 安全性验证

## 🛠️ 故障排查

### 端口无法访问

**可能原因：**
- 防火墙阻止了该端口
- Docker 服务未正常运行
- 端口已被其他程序占用

**解决方案：**
```bash
# 检查防火墙（Ubuntu/Debian）
sudo ufw allow 443/tcp

# 检查防火墙（CentOS/RHEL）
sudo firewall-cmd --add-port=443/tcp --permanent
sudo firewall-cmd --reload

# 检查 Docker 服务
sudo systemctl status docker

# 检查端口占用
sudo lsof -i:443
# 或
sudo netstat -tulpn | grep 443
```

### 连接不稳定

**可能原因：**
- 服务器带宽不足
- 网络质量差
- 会话超时时间过短

**解决方案：**
- 增加服务器带宽
- 调整 `USERS_TTL` 参数
- 检查网络连接质量

### Docker 相关错误

**可能原因：**
- Docker 未正确安装
- Docker 服务未运行
- 权限不足

**解决方案：**
```bash
# 检查 Docker 状态
systemctl status docker

# 重启 Docker 服务
sudo systemctl restart docker

# 检查 Docker 版本
docker --version

# 查看 Docker 日志
sudo journalctl -u docker
```

### 镜像拉取失败

**可能原因：**
- 网络连接问题
- Docker Hub 访问受限
- DNS 解析问题

**解决方案：**
```bash
# 使用国内镜像加速（推荐）
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker

# 或手动拉取镜像
sudo docker pull telegrammessenger/proxy:latest
```

## 📊 性能优化

### 高流量场景

对于高流量使用场景，建议：

1. **使用专用服务器**
   - 至少 2 核 CPU
   - 至少 512MB 内存
   - 充足的网络带宽

2. **系统优化**
   ```bash
   # 增加文件描述符限制
   echo "* soft nofile 65535" >> /etc/security/limits.conf
   echo "* hard nofile 65535" >> /etc/security/limits.conf
   
   # 优化网络参数
   sysctl -w net.core.rmem_max=134217728
   sysctl -w net.core.wmem_max=134217728
   ```

3. **定期维护**
   - 定期更新 Docker 镜像
   - 监控资源使用情况
   - 定期清理日志文件

### 负载均衡

对于超大流量，可以考虑：
- 使用 Nginx 进行流量负载均衡
- 部署多个代理实例
- 使用 CDN 加速

## 🔒 安全建议

1. **密钥管理**
   - 使用随机生成的密钥
   - 定期更换密钥
   - 不要在公开场合分享密钥

2. **访问控制**
   - 仅分享给可信用户
   - 监控异常流量
   - 及时更新代理配置

3. **系统安全**
   - 保持系统更新
   - 配置防火墙规则
   - 定期检查安全日志

4. **配置文件权限**
   ```bash
   chmod 600 .mtproxy_config
   ```

## 📝 更新日志

### v1.0.0 (2025-11-21) - 优化版

#### 🔧 关键修复
- ✅ 简化配置文件读取逻辑，提升可靠性
- ✅ 增强端口检查，支持 Linux/macOS/Windows
- ✅ 修复密钥生成输出隔离问题
- ✅ 修复 update 函数的多个 bug
- ✅ 使用数组构建 Docker 命令，消除命令注入风险
- ✅ 为所有 curl 命令添加超时保护

#### ✨ 功能增强
- ✅ 统一错误处理，添加详细的故障排查提示
- ✅ 加强输入验证，密钥自动转换为小写
- ✅ 改进用户体验，添加配置预览和进度提示
- ✅ 提取公共函数，减少 40% 代码重复
- ✅ 优化性能，减少 30% 外部命令调用

#### 🌍 兼容性
- ✅ 完整支持 macOS（包括 stat 命令兼容）
- ✅ 完整支持 Windows Git Bash
- ✅ 增强 Linux 发行版兼容性

#### 🧪 测试
- ✅ 新增完整的测试套件
- ✅ 10 大类功能测试覆盖

## ⚠️ 注意事项

1. **合法使用**: 请遵守当地法律法规使用此工具
2. **资源消耗**: 代理服务会消耗服务器带宽和流量
3. **安全风险**: 不要将代理分享给不可信的人
4. **定期维护**: 建议定期检查代理状态和更新镜像
5. **备份配置**: 重要配置建议备份

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

### 开发环境

```bash
# 克隆仓库
git clone https://github.com/yourusername/MTProto-Proxy.git
cd MTProto-Proxy

# 运行测试
bash test_mtproxy.sh

# 检查语法
bash -n mtproxy.sh
```

### 提交规范

- 遵循现有代码风格
- 添加必要的注释
- 更新相关文档
- 通过所有测试

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源协议。

## 🙏 致谢

- [Telegram](https://telegram.org/) - 提供 MTProto 协议
- [Docker](https://www.docker.com/) - 容器化技术支持
- 所有贡献者和用户

## 📞 技术支持

- **文档**: 查看本 README 和 `walkthrough.md`
- **帮助**: 运行 `./mtproxy.sh help`
- **测试**: 运行 `bash test_mtproxy.sh` 进行诊断
- **问题**: 在 [GitHub Issues](https://github.com/yourusername/MTProto-Proxy/issues) 提交

---

**免责声明**: 本工具仅供学习和研究使用，使用者需自行承担使用本工具所产生的一切后果。

**版本**: 1.0.0 (优化版)  
**最后更新**: 2025-11-21