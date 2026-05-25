Run the Dark Flow installer — it automatically detects whether to update or do a fresh install:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh)
```

Options:
- `--dry-run` — show what would change without applying anything
- `--force` — re-apply all templates even if already up to date

After the installer finishes, check for stale slash commands that are no longer part of Dark Flow:

1. List all files currently in `.claude/commands/darkflow/` (relative to the project root).
2. Compare them against the canonical Dark Flow command set:
   - `add-issue.md`
   - `analytics-review.md`
   - `architecture-review.md`
   - `claude-md-update.md`
   - `coolify-logs.md`
   - `deployment-failure.md`
   - `fix-issues.md`
   - `gsc-check.md`
   - `install.md`
   - `mailbox-check.md`
   - `observability-check.md`
   - `security-audit.md`
   - `update.md`
   - `vulnerability-check.md`
3. If there are any files **not** in the list above, show them to the user and ask whether to delete them (they are likely leftovers from an older Dark Flow version).
4. Delete only the files the user confirms.
