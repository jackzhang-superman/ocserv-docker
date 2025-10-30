FROM debian:bookworm
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    ocserv radcli radcli-dicts \
    dumb-init gettext-base ca-certificates \
    iproute2 iptables nftables procps iputils-ping curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
RUN mkdir -p /etc/ocserv /etc/radcli /run/ocserv /app/config /app/radius /app/certs

EXPOSE 1600/tcp 1600/udp
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/app/entrypoint.sh"]
