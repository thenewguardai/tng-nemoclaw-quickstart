#!/usr/bin/env bash
# ============================================================================
# TNG NemoClaw — Prerequisite Installer
# Handles macOS (Docker Desktop), native Linux, and WSL2
# ============================================================================

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[prereqs]${NC} $1"; }
success() { echo -e "${GREEN}[prereqs]${NC} $1"; }
warn()    { echo -e "${YELLOW}[prereqs]${NC} $1"; }
fail()    { echo -e "${RED}[prereqs]${NC} $1"; exit 1; }

# --- Environment detection --------------------------------------------------
OS_TYPE="unknown"   # "macos", "linux", "wsl2"
HAS_SYSTEMD=false

detect_environment() {
  case "$(uname -s)" in
    Darwin)
      OS_TYPE="macos"
      info "macOS detected ($(uname -m))."
      ;;
    Linux)
      if grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
        OS_TYPE="wsl2"
        info "WSL2 environment detected."
      else
        OS_TYPE="linux"
        info "Native Linux detected."
      fi
      # Check for systemd
      if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null 2>&1; then
        HAS_SYSTEMD=true
      fi
      ;;
    *)
      fail "Unsupported OS: $(uname -s). NemoClaw supports macOS and Linux."
      ;;
  esac
}

# --- Helper: start Docker daemon -------------------------------------------
start_docker() {
  if [[ "${OS_TYPE}" == "macos" ]]; then
    # macOS: Docker Desktop manages the daemon — we can try to launch it
    if open -a "Docker" 2>/dev/null; then
      info "Launched Docker Desktop. Waiting for daemon..."
      local retries=0
      while ! docker ps &>/dev/null 2>&1; do
        ((retries++))
        [[ ${retries} -gt 30 ]] && return 1
        sleep 2
      done
      return 0
    fi
    return 1
  fi

  # Linux / WSL2
  if [[ "${HAS_SYSTEMD}" == true ]]; then
    sudo systemctl start docker && return 0
  fi
  sudo service docker start 2>/dev/null && return 0
  return 1
}

# --- Git --------------------------------------------------------------------
install_git() {
  if command -v git &>/dev/null; then
    success "Git $(git --version | awk '{print $3}') ✓"
    return
  fi

  info "Installing Git..."
  case "${OS_TYPE}" in
    macos)
      # macOS: xcode-select provides git, or use brew
      if command -v brew &>/dev/null; then
        brew install git
      else
        xcode-select --install 2>/dev/null || true
        warn "Install Xcode Command Line Tools if prompted, then re-run."
      fi
      ;;
    linux|wsl2)
      sudo apt-get update -qq && sudo apt-get install -y -qq git
      ;;
  esac
  success "Git installed ✓"
}

# --- Docker -----------------------------------------------------------------
install_docker() {
  if command -v docker &>/dev/null; then
    success "Docker $(docker --version | awk '{print $3}' | tr -d ',') ✓"
  else
    # Not installed
    case "${OS_TYPE}" in
      macos)
        fail "Docker not found. Install Docker Desktop for Mac:\n  https://www.docker.com/products/docker-desktop/\n  Then re-run this script."
        ;;
      wsl2)
        fail "Docker not found. Install Docker Desktop for Windows with WSL integration:\n  https://www.docker.com/products/docker-desktop/\n  Settings → Resources → WSL Integration → enable your distro."
        ;;
      linux)
        info "Installing Docker..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        rm /tmp/get-docker.sh
        start_docker || warn "Could not auto-start Docker."
        sudo usermod -aG docker "${USER}" 2>/dev/null || true
        success "Docker installed ✓"
        warn "You may need to log out/in for group permissions."
        ;;
    esac
  fi

  # Verify daemon is reachable
  if docker ps &>/dev/null 2>&1; then
    success "Docker daemon reachable ✓"
  else
    warn "Docker CLI present but daemon not responding. Attempting to start..."
    if start_docker; then
      sleep 2
      if docker ps &>/dev/null 2>&1; then
        success "Docker started ✓"
        return
      fi
    fi

    echo ""
    case "${OS_TYPE}" in
      macos)
        warn "Open Docker Desktop and wait for it to finish starting."
        ;;
      wsl2)
        warn "Start Docker Desktop on Windows, or run: sudo service docker start"
        ;;
      linux)
        warn "Run: sudo service docker start (or sudo systemctl start docker)"
        ;;
    esac
    fail "Docker daemon not reachable. Start it and re-run this script."
  fi
}

# --- Node.js ----------------------------------------------------------------
install_node() {
  if command -v node &>/dev/null; then
    success "Node.js $(node --version) ✓"
    return
  fi

  info "Installing Node.js..."
  case "${OS_TYPE}" in
    macos)
      if command -v brew &>/dev/null; then
        brew install node@20
      else
        warn "Install Homebrew first: https://brew.sh"
        warn "Then: brew install node@20"
        fail "Node.js required. Install via Homebrew or nvm."
      fi
      ;;
    linux|wsl2)
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo apt-get install -y -qq nodejs
      ;;
  esac
  success "Node.js $(node --version) installed ✓"
}

# --- Build essentials (Linux only) ------------------------------------------
install_build_deps() {
  case "${OS_TYPE}" in
    macos)
      # Check for Homebrew — needed for some deps
      if ! command -v brew &>/dev/null; then
        warn "Homebrew not found. Some optional deps may be missing."
        warn "Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      fi
      # jq is useful for health checks and policy work
      if ! command -v jq &>/dev/null; then
        if command -v brew &>/dev/null; then
          info "Installing jq..."
          brew install jq
        fi
      fi
      success "macOS build dependencies ✓"
      ;;
    linux|wsl2)
      info "Installing build dependencies..."
      sudo apt-get update -qq
      sudo apt-get install -y -qq \
        build-essential \
        curl \
        wget \
        jq \
        ca-certificates \
        gnupg \
        lsb-release
      success "Build dependencies ✓"
      ;;
  esac
}

# --- NVIDIA API key check ---------------------------------------------------
check_nvidia_key() {
  if [[ -n "${NVIDIA_API_KEY:-}" ]]; then
    success "NVIDIA API key found in environment ✓"
  elif [[ -f "${HOME}/.nvidia-api-key" ]]; then
    success "NVIDIA API key found at ~/.nvidia-api-key ✓"
  else
    info ""
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "  No NVIDIA API key detected."
    info ""
    info "  For cloud inference (default profile), you need one."
    info "  Get a free key at: https://build.nvidia.com"
    info ""
    info "  Then either:"
    info "    export NVIDIA_API_KEY='your-key-here'"
    info "    # or"
    info "    echo 'your-key-here' > ~/.nvidia-api-key"
    info ""
    info "  You can skip this if using local vLLM inference only."
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info ""
  fi
}

# --- Main -------------------------------------------------------------------
main() {
  info "Installing prerequisites..."
  detect_environment
  install_build_deps
  install_git
  install_docker
  install_node
  check_nvidia_key
  success "All prerequisites installed."
}

main "$@"
