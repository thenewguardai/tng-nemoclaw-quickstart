#!/usr/bin/env bash
# ============================================================================
# TNG NemoClaw — Deploy NemoClaw + OpenShell
# Clones repos, builds OpenShell, runs NemoClaw installer
# ============================================================================

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="${HOME}/.tng-nemoclaw"

info()    { echo -e "${CYAN}[deploy]${NC} $1"; }
success() { echo -e "${GREEN}[deploy]${NC} $1"; }
warn()    { echo -e "${YELLOW}[deploy]${NC} $1"; }
fail()    { echo -e "${RED}[deploy]${NC} $1"; exit 1; }

# --- Clone OpenShell --------------------------------------------------------
clone_openshell() {
  OPENSHELL_DIR="${INSTALL_DIR}/OpenShell"

  if [[ -d "${OPENSHELL_DIR}" ]]; then
    info "OpenShell directory exists. Pulling latest..."
    cd "${OPENSHELL_DIR}" && git pull --ff-only
  else
    info "Cloning NVIDIA OpenShell..."
    git clone https://github.com/NVIDIA/OpenShell.git "${OPENSHELL_DIR}"
  fi

  success "OpenShell source ready at ${OPENSHELL_DIR} ✓"
}

# --- Install OpenShell ------------------------------------------------------
install_openshell() {
  OPENSHELL_DIR="${INSTALL_DIR}/OpenShell"
  cd "${OPENSHELL_DIR}"

  info "Installing OpenShell..."

  # OpenShell has its own install process — follow their docs
  if [[ -f "install.sh" ]]; then
    chmod +x install.sh
    ./install.sh
  elif [[ -f "Makefile" ]]; then
    make build
  else
    warn "No standard install script found. Attempting npm install..."
    npm install
  fi

  success "OpenShell installed ✓"
}

# --- Clone NemoClaw ---------------------------------------------------------
clone_nemoclaw() {
  NEMOCLAW_DIR="${INSTALL_DIR}/NemoClaw"

  if [[ -d "${NEMOCLAW_DIR}" ]]; then
    info "NemoClaw directory exists. Pulling latest..."
    cd "${NEMOCLAW_DIR}" && git pull --ff-only
  else
    info "Cloning NVIDIA NemoClaw..."
    git clone https://github.com/NVIDIA/NemoClaw.git "${NEMOCLAW_DIR}"
  fi

  success "NemoClaw source ready at ${NEMOCLAW_DIR} ✓"
}

# --- Run NemoClaw installer -------------------------------------------------
install_nemoclaw() {
  NEMOCLAW_DIR="${INSTALL_DIR}/NemoClaw"
  cd "${NEMOCLAW_DIR}"

  info "Running NemoClaw installer..."
  info "This will:"
  info "  1. Install Node.js dependencies"
  info "  2. Set up the OpenShell gateway"
  info "  3. Configure inference provider"
  info "  4. Create your first sandbox"
  info "  5. Apply baseline security policy"
  info ""

  chmod +x install.sh

  # Pass through NVIDIA API key if available
  if [[ -n "${NVIDIA_API_KEY:-}" ]]; then
    info "Using NVIDIA API key from environment..."
    NVIDIA_API_KEY="${NVIDIA_API_KEY}" ./install.sh
  elif [[ -f "${HOME}/.nvidia-api-key" ]]; then
    info "Using NVIDIA API key from ~/.nvidia-api-key..."
    NVIDIA_API_KEY="$(cat "${HOME}/.nvidia-api-key")" ./install.sh
  else
    info "No NVIDIA API key found. Installer will prompt or use local inference."
    ./install.sh
  fi

  success "NemoClaw installed ✓"
}

# --- Verify installation ----------------------------------------------------
verify() {
  info "Verifying NemoClaw installation..."

  # Check if nemoclaw CLI is available
  if command -v nemoclaw &> /dev/null; then
    success "nemoclaw CLI available ✓"
  else
    # Try adding to PATH
    NEMOCLAW_DIR="${INSTALL_DIR}/NemoClaw"
    if [[ -f "${NEMOCLAW_DIR}/bin/nemoclaw" ]]; then
      export PATH="${NEMOCLAW_DIR}/bin:${PATH}"
      info "Added NemoClaw bin to PATH"
    else
      warn "nemoclaw CLI not found in PATH. You may need to restart your shell."
      warn "Try: export PATH=\"${INSTALL_DIR}/NemoClaw/bin:\$PATH\""
    fi
  fi

  # Check if openshell CLI is available
  if command -v openshell &> /dev/null; then
    success "openshell CLI available ✓"
  else
    warn "openshell CLI not found in PATH. Check OpenShell installation."
  fi
}

# --- Main -------------------------------------------------------------------
main() {
  mkdir -p "${INSTALL_DIR}"

  clone_openshell
  install_openshell
  clone_nemoclaw
  install_nemoclaw
  verify

  success "NemoClaw deployment complete."
}

main "$@"
