Check the Dark Flow workflow status for this project and help the user manage it.

## What to do

1. **Check docs/ structure** — verify all expected folders exist (`docs/product/`, `docs/spec/`, `docs/design/`, `docs/insights/`, `docs/decisions/`). List any that are missing.

2. **Check GitHub labels** — run `gh label list | grep "status:"` to verify the label taxonomy is set up. If missing, offer to run `bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/setup-labels.sh)`.

3. **Show approved task queue** — run:
   ```bash
   gh issue list --label "status:approved" --state open --json number,title,labels,body --limit 20
   ```
   Summarize them by priority. Do not offer to start working — the fix-issues routine handles that.

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

**Before asking anything**, read `docs/github-issues.md` to get the list of `area:*` labels defined for this project. Use those — not a hardcoded list.

If `$ARGUMENTS` contains text beyond "new" (e.g. `/darkflow new fix login button on mobile`), use that text as the **title** — do not ask for a title again. Infer the type from the title if obvious ("fix"/"bug" → `bug`, "add"/"implement" → `enhancement`).

Walk through **only the missing fields** conversationally — skip any field already clear from the title:

1. **What is it?** (if not already clear) — bug, feature, or improvement?
   - bug → label `bug`
   - feature / improvement → label `enhancement`

2. **Title** (if not provided in $ARGUMENTS) — short action-oriented ("Fix X", "Add Y")

3. **Area** — pick one or more from the project's `area:*` labels (read from `docs/github-issues.md`)

4. **Priority:**
   - p0 — breaks revenue or a key feature right now
   - p1 — this week
   - p2 — this month
   - p3 — someday / nice-to-have

5. **Effort:**
   - xs — ≤ 30 min · s — ~2 hours · m — half a day · l — more than a day

6. **Description** — "Briefly describe the problem and what done looks like." Use the answer to write a context paragraph and 1–3 acceptance criteria checkboxes.

Then construct and run:

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
- Always use `status:approved` — the user already decided to do it
- If effort is `l`: warn "This looks like more than a day — better to split into 2–4 sub-issues. Want me to help break it down first?"
- After creating, show the URL and issue number. The fix-issues routine will pick it up automatically.
