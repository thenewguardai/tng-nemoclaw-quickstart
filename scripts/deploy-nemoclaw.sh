#!/usr/bin/env bash
# ============================================================================
# TNG NemoClaw — Deploy NemoClaw + OpenShell
# macOS (Docker Desktop), native Linux, and WSL2
#
# KEY INSIGHT: OpenShell runs k3s inside Docker. The Landlock/seccomp sandbox
# lives inside the container, not on the host. This means macOS works because
# Docker Desktop provides a Linux VM under the hood. The NemoClaw CLI is
# Node.js (cross-platform) and the openshell CLI ships Darwin + Linux binaries.
# ============================================================================

set -uo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="${HOME}/.tng-nemoclaw"

info()    { echo -e "${CYAN}[deploy]${NC} $1"; }
success() { echo -e "${GREEN}[deploy]${NC} $1"; }
warn()    { echo -e "${YELLOW}[deploy]${NC} $1"; }
fail()    { echo -e "${RED}[deploy]${NC} $1"; exit 1; }

# --- Detect environment -----------------------------------------------------
OS_TYPE="linux"
case "$(uname -s)" in
  Darwin) OS_TYPE="macos" ;;
  Linux)
    if grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
      OS_TYPE="wsl2"
    fi
    ;;
esac

# --- Fix cgroup v2 for Docker (Linux/WSL2 only) ----------------------------
fix_cgroup_v2() {
  # macOS: Docker Desktop manages cgroups internally — skip
  if [[ "${OS_TYPE}" == "macos" ]]; then
    info "macOS: Docker Desktop handles cgroup config — skipping."
    return
  fi

  # Check if cgroup v2 is in use
  if [[ ! -f /sys/fs/cgroup/cgroup.controllers ]]; then
    info "cgroup v1 — no fix needed."
    return
  fi

  info "cgroup v2 detected — checking Docker cgroupns config..."

  local DAEMON_JSON="/etc/docker/daemon.json"

  # Already configured?
  if [[ -f "${DAEMON_JSON}" ]]; then
    local CURRENT
    CURRENT=$(jq -r '.["default-cgroupns-mode"] // empty' "${DAEMON_JSON}" 2>/dev/null || true)
    if [[ "${CURRENT}" == "host" ]]; then
      success "Docker cgroupns=host already configured ✓"
      return
    fi
  fi

  # WSL2 with Docker Desktop: the daemon.json is managed by Docker Desktop on
  # the Windows side. /etc/docker/ usually doesn't even exist in the WSL2 distro.
  # Don't try to write a config that will be ignored.
  if [[ "${OS_TYPE}" == "wsl2" ]]; then
    # Multiple signals for Docker Desktop: no /etc/docker dir, or docker info context
    if [[ ! -d "/etc/docker" ]] || docker info 2>/dev/null | grep -qi "docker desktop\|desktop-linux"; then
      warn "Docker Desktop detected on WSL2."
      warn ""
      warn "Set cgroupns=host in Docker Desktop (not in WSL2):"
      warn "  1. Docker Desktop → Settings → Docker Engine"
      warn "  2. Add to the JSON:  \"default-cgroupns-mode\": \"host\""
      warn "  3. Click 'Apply & Restart'"
      warn ""
      warn "Or let NemoClaw handle it:"
      warn "  cd ~/.tng-nemoclaw/NemoClaw && nemoclaw setup-spark"
      warn ""
      warn "Continuing — the onboard wizard will prompt if this isn't set."
      return
    fi
  fi

  info "Configuring Docker for cgroupns=host..."

  # Ensure /etc/docker exists
  sudo mkdir -p /etc/docker

  # Build or update daemon.json
  if [[ -f "${DAEMON_JSON}" ]]; then
    local EXISTING
    EXISTING=$(cat "${DAEMON_JSON}" 2>/dev/null || echo "{}")
    if ! echo "${EXISTING}" | jq . &>/dev/null; then
      warn "Invalid JSON in ${DAEMON_JSON}. Backing up."
      sudo cp "${DAEMON_JSON}" "${DAEMON_JSON}.bak.$(date +%s)"
      EXISTING="{}"
    fi
    echo "${EXISTING}" | jq '. + {"default-cgroupns-mode": "host"}' | sudo tee "${DAEMON_JSON}" > /dev/null
  else
    echo '{"default-cgroupns-mode": "host"}' | sudo tee "${DAEMON_JSON}" > /dev/null
  fi

  # Restart Docker
  info "Restarting Docker..."
  if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null 2>&1; then
    sudo systemctl restart docker
  else
    sudo service docker restart 2>/dev/null || true
  fi

  local RETRIES=0
  while ! docker ps &>/dev/null 2>&1; do
    ((RETRIES++))
    if [[ ${RETRIES} -gt 15 ]]; then
      fail "Docker didn't restart. Check 'sudo service docker status'."
    fi
    sleep 2
  done

  success "Docker restarted with cgroupns=host ✓"
}

# --- Clone OpenShell --------------------------------------------------------
clone_openshell() {
  local DIR="${INSTALL_DIR}/OpenShell"

  if [[ -d "${DIR}" ]]; then
    info "OpenShell exists. Pulling latest..."
    cd "${DIR}" && git pull --ff-only 2>/dev/null || warn "Pull failed — using existing."
  else
    info "Cloning NVIDIA OpenShell..."
    git clone https://github.com/NVIDIA/OpenShell.git "${DIR}"
  fi
  success "OpenShell source ready ✓"
}

