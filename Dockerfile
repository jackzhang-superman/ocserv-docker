FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# ---- Robust apt path: full sources + IPv4 + retry + mirror fallback ----
RUN set -eux; \
    # 1) 写全 sources.list（含 security / updates / non-free-firmware）
    printf '%s\n' \
      'deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware' \
      'deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware' \
      'deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware' \
      > /etc/apt/sources.list; \
    # 2) 先尝试官方源，失败则自动切换到阿里云镜像再重试
    APT_FLAGS='-o Acquire::ForceIPv4=true -o Acquire::Retries=5'; \
    (apt-get ${APT_FLAGS} update) || ( \
      sed -i 's|http://deb.debian.org|http://mirrors.aliyun.com|g; s|http://security.debian.org|http://mirrors.aliyun.com|g' /etc/apt/sources.list; \
      apt-get ${APT_FLAGS} update \
    ); \
    # 3) 安装运行期依赖；--fix-missing 提升成功率
    apt-get install -y --no-install-recommends --fix-missing \
        ca-certificates gnupg dirmngr \
        ocserv radcli radcli-dicts \
        dumb-init gettext-base \
        iproute2 iptables nftables procps iputils-ping curl \
    ; \
    # 4) 清理缓存，减小镜像体积
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 运行期必备目录
RUN mkdir -p /etc/ocserv /etc/radcli /run/ocserv /app/config /app/radius /app/certs

EXPOSE 1600/tcp 1600/udp
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/app/entrypoint.sh"]
