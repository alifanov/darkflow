#!/usr/bin/env python3
"""
Fetch unseen messages from an IMAP mailbox and print them as JSON.

Environment variables (required):
  MAILBOX_IMAP_HOST      IMAP server hostname
  MAILBOX_IMAP_PORT      IMAP port (default: 993 SSL)
  MAILBOX_IMAP_USER      Login username
  MAILBOX_IMAP_PASSWORD  Login password

Usage:
  python3 fetch.py                     # Print JSON array of unseen messages
  python3 fetch.py --count             # Print only the unseen count (cheap, read-only)
  python3 fetch.py --mark-seen 1 2 3  # Mark UIDs as Seen, print nothing
"""

import argparse
import email
import email.header
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


def _env(*names, default=None):
    """First non-empty env var among `names`. Tolerates the three naming
    conventions in the wild: MAILBOX_IMAP_*, MAILBOX_USER/PASSWORD, and the bare
    IMAP_* names used by the process-emails skill."""
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


def fetch_unseen(imap):
    imap.select("INBOX", readonly=False)
    _, data = imap.uid("search", None, "UNSEEN")
    uids = data[0].split() if data[0] else []
    messages = []
    for uid in uids:
        _, msg_data = imap.uid("fetch", uid, "(RFC822)")
        raw = msg_data[0][1]
        msg = email.message_from_bytes(raw)
        messages.append({
            "uid": uid.decode(),
            "from": decode_header_value(msg.get("From", "")),
            "subject": decode_header_value(msg.get("Subject", "")),
            "date": msg.get("Date", ""),
            "message_id": msg.get("Message-ID", ""),
            "body": extract_body(msg),
        })
    return messages


def count_unseen(imap):
    """Cheap count of unseen messages without altering any flags."""
    imap.select("INBOX", readonly=True)
    _, data = imap.uid("search", None, "UNSEEN")
    return len(data[0].split()) if data[0] else 0


def mark_seen(imap, uids):
    imap.select("INBOX", readonly=False)
    for uid in uids:
        imap.uid("store", uid, "+FLAGS", r"(\Seen)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mark-seen", nargs="+", metavar="UID",
                        help="Mark given UIDs as \\Seen and exit")
    parser.add_argument("--count", action="store_true",
                        help="Print only the unseen-message count (read-only) and exit")
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
        if args.count:
            print(count_unseen(imap))
        elif args.mark_seen:
            mark_seen(imap, [uid.encode() for uid in args.mark_seen])
        else:
            messages = fetch_unseen(imap)
            print(json.dumps(messages, ensure_ascii=False))
    finally:
        try:
            imap.logout()
        except Exception:
            pass


if __name__ == "__main__":
    main()
