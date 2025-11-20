# MTProto代理部署脚本

这是一个用于快速部署MTProto代理服务器的Shell脚本。该脚本基于Docker实现，提供了简单易用的界面，支持多种配置选项和管理功能。

## 功能特性

- ✅ 基于Docker的一键安装
- ✅ 自定义端口配置
- ✅ 自动生成随机密钥
- ✅ 多端口支持
- ✅ 自定义标签和广告标签
- ✅ 用户会话超时配置
- ✅ 完整的管理功能（启动、停止、重启）
- ✅ 实时状态和资源使用监控
- ✅ 日志查看和实时监控
- ✅ 开机自启配置
- ✅ 代理信息一键查看（含代理链接）
- ✅ 简单易用的命令行界面

## 系统要求

- Linux系统（推荐Ubuntu 18.04+或CentOS 7+）
- Docker环境
- 至少128MB内存
- 至少1GB磁盘空间
- 公网IP地址

## 安装Docker

在使用脚本前，请确保已安装Docker：

```bash
# Ubuntu系统
sudo apt update && sudo apt install -y docker.io

# CentOS系统
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
```

## 使用方法

### 1. 获取脚本

```bash
git clone https://github.com/yourusername/MTProto-Proxy.git
cd MTProto-Proxy
chmod +x mtproxy.sh
```

### 2. 安装代理

```bash
sudo ./mtproxy.sh install
```

安装过程中会提示您输入以下配置：
- 代理端口（默认：443）
- 密钥（默认为随机生成）
- 自定义标签（可选）
- 广告标签（可选）
- 用户会话超时时间（默认：300秒）
- 是否添加额外端口（可选）

### 3. 启动代理

```bash
sudo ./mtproxy.sh start
```

### 4. 查看代理信息

```bash
sudo ./mtproxy.sh info
```

此命令将显示完整的代理信息，包括：
- 服务器公网IP
- 代理端口
- 访问密钥
- 用户数和流量统计
- Telegram代理链接（可直接复制到Telegram使用）

### 5. 查看代理状态

```bash
sudo ./mtproxy.sh status
```

此命令将显示代理运行状态和资源使用情况。

### 6. 查看代理日志

```bash
sudo ./mtproxy.sh logs
```

### 7. 实时监控代理日志

```bash
sudo ./mtproxy.sh monitor
```

### 8. 配置开机自启

```bash
sudo ./mtproxy.sh autostart
```

### 9. 重启代理

```bash
sudo ./mtproxy.sh restart
```

### 10. 停止代理

```bash
sudo ./mtproxy.sh stop
```

### 11. 更新代理镜像

```bash
sudo ./mtproxy.sh update
```

### 12. 卸载代理

```bash
sudo ./mtproxy.sh uninstall
```

## 配置文件说明

配置文件位于脚本同一目录下的 `.mtproxy.conf` 文件中，包含以下参数：

- `PORT`: 代理端口
- `SECRET`: 访问密钥
- `TAG`: 自定义标签
- `AD_TAG`: 广告标签
- `USERS_TTL`: 用户会话超时时间
- `EXTRA_PORTS`: 额外端口列表
- `PUBLIC_IP`: 服务器公网IP
- `CONTAINER_NAME`: Docker容器名称

您可以手动编辑此文件来修改配置，但建议使用 `install` 命令重新配置。

## 在Telegram中使用代理

1. 打开Telegram设置
2. 选择「数据与存储」或「高级」
3. 点击「代理设置」
4. 选择「添加代理」
5. 选择「MTProto代理」
6. 输入服务器地址、端口和密钥
7. 或者，直接点击 `info` 命令显示的代理链接

## 常见问题

### 端口无法访问
- 检查防火墙是否允许该端口
- 确保Docker服务正常运行
- 尝试使用其他端口（如8443、2086等）

### 连接不稳定
- 可能是服务器带宽不足
- 尝试增加用户会话超时时间
- 检查网络连接质量

### Docker相关错误
- 确保Docker已正确安装
- 检查Docker服务状态：`systemctl status docker`
- 尝试重新启动Docker服务：`systemctl restart docker`

## 性能优化

- 对于高流量场景，建议使用专用服务器
- 增加服务器内存至少512MB
- 考虑使用Nginx进行流量负载均衡
- 定期更新Docker镜像以获取性能改进

## 注意事项

- 请确保您的服务器有稳定的网络连接
- 定期检查代理状态以确保正常运行
- 不要分享您的代理密钥给不可信的人
- 遵守当地法律法规使用此工具

## 许可证

MIT License

## 技术支持

如有任何问题或建议，请在GitHub仓库提交Issue。

---

脚本版本：1.0.0
更新日期：2025年11月