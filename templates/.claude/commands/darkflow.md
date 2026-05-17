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

Run the Dark Flow updater — compares installed version against latest, shows changelog, and smart-updates template files (preserves local modifications unless --force is passed):
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/update.sh)
```

Options:
- `--dry-run` — show what would change without applying anything
- `--force` — overwrite template files even if locally modified

## If $ARGUMENTS contains "new"

Help the user create a GitHub issue for a manually identified task (bug, feature, or improvement).

Walk through these questions one by one — ask them conversationally, not as a form:

1. **What is it?** — bug, feature, or improvement?
   - bug → label `bug`
   - feature → label `enhancement`
   - improvement → label `enhancement`

2. **One-line title** — ask for a short action-oriented title ("Fix X", "Add Y", "Improve Z")

3. **What area of the codebase?** — show available areas and ask to pick one or more:
   `worker` · `api` · `landing` · `checkout` · `auth` · `dashboard` · `email` · `checks` · `docs` · `infra`

4. **Priority?** — ask, give brief context:
   - p0 — breaks revenue or a key feature right now
   - p1 — needs to happen this week
   - p2 — this month
   - p3 — someday / nice-to-have

5. **Effort?** — ask for a rough estimate:
   - xs — ≤ 30 min
   - s — ~2 hours
   - m — half a day
   - l — more than a day (will need to be split into sub-issues)

6. **Description** — ask: "Briefly describe the problem and what done looks like." Use the answer to write:
   - a short context paragraph
   - 1–3 acceptance criteria checkboxes

Then construct and run the `gh issue create` command:

```bash
gh issue create \
  --title "<title>" \
  --label "status:approved,source:manual,area:<area>,priority:<p>,effort:<e>,<type>" \
  --body "$(cat <<'EOF'
## Context

<description>

## Acceptance criteria

- [ ] <criterion 1>
- [ ] <criterion 2 if needed>
EOF
)"
```

**Important rules:**
- Always use `status:approved` for manually created issues — the user already decided to do it
- If effort is `l`, warn: "This looks like more than a day of work — it's better to split into 2–4 smaller issues. Want me to help break it down first?"
- After creating the issue, just show the URL and the issue number. The fix-issues routine will pick it up automatically.
