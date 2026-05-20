Pick up one status:approved GitHub issue, implement the fix, and close it.

## Step 1 — Read project config

Read `.darkflow` in the project root. Extract:
- `branch=` → main branch name (default: main)
- `merge_strategy=` → `pr` or `direct` (default: pr)
- `language=` → output/issue language (default: English)

If `.darkflow` is missing, continue with the defaults.

## Step 2 — Do the work

Look at the open GitHub issues for this project. Take only **one** issue with `status:approved`, sorted by priority (p0 first, then p1, p2, p3).

If there are no `status:approved` issues, stop — skip the run.

Implement all the changes needed for it.

**Before merging or pushing — run quality checks:**

Detect the project's tech stack and run all available checks. Stop at the first failure.

| Stack | Commands to run (in order) |
|---|---|
| Node / pnpm | `pnpm lint` (if script exists) → `pnpm test` (if script exists) → `pnpm build` (if script exists) |
| Node / npm | `npm run lint` → `npm test` → `npm run build` (skip any that aren't defined) |
| Python | `ruff check .` (if ruff installed) → `pytest` (if pytest installed) |
| Rust | `cargo clippy` → `cargo test` → `cargo build` |
| Go | `go vet ./...` → `go test ./...` → `go build ./...` |
| Other | Check for `Makefile` targets `lint`, `test`, `build` and run those that exist |

**If any check fails:**
- Do NOT merge or push
- Leave a comment on the issue: what failed and the relevant error output (truncated to ~20 lines)
- Label the issue `status:blocked`
- Stop the run

**If all checks pass (or no checks apply), proceed:**

**If `merge_strategy=pr`:**
Open a pull request targeting the `branch=` value from `.darkflow` with `Closes #N` in the description. Merge the pull request into that branch. Leave a comment on the issue confirming completion. Close the issue.

**If `merge_strategy=direct`:**
Commit and push directly to the `branch=` value from `.darkflow`. Leave a comment on the issue confirming completion. Close the issue.

Language for GitHub comments and output: the `language=` value from `.darkflow`.

## Step 3 — After completing

Only if the run actually did work (not a "no approved issues" skip), append a routine-log entry to `docs/overview.html`:

1. Read `docs/overview.html`
2. In the JSON inside `<script id="overview-data">`, append to the `logs` array:
   ```json
   { "timestamp": "<current UTC ISO 8601>", "routine": "fix-issues", "summary": "<one-line summary, e.g. 'Closed #42: fixed N+1 in /api/orders, PR #44 merged'>" }
   ```
3. Cap the array at the 50 most recent entries (drop older ones if it exceeds 50)
4. Write `docs/overview.html` — change nothing else in the JSON
