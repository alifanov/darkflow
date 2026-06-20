# Mailbox Check

Hourly check of the project's IMAP inbox — turns new incoming emails into `status:proposed` GitHub issues, and sends approved email replies via SMTP. A two-way bridge between email and the Dark Flow issue loop.

This is an **optional** routine, gated behind the `mailbox` module. Each incoming email becomes an issue with a choice of action (`action:reply` → the routine writes and sends a reply; `action:fix` → `fix-issues` treats it as a code/product task).

**Cost optimization — cheap pre-flight.** The dispatcher runs two cheap checks before spending a Sonnet agent run: a read-only IMAP `UNSEEN` count (`fetch.py --count`) and a `gh issue list` for approved `action:reply` issues. If there is **no new mail and no reply pending**, it **skips the agent** entirely (logged `SKIP mailbox-check — no new mail, no replies pending`). The agent is launched **only** when there's mail to triage, a reply to send, or the probe can't decide (IMAP error / missing python3) — logged `ESCALATE mailbox-check — …`. On a quiet inbox this turns 24 agent runs/day into near-zero LLM cost while keeping the hourly cadence.

**Misconfiguration alert.** If the routine is **enabled but not configured** (`MAILBOX_IMAP_HOST` empty in `.env`), the dispatcher logs it as an `ERROR` and files a single, deduped `needs-human` + `source:mailbox` + `priority:high` GitHub issue telling the human to add the `MAILBOX_*` credentials (or disable the routine). It does **not** open a second issue while the first is still open, and it does not launch the agent. This makes a forgotten setup visible instead of a silent every-hour no-op.

---

## Instructions

```
/darkflow:mailbox-check
```

The command reads `.darkflow` for the output language, branch, and merge strategy, and loads mailbox credentials from `.env` (with `.env.darkflow` as a legacy fallback) — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 * * * *` (hourly) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Module | `mailbox` |
| Permission mode | `bypassPermissions` (default; override per project in the Web UI) |
| Run manually | `~/.darkflow/darkflow-run.sh mailbox-check` |

Enable with `--with-mailbox` during install, or set `modules=...,mailbox,...` in `.darkflow`.

Disable without removing: toggle it off in the Web UI (Settings → Routine schedule).

---

## Required integrations

- **`gh` CLI** authenticated — for creating issues, commenting, closing
- **Mailbox credentials** in `.env` (git-ignored):
  - `MAILBOX_IMAP_HOST` / `_PORT` / `_USER` / `_PASSWORD` — incoming
  - `MAILBOX_SMTP_HOST` / `_PORT` / `_USER` / `_PASSWORD` — outgoing replies
- **Python 3** — the routine drives `.darkflow.d/mailbox/fetch.py` (IMAP) and `send.py` (SMTP)

If `MAILBOX_IMAP_HOST` is empty after sourcing `.env`, the dispatcher logs an `ERROR` and files a deduped `needs-human` issue asking the human to configure (or disable) the routine — see **Misconfiguration alert** above.

---

## What gets created

Issues with labels: `status:proposed`, `source:mailbox`, `priority:high` / `medium` (urgency keywords bump to `high`).

Each issue carries the original email metadata (From, Date, Subject, Message-ID) so replies thread correctly. A human picks `action:reply` or `action:fix` and sets `status:approved` to trigger the action.

---

## How it fits the loop

```
Incoming email → mailbox-check → status:proposed issue (action choice)
  ↓ human adds action:reply or action:fix + status:approved
[action:reply]  mailbox-check (next run) → SMTP reply → closes issue
[action:fix]    fix-issues → implements → PR → merge → closes issue
```

---

## Notes

- Messages are only marked **Seen** after their issue is created — a failed `gh issue create` leaves the mail unread for the next run.
- Reply text comes from human comments on the issue if present; otherwise the routine writes a short acknowledgement in the project `language=`.
- Never paste credentials into issue bodies — only email metadata and message text (truncated to 3000 chars).
