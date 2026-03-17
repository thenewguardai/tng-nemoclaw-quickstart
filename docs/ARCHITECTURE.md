# TNG NemoClaw — Architecture Guide

## The Stack

NemoClaw is a layered system. Understanding what runs where saves you hours of debugging.

**On Linux / WSL2:**
```
Linux host (or WSL2 distro)
  └── Docker Engine
       └── OpenShell gateway container (k3s)
            └── Sandbox container (Landlock + seccomp + netns)
                 └── OpenClaw agent
```

**On macOS:**
```
macOS host
  └── Docker Desktop (Linux VM under the hood)
       └── OpenShell gateway container (k3s)
            └── Sandbox container (Landlock + seccomp + netns)
                 └── OpenClaw agent
```

The security primitives (Landlock, seccomp, network namespaces) run inside the Linux containers, not on the host. This is why macOS works — Docker Desktop provides the Linux kernel, and the sandbox doesn't care what's outside the container.

## Components

### nemoclaw CLI
TypeScript CLI that orchestrates everything. Commands run on the **host** (outside the sandbox). This is your control plane.

### OpenShell Gateway
The policy enforcement layer. Sits between the sandbox and the outside world. Every network request, inference call, and file access goes through OpenShell. Policies are YAML files — network policies are hot-reloadable, filesystem and process policies are locked at sandbox creation.

### Sandbox
An isolated container using Linux kernel security primitives — not Docker (though Docker is used for some infrastructure). The sandbox uses Landlock LSM for filesystem isolation, seccomp for syscall filtering, and network namespaces for egress control. The agent inside has no idea it's sandboxed.

### Blueprint
A versioned Python artifact that defines a deployment. It specifies which model to use, which policies to apply, and how to configure the sandbox. The lifecycle: resolve → verify digest → plan resources → apply.

### Inference Router
Routes model API calls to the configured provider. Three profiles ship by default: NVIDIA cloud, local NIM container, and local vLLM. The Privacy Router component strips sensitive data from cloud-bound requests based on regex patterns you define.

## Manual Setup (Step by Step)

If `setup.sh` doesn't work for your environment, here's the manual path:

### 1. Install prerequisites
```bash
bash scripts/install-prereqs.sh
```

### 2. Clone and install OpenShell
```bash
git clone https://github.com/NVIDIA/OpenShell.git ~/.tng-nemoclaw/OpenShell
cd ~/.tng-nemoclaw/OpenShell
make build
```

### 3. Clone and install NemoClaw
```bash
git clone https://github.com/NVIDIA/NemoClaw.git ~/.tng-nemoclaw/NemoClaw
cd ~/.tng-nemoclaw/NemoClaw
./install.sh
```

### 4. Apply TNG policies
```bash
cp -r policies/ ~/.tng-nemoclaw/policies/
openshell policy apply --network ~/.tng-nemoclaw/policies/base/default-lockdown.yaml
```

### 5. Connect
```bash
nemoclaw my-assistant connect
```

### 6. Verify
```bash
bash scripts/health-check.sh
```

## Inference Profiles

| Profile | Command | Model | Data leaves machine? |
|---------|---------|-------|---------------------|
| Cloud (default) | `--profile default` | nemotron-3-super-120b | Yes (with privacy router) |
| Local NIM | `--profile nim-local` | nemotron-3-super-120b | No |
| Local vLLM | `--profile vllm` | nemotron-3-nano-30b | No |

Switch at runtime: `openshell inference set --provider vllm-local --model nvidia/nemotron-3-nano-30b-a3b`

## Security Layers

| Layer | What it does | When it locks |
|-------|-------------|---------------|
| Network egress | Blocks unauthorized outbound connections | Hot-reloadable |
| Filesystem | Prevents access outside /sandbox and /tmp | Sandbox creation |
| Process | Blocks privilege escalation, dangerous syscalls | Sandbox creation |
| Inference | Routes API calls through controlled pipeline | Hot-reloadable |
