# Example: Writing a Safe Custom Skill

This directory contains `csv_summarizer.py` — a minimal example showing how to write OpenClaw skills that work correctly inside a NemoClaw sandbox.

## Key Patterns

1. **Use `/sandbox/` paths** — all file I/O goes through `/sandbox/input/`, `/sandbox/output/`, `/sandbox/workspace/`
2. **Don't assume network access** — your policy controls what's reachable. Code defensively.
3. **No host filesystem access** — `/etc`, `/home`, `/var` are blocked by OpenShell
4. **No credential access** — can't read `~/.env`, `~/.ssh`, or other credential stores

## Testing in the Sandbox

```bash
# Connect to your sandbox
nemoclaw my-assistant connect

# Copy the skill into the sandbox
cp /path/to/csv_summarizer.py /sandbox/workspace/

# Add a test CSV
echo "name,age,city\nAlice,30,NYC\nBob,25,LA" > /sandbox/input/test.csv

# Run it
python /sandbox/workspace/csv_summarizer.py

# Check output
cat /sandbox/output/csv-summary-*.txt
```
