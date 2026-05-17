# CLAUDE.md — Dark Flow

Dark Flow is a workflow installer for AI-assisted development projects.

## What's in this repo

```
install.sh              ← main installer (copies templates, sets up labels)
setup-labels.sh         ← standalone GitHub labels setup
templates/
  docs/                 ← generic docs structure templates
  .github/              ← GitHub issue template
README.md               ← user-facing documentation
```

## Working on this repo

When improving the workflow templates, edit files in `templates/docs/` — those are what gets installed into other projects.

When the installer logic changes, test it locally:
```bash
# Test in a temp dir
mkdir /tmp/test-project && cd /tmp/test-project && git init
bash /path/to/darkflow/install.sh --name "Test Project" --no-labels
```

After changes, always verify the install script runs end-to-end without errors.

## Releases

No build process — just commit and push. The install one-liner fetches from `master` branch raw files via GitHub CDN.