# --- Install OpenShell ------------------------------------------------------
install_openshell() {
  local DIR="${INSTALL_DIR}/OpenShell"
  cd "${DIR}"

  info "Installing OpenShell..."

  if [[ -f "install.sh" ]]; then
    chmod +x install.sh
    bash install.sh
  elif [[ -f "Makefile" ]]; then
    make build
  else
    warn "No standard install method found."
  fi

  # Verify — check common install locations
  if command -v openshell &>/dev/null; then
    success "openshell $(openshell --version 2>/dev/null || echo '') ✓"
  elif [[ -f "${HOME}/.local/bin/openshell" ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
    success "openshell installed to ~/.local/bin ✓"
  else
    warn "openshell not found in PATH."
    warn "Try: export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
}

# --- Clone NemoClaw ---------------------------------------------------------
clone_nemoclaw() {
  local DIR="${INSTALL_DIR}/NemoClaw"

  if [[ -d "${DIR}" ]]; then
    info "NemoClaw exists. Pulling latest..."
    cd "${DIR}" && git pull --ff-only 2>/dev/null || warn "Pull failed — using existing."
  else
    info "Cloning NVIDIA NemoClaw..."
    git clone https://github.com/NVIDIA/NemoClaw.git "${DIR}"
  fi
  success "NemoClaw source ready ✓"
}

# --- Run NemoClaw installer -------------------------------------------------
install_nemoclaw() {
  local DIR="${INSTALL_DIR}/NemoClaw"
  cd "${DIR}"

  info "Running NemoClaw installer..."

  chmod +x install.sh

  # Build env
  local ENV_VARS=()
  if [[ -n "${NVIDIA_API_KEY:-}" ]]; then
    ENV_VARS+=("NVIDIA_API_KEY=${NVIDIA_API_KEY}")
    info "Using NVIDIA API key from environment."
  elif [[ -f "${HOME}/.nvidia-api-key" ]]; then
    ENV_VARS+=("NVIDIA_API_KEY=$(cat "${HOME}/.nvidia-api-key")")
    info "Using NVIDIA API key from ~/.nvidia-api-key."
  else
    info "No NVIDIA API key — installer will prompt or use local inference."
  fi

  # macOS note: NemoClaw's install.sh may warn about Ubuntu.
  # The sandbox runs inside Docker (Linux containers), so this is fine.
  if [[ "${OS_TYPE}" == "macos" ]]; then
    info ""
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "  macOS note: NemoClaw's installer may warn about OS support."
    info "  The sandbox runs inside Docker (Linux containers), so the"
    info "  Landlock/seccomp security layer works regardless of host OS."
    info "  If the installer exits early, finish manually:"
    info ""
    info "    cd ${DIR}"
    info "    npm install"
    info "    npm link"
    info "    nemoclaw onboard"
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info ""
  fi

  # Run it
  if [[ ${#ENV_VARS[@]} -gt 0 ]]; then
    env "${ENV_VARS[@]}" ./install.sh
  else
    ./install.sh
  fi

  local EXIT_CODE=$?
  if [[ ${EXIT_CODE} -ne 0 ]]; then
    warn "Installer exited with code ${EXIT_CODE}."
    warn ""
    warn "This is common — the onboard wizard may need manual steps."
    warn "To complete setup manually:"
    warn ""
    warn "  cd ${DIR}"
    if [[ "${OS_TYPE}" != "macos" ]]; then
      warn "  nemoclaw setup-spark    # fix cgroup config (Linux/WSL2)"
    fi
    warn "  nemoclaw onboard        # re-run the setup wizard"
    warn ""
    warn "Continuing with policy setup..."
  fi
}

# --- Post-install: find nemoclaw in PATH -----------------------------------
post_install_fixups() {
  if command -v nemoclaw &>/dev/null 2>&1; then
    success "nemoclaw CLI available ✓"
    return
  fi

  # Search common locations
  local DIR="${INSTALL_DIR}/NemoClaw"
  for BIN_PATH in \
    "${DIR}/node_modules/.bin/nemoclaw" \
    "$(npm root -g 2>/dev/null)/nemoclaw/bin/nemoclaw" \
    "${HOME}/.npm-global/bin/nemoclaw" \
    "/usr/local/bin/nemoclaw"; do
    if [[ -f "${BIN_PATH}" 2>/dev/null ]]; then
      export PATH="$(dirname "${BIN_PATH}"):${PATH}"
      success "Found nemoclaw at $(dirname "${BIN_PATH}") ✓"
      return
    fi
  done

  warn "nemoclaw not found in PATH after install."
}

# --- Verify installation ----------------------------------------------------
verify() {
  info "Verifying installation..."
  echo ""

  for CMD in nemoclaw openshell; do
    if command -v "${CMD}" &>/dev/null 2>&1; then
      success "${CMD} CLI ✓"
    else
      warn "${CMD} not in PATH — add ~/.local/bin to your PATH"
    fi
  done

  echo ""
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "  If the onboard wizard didn't complete, finish it:"
  info ""
  info "    cd ${INSTALL_DIR}/NemoClaw"
  info "    nemoclaw onboard"
  if [[ "${OS_TYPE}" != "macos" ]]; then
    info ""
    info "  If it stopped on a cgroup error (Linux/WSL2 only):"
    info "    nemoclaw setup-spark"
  fi
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# --- Main -------------------------------------------------------------------
main() {
  mkdir -p "${INSTALL_DIR}"

  fix_cgroup_v2
  clone_openshell
  install_openshell
  clone_nemoclaw
  install_nemoclaw
  post_install_fixups
  verify

  success "NemoClaw deployment phase complete."
}

main "$@"
