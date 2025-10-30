FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

RUN set -eux; \
    rm -f /etc/apt/sources.list.d/debian.sources; \
    printf '%s\n' \
      'deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware' \
      'deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware' \
      'deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware' \
      > /etc/apt/sources.list; \
    APT_FLAGS="-o Acquire::ForceIPv4=true -o Acquire::Retries=5"; \
    (apt-get ${APT_FLAGS} update) || ( \
      sed -i 's|http://deb.debian.org|http://mirrors.aliyun.com|g; s|http://security.debian.org|http://mirrors.aliyun.com|g' /etc/apt/sources.list; \
      apt-get ${APT_FLAGS} update \
    ); \
    apt-get install -y --no-install-recommends --fix-missing \
      ca-certificates gnupg dirmngr \
      ocserv radcli radcli-dicts \
      dumb-init gettext-base \
      iproute2 iptables nftables procps iputils-ping curl; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
RUN mkdir -p /etc/ocserv /etc/radcli /run/ocserv /app/config /app/radius /app/certs

EXPOSE 1600/tcp 1600/udp
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/app/entrypoint.sh"]
