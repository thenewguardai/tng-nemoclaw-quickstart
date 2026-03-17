# TNG NemoClaw — Troubleshooting

## Quick Diagnostics

```bash
# Check everything at once
bash scripts/health-check.sh

# NemoClaw-level health
nemoclaw my-assistant status

# OpenShell-level sandbox state
openshell sandbox list

# Stream logs in real-time
nemoclaw my-assistant logs --follow
```

## Common Issues

### "nemoclaw: command not found"

NemoClaw's binary isn't in your PATH. Fix:
```bash
export PATH="$HOME/.tng-nemoclaw/NemoClaw/bin:$PATH"
# Add to your .bashrc or .zshrc to persist
```

### "openshell: command not found"

Same issue, different binary:
```bash
export PATH="$HOME/.tng-nemoclaw/OpenShell/bin:$PATH"
```

### Install script fails with Docker permission errors

You need to be in the `docker` group:
```bash
sudo usermod -aG docker $USER
# Log out and back in, or:
newgrp docker
```

### "NemoClaw requires a fresh installation of OpenClaw"

If you have an existing OpenClaw install, NemoClaw can't layer on top. Options:
1. Uninstall OpenClaw first, then run `setup.sh`
2. Run NemoClaw on a separate machine or VM
3. Use a Docker container as your base environment

### Sandbox won't start — "Landlock not supported"

Landlock LSM requires Linux kernel 5.13+. Check:
```bash
uname -r
# If below 5.13, you need a kernel upgrade
```

Ubuntu 22.04 ships with 5.15+, so this shouldn't happen on supported distros.

### Agent can't reach inference API

Check your NVIDIA API key:
```bash
# Is it set?
echo $NVIDIA_API_KEY

# Test it directly
curl -s -H "Authorization: Bearer $NVIDIA_API_KEY" \
  https://integrate.api.nvidia.com/v1/models | jq .
```

If using local inference, make sure the NIM container or vLLM process is running:
```bash
docker ps | grep nim
# or
ps aux | grep vllm
```

### Policy changes aren't taking effect

Network policies are hot-reloadable. Filesystem and process policies are NOT — they're locked at sandbox creation. If you need to change filesystem boundaries, you need to destroy and recreate the sandbox.

```bash
# Reapply network policy (no restart needed)
openshell policy apply --network policies/my-policy.yaml

# For filesystem changes — recreate the sandbox
nemoclaw my-assistant stop
# Re-run setup with new filesystem policy
```

### Monitoring stack (Grafana) not showing data

1. Check Promtail is finding the log files:
   ```bash
   docker logs tng-promtail
   ```
2. Verify Loki is receiving data:
   ```bash
   curl http://localhost:3100/ready
   ```
3. Make sure log paths in `promtail-config.yaml` match your actual NemoClaw log locations

### "openclaw nemoclaw" plugin commands fail

The plugin commands are under active development. Use the `nemoclaw` host CLI instead — it's the stable interface. Check the NemoClaw GitHub issues for known plugin bugs.

## Getting Help

- **NemoClaw issues:** https://github.com/NVIDIA/NemoClaw/issues
- **OpenShell issues:** https://github.com/NVIDIA/OpenShell/issues
- **TNG community:** https://thenewguard.ai
