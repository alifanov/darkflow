Check the project's IMAP inbox for new messages, create tasks from them, and send approved email replies via SMTP.

> **Note — cheap pre-flight.** The dispatcher (`darkflow-run.sh`) runs a read-only IMAP unseen-count (`fetch.py --count`) and a `df task list` for approved reply tasks *before* launching this agent. If there's no new mail and no reply pending, it **skips this agent entirely** — so on a quiet inbox you are not invoked. When you *are* invoked there is real work (new mail and/or replies to send); proceed with the full steps below.

## Step 1 — Read config

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `language` → output/task language (default: English)
- `branch` → main branch name
- `mergeStrategy` → `pr` or `direct`

Load mailbox credentials from `.env` (the project's main env; `.env.darkflow` is a legacy fallback):
```bash
set -a; [ -f .env.darkflow ] && source .env.darkflow; [ -f .env ] && source .env; set +a
```

If `MAILBOX_IMAP_HOST` is empty after sourcing — stop and print "mailbox not configured — add MAILBOX_IMAP_* vars to .env".

## Step 2 — Send approved replies

Find all open tasks with `status:approved`, `source:mailbox`, `action:reply`:

```bash
~/.darkflow/df task list --status approved --source mailbox --action reply --state open
```

For each such task:

1. Extract email metadata from the task body (look for the structured block added in Step 4):
   - **To** — value of `From:` field in the task body (reply goes back to the sender)
   - **Subject** — `Re: ` + original subject from `Subject:` field
   - **Message-ID** — value of `Message-ID:` field for threading

2. Check if there are any human comments on the task. If yes — include them as the reply body context (the human may have added instructions or draft text). If not — write a polite, short acknowledgement in `language` that the message was received and is being handled.

3. Write the reply body to a temp file:
   ```bash
   cat > /tmp/darkflow_reply_$number.txt << 'EOF'
   <reply text here>
   EOF
   ```

4. Send the reply:
   ```bash
   python3 ~/.darkflow/mailbox/send.py \
     --to "<From address from task>" \
     --subject "Re: <original subject>" \
     --in-reply-to "<message-id from task>" \
     --body-file /tmp/darkflow_reply_$number.txt
   ```

5. If send succeeds: leave a comment on the task ("Reply sent to <address>"), then close it:
   ```bash
   ~/.darkflow/df task comment $number --body "Reply sent to <address>."
   ~/.darkflow/df task close $number
   ```

6. If send fails: `~/.darkflow/df task needs-human $number` (needs-human and status:approved are mutually exclusive — parking it for a human must drop it from the approved queue), leave a comment with the error. Continue to the next task.

## Step 3 — Fetch new mail

```bash
python3 ~/.darkflow/mailbox/fetch.py
```

The script prints a JSON array of unseen messages to stdout. Each element:
```json
{ "uid": "123", "from": "...", "subject": "...", "date": "...", "message_id": "...", "body": "..." }
```

If the array is empty — skip to Step 5.

Capture the output and parse it. Process each message one by one in Step 4.

## Step 4 — Create tasks

For each message from Step 3:

**Determine priority:**
- `high` — subject or body contains urgency keywords: "broken", "ошибка", "не работает", "urgent", "critical", "срочно", "bug", "crash", "down"
- `medium` — everything else (default)

**Create the task.** Leave `--action` unset — a human picks `reply` or `fix` before approving (see body text below):

```bash
~/.darkflow/df task create \
  --title "<action-oriented title>" \
  --source mailbox --priority <high or medium> \
  --body "$(cat << 'EOF'
## Incoming email

**From:** <from>
**Date:** <date>
**Subject:** <subject>
**Message-ID:** <message_id>

## Message

<body text — truncate to 3000 chars if longer, add "... [truncated]">

## What to do

A human decides the action before approving this task — run one of:

- `~/.darkflow/df task set-action <n> reply` → mailbox-check will write and send an email reply on your behalf
- `~/.darkflow/df task set-action <n> fix` → fix-issues will treat this as a code task

Then approve the task to trigger the action.
EOF
)"
```

**Title format** — rewrite to be action-oriented in `language`:
- For support requests: "Reply to <sender name>: <their subject>"
- For bug reports: "Fix: <what is broken> (reported by <sender name>)"
- For feature requests: "Evaluate: <request summary> (from <sender name>)"

**After successfully creating the task** — mark the message as Seen in the mailbox:
```bash
python3 ~/.darkflow/mailbox/fetch.py --mark-seen <uid>
```

If task creation fails for a message — do NOT mark it as Seen (it will be re-fetched next run). Log the error and continue.

Language for all tasks, comments, and reply emails: the `language` value from `.darkflow.d/state/config.json`.
