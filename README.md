🐋 ocserv-docker 使用说明 / Usage Guide
🚀 1. 一键安装 (Automatic Installation)

在服务器上执行以下命令即可自动安装与部署：

TOKEN="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" && \
bash -c "$(curl -fsSL -H "Authorization: Bearer $TOKEN" https://raw.githubusercontent.com/jackzhang-superman/ocserv-docker/main/run.sh)" -- -u jackzhang-superman -t "$TOKEN"


🧩 安装完成后将自动构建并启动 ocserv 容器。
⚙️ 2. 修改服务器标识 (Custom Banner)

每台服务器的 Banner 可在 docker-compose.yml 中自定义：

编辑以下部分：

environment:
  BANNER: "欢迎使用 节点-(官网地址为：https://www.cyberfly.org)"


根据实际节点信息修改后保存，然后重新启动：

docker compose up -d

🌐 3. 启用 NAT 与 转发 (Enable NAT & IP Forwarding)

⚠️ 否则客户端能连接但无法访问外网。

执行以下命令开启内核转发与 NAT：

sysctl -w net.ipv4.ip_forward=1
iptables -P FORWARD ACCEPT
iptables -t nat -F POSTROUTING
iptables -A FORWARD -i vpns0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o vpns0 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth0 -j MASQUERADE


💡 若外网网卡不是 eth0，请用 ip route get 8.8.8.8 查询实际名称并替换。

✅ 4. 验证连接 (Verify)
docker ps               # 确认容器正在运行
docker logs -f ocserv   # 查看运行日志
iptables -t nat -L POSTROUTING -n -v  # NAT 命中计数应递增


客户端（AnyConnect / OpenConnect）应能：

✅ 成功连接并认证；

✅ 访问互联网；

✅ DNS 解析正常。

💾 5. 永久保存 NAT 配置 (Optional)
apt install -y iptables-persistent
netfilter-persistent save

🧠 提示 / Notes

默认认证方式为 FreeRADIUS（可在 RADIUS_SERVER 环境变量中修改）。

证书放在 certs/ 目录下的 fullchain.pem 与 privkey.pem。

配置模板位于 config/ocserv.conf.tmpl，修改后执行 docker compose up -d 生效。
