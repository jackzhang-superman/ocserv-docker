#!/usr/bin/env bash
set -Eeuo pipefail

# =====================================================
# ocserv-docker One‑liner installer / runner
# Supports private GitHub repo via Personal Access Token (PAT).
# Usage examples:
#   TOKEN="ghp_xxx" bash run.sh -u YOUR_GITHUB_USER -t "$TOKEN"
#   TOKEN="ghp_xxx" bash run.sh -u YOUR_GITHUB_USER -r ocserv-docker -b main -d /opt/ocserv-docker
#
# Flags:
#   -u|--user       GitHub username/owner (required)
#   -r|--repo       Repository name (default: ocserv-docker)
#   -b|--branch     Branch name (default: main)
#   -t|--token      GitHub fine-grained PAT with 'contents:read' (optional if repo is public)
#   -d|--dir        Target directory to clone into (default: ./ocserv-docker)
#   --no-build      Skip 'docker compose build' (use prebuilt image or remote buildkit)
#   --pull          Run 'docker compose pull' before up (if using registry images)
# =====================================================

GH_USER=""
GH_REPO="ocserv-docker"
GH_BRANCH="main"
TARGET_DIR=""
GITHUB_TOKEN="${TOKEN:-}"
DO_BUILD="yes"
DO_PULL="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--user)   GH_USER="$2"; shift 2;;
    -r|--repo)   GH_REPO="$2"; shift 2;;
    -b|--branch) GH_BRANCH="$2"; shift 2;;
    -t|--token)  GITHUB_TOKEN="$2"; shift 2;;
    -d|--dir)    TARGET_DIR="$2"; shift 2;;
    --no-build)  DO_BUILD="no"; shift 1;;
    --pull)      DO_PULL="yes"; shift 1;;
    -h|--help)
      grep '^# ' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

if [[ -z "${GH_USER}" ]]; then
  echo "[FATAL] Missing GitHub user/owner. Use -u YOUR_GITHUB_USER"
  exit 1
fi

if [[ -z "${TARGET_DIR}" ]]; then
  TARGET_DIR="./${GH_REPO}"
fi

REPO_URL="https://github.com/${GH_USER}/${GH_REPO}.git"
if [[ -n "${GITHUB_TOKEN}" ]]; then
  # Embed token only for the clone command to avoid persisting in origin url
  AUTH_REPO_URL="https://${GITHUB_TOKEN}@github.com/${GH_USER}/${GH_REPO}.git"
else
  AUTH_REPO_URL="${REPO_URL}"
fi

# ------- helpers -------
log() { printf "\033[1;32m[INFO]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
die() { printf "\033[1;31m[FATAL]\033[0m %s\n" "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# ------- install Docker if missing -------
install_docker() {
  if need_cmd docker; then
    log "Docker already installed: $(docker --version | head -n1)"
    return
  fi

  OS_FAMILY=""
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_FAMILY="${ID:-}"
  fi

  log "Installing Docker CE ... (detected: ${OS_FAMILY:-unknown})"
  case "$OS_FAMILY" in
    ubuntu|debian)
      apt-get update -y
      apt-get install -y ca-certificates curl gnupg lsb-release
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/${OS_FAMILY}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_FAMILY} \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list
      apt-get update -y
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
    centos|rhel|rocky|almalinux)
      yum install -y yum-utils device-mapper-persistent-data lvm2
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || \
      dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      systemctl enable docker
      systemctl start docker
      ;;
    *)
      warn "Unknown distro. Using convenience script."
      curl -fsSL https://get.docker.com | sh
      ;;
  esac

  if ! need_cmd docker; then
    die "Docker installation failed."
  fi
}

# ------- ensure compose plugin -------
ensure_compose() {
  if docker compose version >/dev/null 2>&1; then
    log "Docker Compose plugin OK: $(docker compose version | head -n1)"
    return
  fi
  warn "Docker Compose plugin not found. Attempting to install (plugin) ..."
  # Try installing compose plugin via package manager if not already done in install_docker()
  if need_cmd apt-get; then
    apt-get update -y || true
    apt-get install -y docker-compose-plugin || true
  elif need_cmd yum || need_cmd dnf; then
    (yum install -y docker-compose-plugin || dnf install -y docker-compose-plugin) || true
  fi

  if ! docker compose version >/dev/null 2>&1; then
    # fallback to legacy docker-compose binary
    warn "Falling back to legacy docker-compose"
    if ! need_cmd curl; then
      die "curl required to install legacy docker-compose"
    fi
    DEST="/usr/local/bin/docker-compose"
    curl -L "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-$(uname -s)-$(uname -m)" -o "$DEST"
    chmod +x "$DEST"
    if ! need_cmd docker-compose; then
      die "Failed to install docker-compose"
    fi
    # Create a shim to map 'docker compose' calls
    if ! command -v docker >/dev/null 2>&1; then
      die "Docker is required"
    fi
    # provide a small wrapper for 'docker compose'
    mkdir -p /usr/local/libexec
    cat >/usr/local/libexec/docker-compose-shim <<'EOF'
#!/usr/bin/env bash
exec docker-compose "$@"
EOF
    chmod +x /usr/local/libexec/docker-compose-shim
    # alias function for current shell
    docker() {
      if [[ "$1" == "compose" ]]; then shift; /usr/local/libexec/docker-compose-shim "$@"; else command docker "$@"; fi
    }
    export -f docker || true
    log "Legacy docker-compose installed."
  fi
}

# ------- clone repo (private supported) -------
clone_repo() {
  if [[ -d "${TARGET_DIR}/.git" ]]; then
    log "Repo exists at ${TARGET_DIR}. Pulling latest from ${GH_BRANCH} ..."
    git -C "${TARGET_DIR}" fetch origin "${GH_BRANCH}"
    git -C "${TARGET_DIR}" checkout "${GH_BRANCH}"
    git -C "${TARGET_DIR}" pull --ff-only origin "${GH_BRANCH}"
    return
  fi

  log "Cloning ${GH_USER}/${GH_REPO}@${GH_BRANCH} into ${TARGET_DIR} ..."
  git clone --branch "${GH_BRANCH}" --depth 1 "${AUTH_REPO_URL}" "${TARGET_DIR}"
  # Reset remote URL to non-token form so token won't persist on disk
  git -C "${TARGET_DIR}" remote set-url origin "${REPO_URL}"
}

# ------- deploy with compose -------
deploy() {
  cd "${TARGET_DIR}"
  mkdir -p certs
  if [[ ! -f certs/fullchain.pem || ! -f certs/privkey.pem ]]; then
    warn "certs/fullchain.pem or certs/privkey.pem not found."
    echo "  Place your certificate files under: $(pwd)/certs/"
    echo "  Names: fullchain.pem  privkey.pem  [optional cert.pem]"
  fi

  if [[ "${DO_PULL}" == "yes" ]]; then
    log "docker compose pull ..."
    docker compose pull || true
  fi

  if [[ "${DO_BUILD}" == "yes" ]]; then
    log "docker compose build ..."
    docker compose build
  fi

  log "docker compose up -d ..."
  docker compose up -d

  log "Deployment finished."
  echo "Check logs: docker compose logs -f"
}

main() {
  need_cmd git || die "git is required."
  install_docker
  ensure_compose
  clone_repo
  deploy
}

main "$@"
