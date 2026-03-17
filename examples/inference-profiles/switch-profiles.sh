#!/usr/bin/env bash
# ============================================================================
# TNG NemoClaw — Inference Profile Examples
# Shows how to switch between cloud, local NIM, and local vLLM inference
#
# All three profiles are hot-swappable at runtime — no sandbox restart needed.
# ============================================================================

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}NemoClaw Inference Profiles${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Profile 1: NVIDIA Cloud (default) ------------------------------------
echo ""
echo -e "${CYAN}Profile 1: NVIDIA Cloud${NC}"
echo "  Best quality model, requires API key, data goes to NVIDIA's API"
echo "  Use for: general-purpose tasks, non-sensitive data"
echo ""
echo "  # Launch with cloud profile"
echo "  openclaw nemoclaw launch --profile default"
echo ""
echo "  # Or switch at runtime"
echo "  openshell inference set --provider nvidia-cloud --model nvidia/nemotron-3-super-120b-a12b"

# --- Profile 2: Local NIM -------------------------------------------------
echo ""
echo -e "${CYAN}Profile 2: Local NIM (On-Premises)${NC}"
echo "  Same model, runs in a local NIM container. Data never leaves."
echo "  Use for: sensitive data, HIPAA/SOC2 workloads, air-gapped networks"
echo "  Requires: NVIDIA GPU with sufficient VRAM"
echo ""
echo "  # Launch with NIM profile"
echo "  openclaw nemoclaw launch --profile nim-local"
echo ""
echo "  # Or switch at runtime"
echo "  openshell inference set --provider nim-local --model nvidia/nemotron-3-super-120b-a12b"

# --- Profile 3: Local vLLM ------------------------------------------------
echo ""
echo -e "${CYAN}Profile 3: Local vLLM (Development)${NC}"
echo "  Smaller model, runs via vLLM on your hardware. Fully offline."
echo "  Use for: development, testing, low-resource environments"
echo "  Requires: NVIDIA GPU (smaller VRAM OK) or CPU (slow but works)"
echo ""
echo "  # Launch with vLLM profile"
echo "  openclaw nemoclaw launch --profile vllm"
echo ""
echo "  # Or switch at runtime"
echo "  openshell inference set --provider vllm-local --model nvidia/nemotron-3-nano-30b-a3b"

# --- Quick test ------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Quick Test:${NC}"
echo ""
echo "  # Check current profile"
echo "  nemoclaw my-assistant status"
echo ""
echo "  # Switch and verify"
echo "  openshell inference set --provider vllm-local --model nvidia/nemotron-3-nano-30b-a3b"
echo "  nemoclaw my-assistant connect"
echo "  openclaw agent --agent main --local -m 'What model are you running?' --session-id test"
echo ""
