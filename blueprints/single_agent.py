"""
TNG NemoClaw — Single Agent Blueprint
Deploys one sandboxed OpenClaw agent with configurable policy and inference.

Usage:
    python blueprints/single_agent.py --name my-agent --policy policies/base/default-lockdown.yaml
    python blueprints/single_agent.py --name research-bot --policy policies/dev/permissive-dev.yaml --profile vllm
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def check_prerequisites():
    """Verify NemoClaw and OpenShell are installed."""
    checks = {
        "nemoclaw": "NemoClaw CLI",
        "openshell": "OpenShell CLI",
        "docker": "Docker",
    }

    missing = []
    for cmd, name in checks.items():
        result = subprocess.run(["which", cmd], capture_output=True)
        if result.returncode != 0:
            missing.append(name)

    if missing:
        print(f"[ERROR] Missing prerequisites: {', '.join(missing)}")
        print("Run setup.sh first, or see docs/ARCHITECTURE.md for manual install.")
        sys.exit(1)

    print("[OK] All prerequisites found.")


def deploy_agent(name: str, policy_path: str, profile: str):
    """Deploy a single sandboxed agent."""

    print(f"\n{'='*60}")
    print(f"  Deploying agent: {name}")
    print(f"  Policy: {policy_path}")
    print(f"  Inference profile: {profile}")
    print(f"{'='*60}\n")

    # Step 1: Launch the sandbox with NemoClaw
    print("[1/3] Creating sandbox...")
    launch_cmd = ["nemoclaw", "setup"]
    if profile:
        launch_cmd.extend(["--profile", profile])

    result = subprocess.run(launch_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"[ERROR] Sandbox creation failed:\n{result.stderr}")
        sys.exit(1)
    print("[OK] Sandbox created.")

    # Step 2: Apply the security policy
    if policy_path and Path(policy_path).exists():
        print(f"[2/3] Applying policy: {policy_path}")
        policy_cmd = ["openshell", "policy", "apply", "--network", policy_path]
        result = subprocess.run(policy_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"[WARN] Policy apply returned: {result.stderr}")
        else:
            print("[OK] Policy applied.")
    else:
        print(f"[2/3] No custom policy — using NemoClaw defaults.")

    # Step 3: Verify
    print("[3/3] Running health check...")
    status_cmd = ["nemoclaw", name, "status"]
    result = subprocess.run(status_cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"[OK] Agent '{name}' is running.")
        print(f"\n  Connect:  nemoclaw {name} connect")
        print(f"  Status:   nemoclaw {name} status")
        print(f"  Logs:     nemoclaw {name} logs --follow")
        print(f"  Monitor:  nemoclaw term")
    else:
        print(f"[WARN] Could not verify agent status. Check manually:")
        print(f"  nemoclaw {name} status")
        print(f"  openshell sandbox list")

    print(f"\n{'='*60}")
    print(f"  Deployment complete.")
    print(f"{'='*60}\n")


def main():
    parser = argparse.ArgumentParser(
        description="TNG NemoClaw — Deploy a single sandboxed agent"
    )
    parser.add_argument(
        "--name",
        default="my-assistant",
        help="Name for the sandbox (default: my-assistant)",
    )
    parser.add_argument(
        "--policy",
        default="policies/base/default-lockdown.yaml",
        help="Path to OpenShell policy YAML",
    )
    parser.add_argument(
        "--profile",
        default="default",
        choices=["default", "nim-local", "vllm"],
        help="Inference profile (default: nvidia cloud)",
    )

    args = parser.parse_args()

    check_prerequisites()
    deploy_agent(args.name, args.policy, args.profile)


if __name__ == "__main__":
    main()
