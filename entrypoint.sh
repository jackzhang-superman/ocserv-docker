#!/usr/bin/env bash
set -Eeuo pipefail

: "${VPN_TCP_PORT:=1600}"
: "${VPN_UDP_PORT:=1600}"
: "${KEEPALIVE:=300}"
: "${STATS_REPORT:=600}"
: "${DPD:=120}"
: "${MOBILE_DPD:=90}"
: "${TLS_PRIORITIES:=NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0}"
: "${MAX_CLIENTS:=4096}"
: "${MAX_SAME:=6400}"
: "${DEVICE:=vpns}"
: "${DEFAULT_DOMAIN:=example.com}"
: "${DNS:=8.8.8.8,8.8.4.4}"
: "${LOG_FILE:=/var/log/ocserv.log}"
: "${BANNER:=欢迎使用 节点-(官网地址为：https://www.cyberfly.org)}"
: "${ENABLE_CISCO_COMPAT:=true}"
: "${ENABLE_DTLS_LEGACY:=true}"
: "${ENABLE_IPV6:=false}"

: "${RADIUS_SERVER:=139.162.17.63}"
: "${RADIUS_AUTH_PORT:=1812}"
: "${RADIUS_ACCT_PORT:=1813}"
: "${RADIUS_SECRET:=testing123}"
: "${RADIUS_NAS_IDENTIFIER:=ocserv-docker-prod}"
: "${FORCE_TEMPLATE:=true}"

OCSERV_CONF=/etc/ocserv/ocserv.conf
RADCLI_CONF=/etc/radcli/radiusclient.conf
RADCLI_SERVERS=/etc/radcli/servers

ensure_tun() {
  [[ -e /dev/net/tun ]] || { mkdir -p /dev/net && mknod /dev/net/tun c 10 200 || true; }
}

render_conf() {
  export DNS_LINES=""
  IFS=',' read -ra arr <<< "${DNS}"
  for d in "${arr[@]}"; do
    DNS_LINES+="dns = ${d}\n"
  done

  if [[ ! -f "$OCSERV_CONF" || "$FORCE_TEMPLATE" == "true" ]]; then
    envsubst < /app/config/ocserv.conf.tmpl | sed 's/\\n/\n/g' > "$OCSERV_CONF"
  fi
  if [[ ! -f "$RADCLI_CONF" || "$FORCE_TEMPLATE" == "true" ]]; then
    envsubst < /app/radius/radiusclient.conf.tmpl > "$RADCLI_CONF"
    # 兼容性修正：模板若误写为 nas_identifier，这里强制替换为 radcli 标准 nas-identifier
    sed -i 's/^nas_identifier/nas-identifier/' "$RADCLI_CONF" || true
  fi
  if [[ ! -f "$RADCLI_SERVERS" || "$FORCE_TEMPLATE" == "true" ]]; then
    envsubst < /app/radius/servers.tmpl > "$RADCLI_SERVERS"
    chmod 600 "$RADCLI_SERVERS" || true
  fi
}

deploy_profile() {
  if [[ -f /app/config/profile.xml ]]; then
    install -m 0644 /app/config/profile.xml /etc/ocserv/profile.xml
    echo "[INFO] profile.xml deployed to /etc/ocserv/profile.xml"
  else
    echo "[WARN] /app/config/profile.xml not found; skipping profile deployment."
  fi
}

fix_radcli_dict() {
  # 优先使用 /usr/share/radcli/dictionary；若无则尝试从 FreeRADIUS 软链
  if [[ ! -e /usr/share/radcli/dictionary ]]; then
    if [[ -e /usr/share/freeradius/dictionary ]]; then
      mkdir -p /usr/share/radcli
      ln -s /usr/share/freeradius/dictionary /usr/share/radcli/dictionary
      echo "[INFO] radcli dictionary -> /usr/share/freeradius/dictionary"
    fi
  fi

  # 部分环境 ocserv/radcli 会找 dictionary.compat；给它一个兜底的软链
  if [[ -e /usr/share/radcli/dictionary && ! -e /usr/share/radcli/dictionary.compat ]]; then
    ln -s /usr/share/radcli/dictionary /usr/share/radcli/dictionary.compat
    echo "[INFO] created /usr/share/radcli/dictionary.compat symlink"
  fi

  # 我们的 radiusclient.conf 指向 /etc/radcli/dictionary —— 确保这个路径也可用
  if [[ -e /usr/share/radcli/dictionary && ! -e /etc/radcli/dictionary ]]; then
    ln -s /usr/share/radcli/dictionary /etc/radcli/dictionary
    echo "[INFO] /etc/radcli/dictionary -> /usr/share/radcli/dictionary"
  fi

  # 最终兜底：仍然不存在则报错退出，避免 sec-mod 死循环
  if [[ ! -e /usr/share/radcli/dictionary && ! -e /etc/radcli/dictionary ]]; then
    echo "[ERROR] radcli dictionary not found. Install radcli-dicts or freeradius-common."
    exit 1
  fi
}


check_certs() {
  [[ -f /etc/ocserv/cyberfly.org/fullchain.pem ]] || { echo "缺少 fullchain.pem"; exit 1; }
  [[ -f /etc/ocserv/cyberfly.org/privkey.pem  ]] || { echo "缺少 privkey.pem";  exit 1; }
  # 只在可写时调整权限，避免只读挂载报错
  if [[ -w /etc/ocserv/cyberfly.org/privkey.pem ]]; then
    chmod 600 /etc/ocserv/cyberfly.org/privkey.pem || true
  fi
}

enable_forwarding() {
  # host 网络下 Docker 可能不允许 sysctl，这里失败也不致命
  sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
  [[ "$ENABLE_IPV6" == "true" ]] && sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1 || true
}

tune_limits() {
  # 提高容器内进程可打开文件数，若宿主未允许则忽略
  ulimit -n 131072 || true
}

start() {
  echo "[INFO] starting ocserv on TCP ${VPN_TCP_PORT} / UDP ${VPN_UDP_PORT}"
  exec ocserv -f -c "$OCSERV_CONF" -d 1
}

ensure_tun
render_conf
deploy_profile
fix_radcli_dict
check_certs
enable_forwarding
tune_limits
start
