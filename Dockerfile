FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

# --- Robust apt install on Debian 12 (IPv4 + retries + full sources) ---
RUN set -eux; \
    # 1) 写全 sources.list，包含 main / updates / security / non-free-firmware
    printf '%s\n' \
      'deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware' \
      'deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware' \
      'deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware' \
      > /etc/apt/sources.list; \
    # 如在国内或网络不稳，可切换镜像：取消下一行注释
    # sed -i 's|http://deb.debian.org|http://mirrors.aliyun.com|g;s|http://security.debian.org|http://mirrors.aliyun.com|g' /etc/apt/sources.list; \
    # 2) 强制走 IPv4，增加重试，更新索引
    apt-get -o Acquire::ForceIPv4=true -o Acquire::Retries=5 update; \
    # 3) 安装依赖
    apt-get install -y --no-install-recommends \
        ca-certificates gnupg dirmngr \
        ocserv radcli radcli-dicts \
        dumb-init gettext-base \
        iproute2 iptables nftables procps iputils-ping curl \
    ; \
    # 4) 清理
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 运行期目录
RUN mkdir -p /etc/ocserv /etc/radcli /run/ocserv /app/config /app/radius /app/certs

EXPOSE 1600/tcp 1600/udp
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/app/entrypoint.sh"]
