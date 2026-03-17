#!/usr/bin/env bash
# ============================================================================
# TNG NemoClaw — Teardown
# Clean uninstall of NemoClaw, OpenShell, and all sandboxes
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="${HOME}/.tng-nemoclaw"

echo ""
echo -e "${RED}${BOLD}TNG NemoClaw — Teardown${NC}"
echo ""
echo "This will:"
echo "  1. Stop all running sandboxes"
echo "  2. Remove NemoClaw and OpenShell installations"
echo "  3. Remove TNG policy templates"
echo "  4. Clean up Docker containers and images"
echo ""
read -p "Are you sure? (y/N): " CONFIRM
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

echo ""

# Stop sandboxes
if command -v nemoclaw &> /dev/null; then
  echo -e "${CYAN}[teardown]${NC} Stopping sandboxes..."
  nemoclaw stop 2>/dev/null || true
fi

if command -v openshell &> /dev/null; then
  echo -e "${CYAN}[teardown]${NC} Cleaning OpenShell sandboxes..."
  openshell sandbox stop --all 2>/dev/null || true
fi

# Run NemoClaw uninstaller if available
NEMOCLAW_DIR="${INSTALL_DIR}/NemoClaw"
if [[ -f "${NEMOCLAW_DIR}/uninstall.sh" ]]; then
  echo -e "${CYAN}[teardown]${NC} Running NemoClaw uninstaller..."
  cd "${NEMOCLAW_DIR}" && bash uninstall.sh 2>/dev/null || true
fi

# Remove install directory
if [[ -d "${INSTALL_DIR}" ]]; then
  echo -e "${CYAN}[teardown]${NC} Removing ${INSTALL_DIR}..."
  rm -rf "${INSTALL_DIR}"
fi

# Clean up Docker artifacts
echo -e "${CYAN}[teardown]${NC} Cleaning Docker artifacts..."
docker ps -a --filter "name=nemoclaw" --filter "name=openshell" -q 2>/dev/null | \
  xargs -r docker rm -f 2>/dev/null || true
docker images --filter "reference=*nemoclaw*" --filter "reference=*openshell*" -q 2>/dev/null | \
  xargs -r docker rmi -f 2>/dev/null || true

echo ""
echo -e "${GREEN}[teardown]${NC} Teardown complete. Everything cleaned up."
echo -e "${CYAN}[teardown]${NC} Docker and Node.js were left in place (they may be used by other tools)."
