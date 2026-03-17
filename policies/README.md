# TNG NemoClaw — Security Policy Templates

## How Policies Work

NemoClaw uses NVIDIA OpenShell to enforce security boundaries around AI agents. Policies are declarative YAML files that control:

- **Network egress** — Which hosts the agent can reach (hot-reloadable at runtime)
- **Filesystem access** — What the agent can read/write (locked at sandbox creation)
- **Process restrictions** — Privilege escalation, syscall filtering (locked at creation)
- **Inference routing** — Which models the agent uses and how data flows (hot-reloadable)

## Applying a Policy

```bash
# Apply a network policy (can be changed at runtime)
openshell policy apply --network policies/healthcare/hipaa-agent.yaml

# Switch between policies without restarting the sandbox
openshell policy apply --network policies/dev/permissive-dev.yaml
```

## Available Templates

### `base/default-lockdown.yaml`
**Maximum restriction.** Blocks all outbound network except NVIDIA inference endpoints. Use as your starting point and open only what you need.

### `healthcare/hipaa-agent.yaml`
**HIPAA Technical Safeguards.** Local inference only (PHI never leaves your infrastructure), allowlisted EHR endpoints, aggressive PII/PHI redaction, full audit logging with file hashes. Customize the allowed endpoints for your EHR vendor.

### `financial/soc2-agent.yaml`
**SOC 2 audit trail.** Financial data provider APIs only, tamper-evident file logging, supports cloud inference with privacy router redaction. Designed to generate SOC 2 compliance evidence.

### `legal/legal-privilege.yaml`
**Attorney-client privilege.** Zero external network access, local inference only, document containment zones that prevent privileged material from leaving the sandbox. Built for law firms and in-house legal.

### `dev/permissive-dev.yaml`
**Development and testing.** Broad HTTPS access with full logging. Use this to understand what your agent tries to reach, then build a restrictive policy from the logs. **Never use in production.**

## Writing Your Own

Start with `base/default-lockdown.yaml` and modify:

1. Add your specific API endpoints to `network.egress.allow`
2. Adjust `filesystem.writable` paths for your use case
3. Configure `inference.provider` and `inference.privacy_router`
4. Set `logging` levels appropriate for your compliance requirements

See [docs/POLICIES.md](../docs/POLICIES.md) for the full policy writing guide.

## The Opportunity

Every regulated industry needs custom agent policies. If you can write these YAML files for a specific vertical (insurance, government, education, defense), you have a consulting business. See [docs/OPPORTUNITIES.md](../docs/OPPORTUNITIES.md) for more.
