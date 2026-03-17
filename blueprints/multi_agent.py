"""
TNG NemoClaw — Multi-Agent Blueprint
Deploys multiple sandboxed agents, each with their own policy and role.

Usage:
    python blueprints/multi_agent.py --config blueprints/fleet.yaml

Example fleet.yaml:
    agents:
      - name: researcher
        policy: policies/dev/permissive-dev.yaml
        profile: default
      - name: code-reviewer
        policy: policies/base/default-lockdown.yaml
        profile: vllm
      - name: data-analyst
        policy: policies/base/default-lockdown.yaml
        profile: nim-local
"""

import argparse
import subprocess
import sys
import time

try:
    import yaml
except ImportError:
    print("[ERROR] PyYAML required. Install: pip install pyyaml")
    sys.exit(1)

from pathlib import Path


def deploy_single(name: str, policy: str, profile: str) -> bool:
    """Deploy one agent. Returns True on success."""
    print(f"\n--- Deploying: {name} (policy={policy}, profile={profile}) ---")

    launch_cmd = ["nemoclaw", "setup", "--profile", profile]
    result = subprocess.run(launch_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"[ERROR] Failed to create sandbox for {name}: {result.stderr}")
        return False

    if policy and Path(policy).exists():
        policy_cmd = ["openshell", "policy", "apply", "--network", policy]
        subprocess.run(policy_cmd, capture_output=True, text=True)

    print(f"[OK] {name} deployed.")
    return True


def deploy_fleet(config_path: str):
    """Deploy all agents defined in a fleet config."""
    with open(config_path) as f:
        config = yaml.safe_load(f)

    agents = config.get("agents", [])
    if not agents:
        print("[ERROR] No agents defined in config.")
        sys.exit(1)

    print(f"\nDeploying fleet of {len(agents)} agents...")
    print("=" * 60)

    results = {}
    for agent in agents:
        name = agent.get("name", "unnamed")
        policy = agent.get("policy", "policies/base/default-lockdown.yaml")
        profile = agent.get("profile", "default")

        success = deploy_single(name, policy, profile)
        results[name] = "OK" if success else "FAILED"
        time.sleep(2)  # Brief pause between deployments

    # Summary
    print(f"\n{'='*60}")
    print("Fleet Deployment Summary:")
    print(f"{'='*60}")
    for name, status in results.items():
        icon = "✓" if status == "OK" else "✗"
        print(f"  {icon} {name}: {status}")

    failed = sum(1 for s in results.values() if s == "FAILED")
    if failed:
        print(f"\n[WARN] {failed}/{len(agents)} agents failed to deploy.")
    else:
        print(f"\n[OK] All {len(agents)} agents deployed successfully.")


def main():
    parser = argparse.ArgumentParser(
        description="TNG NemoClaw — Deploy a fleet of sandboxed agents"
    )
    parser.add_argument(
        "--config",
        default="blueprints/fleet.yaml",
        help="Path to fleet configuration YAML",
    )
    args = parser.parse_args()

    if not Path(args.config).exists():
        print(f"[ERROR] Config not found: {args.config}")
        print("Create a fleet.yaml — see the docstring in this file for format.")
        sys.exit(1)

    deploy_fleet(args.config)


if __name__ == "__main__":
    main()
