Update Dark Flow to the latest version.

## Step 1 — Run the installer

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh) --force --yes
```

The installer is fully non-interactive: `--yes` skips all prompts, `--force` overwrites locally-modified templates. It will update `.darkflow.d/darkflow-run.sh`, slash commands, and the version in `.darkflow`.

## Step 2 — Verify

After the installer exits, confirm the update succeeded:

```bash
grep '^version=' .darkflow
```

Compare the installed version against the latest release:

```bash
curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/VERSION
```

## Step 3 — Report

Print a single summary line:
- On success: `Dark Flow updated to vX.Y.Z`
- If already up to date: `Dark Flow already up to date (vX.Y.Z)`
- On failure: print the error output and exit non-zero
