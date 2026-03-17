#!/usr/bin/env bash
# ============================================================================
# TNG NemoClaw — Health Check
# Verifies the entire stack is running correctly
# ============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check_pass() { echo -e "  ${GREEN}✓${NC} $1"; ((PASS++)); }
check_fail() { echo -e "  ${RED}✗${NC} $1"; ((FAIL++)); }
check_warn() { echo -e "  ${YELLOW}!${NC} $1"; ((WARN++)); }

echo ""
echo -e "${CYAN}${BOLD}TNG NemoClaw Health Check${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- System checks ----------------------------------------------------------
echo ""
echo -e "${BOLD}System:${NC}"

if command -v docker &> /dev/null && docker ps &> /dev/null; then
  check_pass "Docker running"
else
  check_fail "Docker not running"
fi

if command -v node &> /dev/null; then
  check_pass "Node.js $(node --version)"
else
  check_fail "Node.js not found"
fi

if command -v git &> /dev/null; then
  check_pass "Git installed"
else
  check_fail "Git not found"
fi

# --- NemoClaw checks --------------------------------------------------------
echo ""
echo -e "${BOLD}NemoClaw:${NC}"

if command -v nemoclaw &> /dev/null; then
  check_pass "nemoclaw CLI in PATH"
else
  # Check common install locations
  if [[ -f "${HOME}/.tng-nemoclaw/NemoClaw/bin/nemoclaw" ]]; then
    check_warn "nemoclaw CLI found but not in PATH"
  else
    check_fail "nemoclaw CLI not found"
  fi
fi

INSTALL_DIR="${HOME}/.tng-nemoclaw"
if [[ -d "${INSTALL_DIR}/NemoClaw" ]]; then
  check_pass "NemoClaw repo cloned"
else
  check_fail "NemoClaw repo not found at ${INSTALL_DIR}/NemoClaw"
fi

# --- OpenShell checks -------------------------------------------------------
echo ""
echo -e "${BOLD}OpenShell:${NC}"

if command -v openshell &> /dev/null; then
  check_pass "openshell CLI in PATH"
else
  check_warn "openshell CLI not found in PATH"
fi

if [[ -d "${INSTALL_DIR}/OpenShell" ]]; then
  check_pass "OpenShell repo cloned"
else
  check_fail "OpenShell repo not found at ${INSTALL_DIR}/OpenShell"
fi

# --- Sandbox checks ---------------------------------------------------------
echo ""
echo -e "${BOLD}Sandbox:${NC}"

if command -v nemoclaw &> /dev/null; then
  if nemoclaw my-assistant status &> /dev/null 2>&1; then
    check_pass "Sandbox 'my-assistant' running"
  else
    check_warn "Sandbox 'my-assistant' not running (run: nemoclaw setup)"
  fi
fi

if command -v openshell &> /dev/null; then
  SANDBOX_COUNT=$(openshell sandbox list 2>/dev/null | grep -c "running" || echo "0")
  if [[ "${SANDBOX_COUNT}" -gt 0 ]]; then
    check_pass "${SANDBOX_COUNT} sandbox(es) running"
  else
    check_warn "No running sandboxes detected"
  fi
fi

# --- Policy checks ----------------------------------------------------------
echo ""
echo -e "${BOLD}Policies:${NC}"

POLICY_DIR="${INSTALL_DIR}/policies"
if [[ -d "${POLICY_DIR}" ]]; then
  POLICY_COUNT=$(find "${POLICY_DIR}" -name "*.yaml" | wc -l)
  check_pass "${POLICY_COUNT} TNG policy templates available"
else
  check_warn "TNG policies not deployed (run setup.sh)"
fi

# --- Inference checks -------------------------------------------------------
echo ""
echo -e "${BOLD}Inference:${NC}"

if [[ -n "${NVIDIA_API_KEY:-}" ]]; then
  check_pass "NVIDIA API key set in environment"
elif [[ -f "${HOME}/.nvidia-api-key" ]]; then
  check_pass "NVIDIA API key found at ~/.nvidia-api-key"
else
  check_warn "No NVIDIA API key — cloud inference won't work"
fi

# Check for NVIDIA GPU (optional)
if command -v nvidia-smi &> /dev/null; then
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
  check_pass "NVIDIA GPU detected: ${GPU_NAME}"
else
  check_warn "No NVIDIA GPU — local Nemotron inference unavailable"
fi

# --- Summary ----------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}${PASS} passed${NC}  ${YELLOW}${WARN} warnings${NC}  ${RED}${FAIL} failed${NC}"

if [[ ${FAIL} -gt 0 ]]; then
  echo ""
  echo -e "  ${RED}Some checks failed. Review the output above.${NC}"
  echo -e "  See docs/TROUBLESHOOTING.md for common fixes."
  exit 1
elif [[ ${WARN} -gt 0 ]]; then
  echo ""
  echo -e "  ${YELLOW}Warnings present but not blocking. You're good to go.${NC}"
  exit 0
else
  echo ""
  echo -e "  ${GREEN}All checks passed. Your NemoClaw stack is healthy.${NC}"
  exit 0
fi
