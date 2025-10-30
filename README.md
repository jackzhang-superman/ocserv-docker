# 🐳 ocserv-docker

Dockerized **Cisco AnyConnect (ocserv)** with **FreeRADIUS authentication**.

> ⚠️ This repo contains production-ready defaults **including RADIUS IP & secret** as per user's request (Plan B).
> If you fork it publicly, consider replacing them with environment placeholders.

---

## 🚀 Quick Start

```bash
git clone https://github.com/YOUR_GITHUB_NAME/ocserv-docker.git
cd ocserv-docker

# Put your certificates
mkdir -p certs
# Place: certs/fullchain.pem  certs/privkey.pem  [optional certs/cert.pem]

docker compose build
docker compose up -d
docker compose logs -f
```

Once up, ocserv listens on **TCP/UDP 1600** (host network).

---

## 🔐 RADIUS Settings (default in compose)
```
RADIUS_SERVER = 139.162.17.63
RADIUS_SECRET = testing123
AUTH_PORT     = 1812
ACCT_PORT     = 1813
```

You can change them in `docker-compose.yml` at any time.

---

## 📂 Repo Layout
```
.
├─ Dockerfile
├─ docker-compose.yml
├─ entrypoint.sh
├─ config/
│  └─ ocserv.conf.tmpl
├─ radius/
│  ├─ radiusclient.conf.tmpl
│  └─ servers.tmpl
└─ certs/
   └─ README.txt
```

---

## ⚙️ Notes
- Host network is used for best DTLS performance.
- File descriptor limits are set via compose `ulimits` (51200).
- Templates are rendered at container start. You can override env vars in compose.
- Never commit your **private keys** to GitHub.

---

## 🧪 Verify RADIUS connectivity (from host)
```bash
# Install radcli or freeradius-utils on host if needed and run:
radtest jack your_password 139.162.17.63 0 testing123
```
Expect `Access-Accept` on success.
