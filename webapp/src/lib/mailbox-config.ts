import fs from "fs";
import path from "path";

/**
 * Mailbox IMAP credentials live in the project's main `<localPath>/.env`
 * (git-ignored, never stored in the DB). Older installs may instead keep them in
 * `.env.darkflow`, so we read `.env` first and fall back to `.env.darkflow`.
 *
 * Canonical variable names (the single, unified convention) are
 * `MAILBOX_IMAP_HOST` / `MAILBOX_IMAP_PORT` / `MAILBOX_IMAP_USER` /
 * `MAILBOX_IMAP_PASSWORD` — matching what the installer writes and the python
 * fetcher reads.
 */

export type MailboxEnv = Record<string, string>;

function stripQuotes(value: string): string {
  const v = value.trim();
  if (
    (v.startsWith('"') && v.endsWith('"')) ||
    (v.startsWith("'") && v.endsWith("'"))
  ) {
    return v.slice(1, -1);
  }
  return v;
}

function parseEnvFile(filePath: string): MailboxEnv | null {
  let raw: string;
  try {
    raw = fs.readFileSync(filePath, "utf-8");
  } catch {
    return null;
  }
  const env: MailboxEnv = {};
  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const withoutExport = trimmed.replace(/^export\s+/, "");
    const eq = withoutExport.indexOf("=");
    if (eq === -1) continue;
    const key = withoutExport.slice(0, eq).trim();
    if (!key.startsWith("MAILBOX_")) continue;
    env[key] = stripQuotes(withoutExport.slice(eq + 1));
  }
  return env;
}

/**
 * Read the project's MAILBOX_* credentials.
 * Returns null if neither `.env` nor `.env.darkflow` exists.
 */
export function readMailboxEnv(localPath: string | null | undefined): MailboxEnv | null {
  const dir = localPath?.trim();
  if (!dir) return null;

  // `.env` is canonical; `.env.darkflow` is the legacy fallback. Keys from `.env`
  // win when both files define them.
  const fallback = parseEnvFile(path.join(dir, ".env.darkflow"));
  const primary = parseEnvFile(path.join(dir, ".env"));
  if (fallback === null && primary === null) return null;

  return { ...(fallback ?? {}), ...(primary ?? {}) };
}

/** True when the IMAP credentials needed to connect are all present. */
export function isMailboxConfigured(env: MailboxEnv | null): env is MailboxEnv {
  return Boolean(
    env &&
      env.MAILBOX_IMAP_HOST &&
      env.MAILBOX_IMAP_USER &&
      env.MAILBOX_IMAP_PASSWORD
  );
}
