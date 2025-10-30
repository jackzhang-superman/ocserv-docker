#!/usr/bin/env bash
set -Eeuo pipefail

: "${VPN_TCP_PORT:=1600}"
: "${VPN_UDP_PORT:=1600}"
: "${KEEPALIVE:=300}"
: "${STATS_REPORT:=600}"
: "${DPD:=120}"
: "${MOBILE_DPD:=90}"
: "${TLS_PRIORITIES:=NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0}"
: "${MAX_CLIENTS:=51200}"
: "${MAX_SAME:=10000}"
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
  fi
  if [[ ! -f "$RADCLI_SERVERS" || "$FORCE_TEMPLATE" == "true" ]]; then
    envsubst < /app/radius/servers.tmpl > "$RADCLI_SERVERS"
    chmod 600 "$RADCLI_SERVERS"
  fi
}

check_certs() {
  [[ -f /etc/ocserv/cyberfly.org/fullchain.pem ]] || { echo "缺少 fullchain.pem"; exit 1; }
  [[ -f /etc/ocserv/cyberfly.org/privkey.pem  ]] || { echo "缺少 privkey.pem";  exit 1; }
  chmod 600 /etc/ocserv/cyberfly.org/privkey.pem || true
}

enable_forwarding() {
  sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
  [[ "$ENABLE_IPV6" == "true" ]] && sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1 || true
}

start() {
  echo "[INFO] starting ocserv on TCP ${VPN_TCP_PORT} / UDP ${VPN_UDP_PORT}"
  exec ocserv -f -c "$OCSERV_CONF" -d 1
}

ensure_tun
render_conf
check_certs
enable_forwarding
start
