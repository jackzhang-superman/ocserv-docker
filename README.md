# 🐋 ocserv-docker  
Cisco AnyConnect (ocserv) Docker 一键部署方案  
A lightweight and automated Docker deployment for ocserv (Cisco AnyConnect VPN).

---

## 🚀 1. 一键安装 (Automatic Installation)

在服务器上执行以下命令，即可自动安装并启动容器：

```bash
TOKEN="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" && bash -c "$(curl -fsSL -H "Authorization: Bearer $TOKEN" https://raw.githubusercontent.com/jackzhang-superman/ocserv-docker/main/run.sh)" -- -u jackzhang-superman -t "$TOKEN"
```

> 💡 安装脚本会自动构建镜像、启动容器并配置 ocserv 环境。  
> 默认支持 FreeRADIUS 认证，可在环境变量中调整。

---

## ⚙️ 2. 修改节点信息 (Custom Banner)

每台服务器的 Banner 可在 `docker-compose.yml` 中自定义：

```yaml
environment:
  BANNER: "欢迎使用 节点-(官网地址为：https://www.cyberfly.org)"
```

修改完成后执行：
```bash
docker compose up -d
```

即可加载新的标识信息。

---

## 🌐 3. 启用 NAT 与 转发 (Enable NAT & IP Forwarding)

> ⚠️ 否则客户端虽然能连接，但无法访问外网。

在宿主机执行以下命令：

```bash
sysctl -w net.ipv4.ip_forward=1
iptables -P FORWARD ACCEPT
iptables -t nat -F POSTROUTING
iptables -A FORWARD -i vpns0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o vpns0 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth0 -j MASQUERADE
```

> 💡 若外网网卡不是 `eth0`，可执行 `ip route get 8.8.8.8` 查找真实接口名并替换。

---

## ✅ 4. 验证连接 (Verify)

```bash
docker ps               # 查看容器状态
docker logs -f ocserv   # 实时查看运行日志
iptables -t nat -L POSTROUTING -n -v  # 确认 NAT 已命中
```

客户端（AnyConnect / OpenConnect）测试：
- ✅ 能成功认证连接；
- ✅ 能访问互联网；
- ✅ DNS 解析正常。

---

## 💾 5. 永久保存 NAT 配置 (Optional)

```bash
apt install -y iptables-persistent
netfilter-persistent save
```

---

## 🧩 6. 结构说明 (Project Structure)

| 路径 | 说明 |
|------|------|
| `config/` | ocserv 主配置模板（`ocserv.conf.tmpl`） |
| `radius/` | FreeRADIUS 客户端模板 |
| `certs/` | 证书目录（`fullchain.pem` / `privkey.pem`） |
| `run.sh` | 一键安装脚本 |
| `docker-compose.yml` | 启动定义文件 |

---

## 🧠 提示 / Notes

- 默认认证方式：**FreeRADIUS**  
- 证书路径：`certs/fullchain.pem` & `certs/privkey.pem`  
- 模板修改后需执行：`docker compose up -d`  
- 日志查看命令：`docker logs -f ocserv`

