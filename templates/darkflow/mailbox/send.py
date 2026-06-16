#!/usr/bin/env python3
"""
Send an email reply via SMTP.

Environment variables (required):
  MAILBOX_SMTP_HOST      SMTP server hostname
  MAILBOX_SMTP_PORT      SMTP port (default: 587 STARTTLS)
  MAILBOX_SMTP_USER      Login username
  MAILBOX_SMTP_PASSWORD  Login password
  MAILBOX_IMAP_USER      Used as From address if MAILBOX_SMTP_USER equals host

Optional:
  MAILBOX_SMTP_SSL       Set to "1" to use SSL on port (overrides STARTTLS)

Usage:
  python3 send.py --to "user@example.com" \
                  --subject "Re: Your message" \
                  --in-reply-to "<message-id@example.com>" \
                  --body-file /tmp/reply.txt
"""

import argparse
import email.message
import os
import smtplib
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--to", required=True)
    parser.add_argument("--subject", required=True)
    parser.add_argument("--in-reply-to", default="")
    parser.add_argument("--body-file", required=True)
    args = parser.parse_args()

    # Tolerate the naming conventions in the wild: MAILBOX_SMTP_*, and the bare
    # SMTP_*/IMAP_* names used by the process-emails skill.
    def _env(*names, default=""):
        for n in names:
            v = os.environ.get(n)
            if v:
                return v
        return default

    smtp_host = _env("MAILBOX_SMTP_HOST", "SMTP_HOST")
    smtp_port = int(_env("MAILBOX_SMTP_PORT", "SMTP_PORT", default="587"))
    smtp_user = _env("MAILBOX_SMTP_USER", "SMTP_USER")
    smtp_pass = _env("MAILBOX_SMTP_PASSWORD", "SMTP_PASSWORD")
    use_ssl = _env("MAILBOX_SMTP_SSL", "SMTP_SSL") == "1"
    from_addr = smtp_user or _env("MAILBOX_IMAP_USER", "MAILBOX_USER", "IMAP_USER")

    if not smtp_host:
        print("Missing MAILBOX_SMTP_HOST", file=sys.stderr)
        sys.exit(1)
    if not from_addr:
        print("Missing MAILBOX_SMTP_USER or MAILBOX_IMAP_USER", file=sys.stderr)
        sys.exit(1)

    try:
        with open(args.body_file, encoding="utf-8") as f:
            body = f.read()
    except OSError as e:
        print(f"Cannot read body file: {e}", file=sys.stderr)
        sys.exit(1)

    msg = email.message.EmailMessage()
    msg["From"] = from_addr
    msg["To"] = args.to
    msg["Subject"] = args.subject
    if args.in_reply_to:
        msg["In-Reply-To"] = args.in_reply_to
        msg["References"] = args.in_reply_to
    msg.set_content(body)

    try:
        if use_ssl:
            with smtplib.SMTP_SSL(smtp_host, smtp_port) as server:
                server.login(smtp_user, smtp_pass)
                server.send_message(msg)
        else:
            with smtplib.SMTP(smtp_host, smtp_port) as server:
                server.ehlo()
                server.starttls()
                server.ehlo()
                server.login(smtp_user, smtp_pass)
                server.send_message(msg)
    except smtplib.SMTPException as e:
        print(f"SMTP error: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Sent reply to {args.to}")


if __name__ == "__main__":
    main()
