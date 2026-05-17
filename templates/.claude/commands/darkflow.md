Check the Dark Flow workflow status for this project and help the user manage it.

## What to do

1. **Check docs/ structure** — verify all expected folders exist (`docs/product/`, `docs/spec/`, `docs/design/`, `docs/insights/`, `docs/decisions/`). List any that are missing.

2. **Check GitHub labels** — run `gh label list | grep "status:"` to verify the label taxonomy is set up. If missing, offer to run `bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/setup-labels.sh)`.

3. **Show approved task queue** — run:
   ```bash
   gh issue list --label "status:approved" --state open --json number,title,labels,body --limit 20
   ```
   If there are approved issues, summarize them by priority and ask if the user wants to start working on one.

4. **Check for proposed issues** — run:
   ```bash
   gh issue list --label "status:proposed" --state open --json number,title,labels --limit 10
   ```
   Summarize what's waiting for human review.

5. **Report** — give a short health summary:
   - ✓/✗ docs/ structure present
   - ✓/✗ GitHub labels configured
   - N approved tasks ready to work on
   - N proposed tasks waiting for review

## If $ARGUMENTS contains "install" or "setup"

Run the Dark Flow installer:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh)
```

## If $ARGUMENTS contains "labels"

Re-run label setup only:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/setup-labels.sh)
```

## If $ARGUMENTS contains "update"

Force-update all Dark Flow template files (preserves project-specific content):
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh) --force --no-labels
```
