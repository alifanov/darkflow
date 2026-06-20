# Fix CI Issue

Picks up one open `source:ci` issue (filed by the CI gate when lint/test fails), reproduces the failure, pushes a fix, and leaves an attempt marker. The **same issue is retried up to 3 times**; only after the third failed attempt is it handed to a human (`needs-human`). This bounds the red-CI → issue → fix → red-CI loop.

This routine is the CI-specific counterpart to `fix-issues`. `source:ci` issues are **excluded** from the general `fix-issues` queue so the retry cap is never bypassed.

---

## Instructions

```
/darkflow:fix-ci-issue
```

Reads `.darkflow` for `branch`, `merge_strategy`, and `language` — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `*/15 * * * *` (every 15 min) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (lint/test fixes are mechanical) |
| Permission mode | `bypassPermissions` (set in `.darkflow.d/routines.yml`) |
| Run manually | `~/.darkflow/darkflow-run.sh fix-ci-issue` |
| Module | `ci-gate` — only installed when the CI gate is enabled |

---

## Required integrations

- **`gh` CLI** authenticated — to read/comment/close issues and push fixes
- **`ci-gate` module** — the `.github/workflows/darkflow-ci-gate.yml` workflow files the `source:ci` issues this routine consumes

---

## How the retry cap works

1. The CI gate keeps **one open issue per branch** (deduped by the stable title `CI failure on <branch>`).
2. Each `fix-ci-issue` run counts prior attempt markers (`<!-- darkflow:ci-attempt -->` comments) on the issue:
   - `< 3` → attempt the fix, push, add the `ci-retry` label, post an attempt marker. **Does not close the issue.**
   - `>= 3` → escalate: add `needs-human`, remove `status:approved`, comment, stop.
3. When CI passes again, the gate's **close-on-green** step closes the issue automatically. A fixed issue therefore never reaches the human-escalation path.

---

## Labels

- Consumes: `source:ci` + `status:approved`
- Adds while retrying: `ci-retry`
- On the 3rd failed attempt: `needs-human` (and removes `status:approved`)

---

## Notes

- Verification runs `lint` + `test` only — **not** `build`; the CI gate verifies the build on push.
- Uses `Refs #N` (not `Closes #N`) in PRs so the issue stays open until CI is actually green.
- `MAX_ATTEMPTS` is 3 (defined in the command). Lower it to be stricter, raise it to be more forgiving.
