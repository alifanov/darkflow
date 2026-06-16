#!/usr/bin/env python3
"""
Read the most recent messages from an IMAP mailbox and print them as JSON.

This is a READ-ONLY lister used by the dashboard's Mailbox tab. Unlike the worker's
templates/darkflow/mailbox/fetch.py (which fetches UNSEEN and marks them seen), this:
  - selects INBOX read-only and uses BODY.PEEK, so it NEVER changes the \\Seen flag;
  - returns the latest N messages regardless of read/unread state, newest first;
  - includes each message's seen flag and an ISO-8601 sent_at.

Environment variables (required):
  MAILBOX_IMAP_HOST      IMAP server hostname
  MAILBOX_IMAP_PORT      IMAP port (default: 993 SSL)
  MAILBOX_IMAP_USER      Login username
  MAILBOX_IMAP_PASSWORD  Login password

Usage:
  python3 mailbox-fetch.py [--limit N]   # default N=50; prints JSON array to stdout
"""

import argparse
import email
import email.header
import email.utils
import imaplib
import json
import os
import sys


def decode_header_value(raw):
    parts = email.header.decode_header(raw or "")
    chunks = []
    for part, charset in parts:
        if isinstance(part, bytes):
            chunks.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            chunks.append(part)
    return "".join(chunks)


def extract_body(msg):
    """Return plain-text body; fall back to stripping HTML if no text/plain."""
    plain = None
    html = None
    if msg.is_multipart():
        for part in msg.walk():
            ct = part.get_content_type()
            if ct == "text/plain" and plain is None:
                charset = part.get_content_charset() or "utf-8"
                plain = part.get_payload(decode=True).decode(charset, errors="replace")
            elif ct == "text/html" and html is None:
                charset = part.get_content_charset() or "utf-8"
                html = part.get_payload(decode=True).decode(charset, errors="replace")
    else:
        ct = msg.get_content_type()
        charset = msg.get_content_charset() or "utf-8"
        payload = msg.get_payload(decode=True)
        if payload:
            if ct == "text/plain":
                plain = payload.decode(charset, errors="replace")
            elif ct == "text/html":
                html = payload.decode(charset, errors="replace")

    if plain is not None:
        return plain.strip()
    if html is not None:
        import re
        text = re.sub(r"<[^>]+>", " ", html)
        text = re.sub(r"[ \t]+", " ", text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        return text.strip()
    return ""


def parse_date(raw):
    """Return an ISO-8601 string for the Date header, or None if unparseable."""
    if not raw:
        return None
    try:
        dt = email.utils.parsedate_to_datetime(raw)
    except (TypeError, ValueError):
        return None
    if dt is None:
        return None
    return dt.isoformat()


def _env(*names, default=None):
    """First non-empty env var among `names`. Tolerates the naming conventions in
    the wild: MAILBOX_IMAP_*, MAILBOX_USER/PASSWORD, and bare IMAP_* names."""
    for n in names:
        v = os.environ.get(n)
        if v:
            return v
    return default


def connect():
    host = _env("MAILBOX_IMAP_HOST", "IMAP_HOST")
    port = int(_env("MAILBOX_IMAP_PORT", "IMAP_PORT", default="993"))
    user = _env("MAILBOX_IMAP_USER", "MAILBOX_USER", "IMAP_USER")
    password = _env("MAILBOX_IMAP_PASSWORD", "MAILBOX_PASSWORD", "IMAP_PASSWORD")
    if not host:
        raise KeyError("MAILBOX_IMAP_HOST (or IMAP_HOST)")
    if not user:
        raise KeyError("MAILBOX_IMAP_USER (or IMAP_USER)")
    if not password:
        raise KeyError("MAILBOX_IMAP_PASSWORD (or IMAP_PASSWORD)")
    imap = imaplib.IMAP4_SSL(host, port)
    imap.login(user, password)
    return imap


def fetch_recent(imap, limit):
    # readonly=True guarantees the server never updates \Seen on our account.
    imap.select("INBOX", readonly=True)
    _, data = imap.uid("search", None, "ALL")
    uids = data[0].split() if data[0] else []
    # Newest messages have the highest UIDs; take the last `limit`, newest first.
    recent = list(reversed(uids[-limit:]))
    messages = []
    for uid in recent:
        # BODY.PEEK[] fetches the full message WITHOUT setting \Seen.
        _, msg_data = imap.uid("fetch", uid, "(FLAGS BODY.PEEK[])")
        raw = None
        flags = b""
        for part in msg_data:
            if isinstance(part, tuple):
                flags = part[0] or b""
                raw = part[1]
        if raw is None:
            continue
        msg = email.message_from_bytes(raw)
        seen = b"\\Seen" in flags
        messages.append({
            "uid": uid.decode(),
            "from": decode_header_value(msg.get("From", "")),
            "subject": decode_header_value(msg.get("Subject", "")),
            "date": msg.get("Date", ""),
            "sent_at": parse_date(msg.get("Date", "")),
            "message_id": (msg.get("Message-ID", "") or "").strip(),
            "seen": seen,
            "body": extract_body(msg),
        })
    return messages


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=50,
                        help="Maximum number of recent messages to return (default: 50)")
    args = parser.parse_args()

    try:
        imap = connect()
    except KeyError as e:
        print(f"Missing environment variable: {e}", file=sys.stderr)
        sys.exit(1)
    except imaplib.IMAP4.error as e:
        print(f"IMAP error: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        messages = fetch_recent(imap, max(1, args.limit))
        print(json.dumps(messages, ensure_ascii=False))
    finally:
        try:
            imap.logout()
        except Exception:
            pass


if __name__ == "__main__":
    main()
