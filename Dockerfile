FROM debian:bookworm
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ocserv dumb-init gettext-base ca-certificates \
      iproute2 iptables nftables procps iputils-ping curl; \
    (apt-get install -y --no-install-recommends radcli radcli-dicts) \
      || apt-get install -y --no-install-recommends libradcli4; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
RUN mkdir -p /etc/ocserv /etc/radcli /run/ocserv /app/config /app/radius /app/certs

EXPOSE 1600/tcp 1600/udp
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/app/entrypoint.sh"]
