# TNG NemoClaw — Policy Writing Guide

## The Basics

OpenShell policies are YAML files that define what a sandboxed agent can and cannot do. They control three layers: network, filesystem, and inference routing.

## Starting Point

Always start with `policies/base/default-lockdown.yaml`. It blocks everything except inference. Open only what your use case requires.

```bash
# Apply the lockdown baseline
openshell policy apply --network policies/base/default-lockdown.yaml

# Then layer on your customizations
openshell policy apply --network policies/my-custom-policy.yaml
```

## Network Policies

Network policies control outbound connections. They're **hot-reloadable** — change them without restarting the sandbox.

```yaml
network:
  egress:
    allow:
      - host: "api.example.com"     # Exact hostname
        ports: [443]                  # Which ports
        protocol: "https"             # Protocol
        description: "Why this is allowed"

      - host: "*.internal.co"        # Wildcard subdomain
        ports: [443, 8443]
        protocol: "https"

    deny:
      - host: "*"                     # Catch-all deny
```

**Best practice:** Write your deny rule first, then add specific allows. Never use a broad allow in production.

## Filesystem Policies

Filesystem policies define readable/writable paths. They're **locked at sandbox creation** — you can't change them at runtime.

```yaml
filesystem:
  writable:
    - "/sandbox/workspace"
    - "/sandbox/output"
    - "/tmp"

  blocked:
    - "/etc"
    - "/var"
    - "/home"

  containment_zones:
    - path: "/sandbox/sensitive"
      allow_export: false    # Files here can NEVER leave the sandbox
```

## Inference Routing

Controls which models the agent uses and how data flows to them.

```yaml
inference:
  provider: "nvidia-cloud"           # or "nim-local" or "vllm-local"
  model: "nvidia/nemotron-3-super-120b-a12b"

  privacy_router:
    enabled: true
    allow_cloud: true                 # Set false to block all cloud inference
    redact_patterns:
      - "\\b\\d{3}-\\d{2}-\\d{4}\\b"  # SSN pattern
    log_routing: true
    log_redactions: true
```

## Workflow: Building a Custom Policy

1. Deploy with `dev/permissive-dev.yaml` (broad access + full logging)
2. Run your agent through realistic tasks
3. Review the logs — see what hosts it reaches, what files it touches
4. Build your production policy based on actual observed behavior
5. Test the restrictive policy — make sure the agent still works
6. Deploy to production

This is the correct order. Don't guess what the agent needs — observe it, then lock it down.

## Testing a Policy

```bash
# Apply your policy
openshell policy apply --network my-policy.yaml

# Connect to the sandbox
nemoclaw my-assistant connect

# Try to hit a blocked endpoint (should fail)
curl https://should-be-blocked.com

# Try to hit an allowed endpoint (should work)
curl https://your-allowed-api.com

# Check the logs from the host
nemoclaw my-assistant logs -f
```
