import fs from "fs";
import path from "path";

/**
 * Mailbox IMAP credentials live in the project's main `<localPath>/.env`
 * (git-ignored, never stored in the DB). Older installs may instead keep them in
 * `.env.darkflow`, so we read `.env` first and fall back to `.env.darkflow`.
 *
 * Naming in the wild is inconsistent across three conventions:
 *   - darkflow templates:   MAILBOX_IMAP_HOST / MAILBOX_IMAP_USER / MAILBOX_IMAP_PASSWORD
 *   - marketloop:           MAILBOX_IMAP_HOST / MAILBOX_USER       / MAILBOX_PASSWORD
 *   - process-emails skill: IMAP_HOST         / IMAP_USER          / IMAP_PASSWORD
 * We accept all of them and normalize to the MAILBOX_IMAP_* names the python
 * fetcher reads.
 */

export type MailboxEnv = Record<string, string>;

// Only these prefixes are pulled out of the env file (avoids slurping unrelated vars).
const RELEVANT_PREFIXES = ["MAILBOX_", "IMAP_", "SMTP_", "EMAIL_"];

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
    if (!RELEVANT_PREFIXES.some((p) => key.startsWith(p))) continue;
    env[key] = stripQuotes(withoutExport.slice(eq + 1));
  }
  return env;
}

/** First non-empty value among the given keys. */
function pick(env: MailboxEnv, ...keys: string[]): string | undefined {
  for (const k of keys) if (env[k]) return env[k];
  return undefined;
}

/**
 * Read the project's mailbox credentials, normalized so the python fetcher
 * always sees `MAILBOX_IMAP_HOST/PORT/USER/PASSWORD`.
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

  const env: MailboxEnv = { ...(fallback ?? {}), ...(primary ?? {}) };

  // Normalize across all three naming conventions onto MAILBOX_IMAP_*.
  const host = pick(env, "MAILBOX_IMAP_HOST", "IMAP_HOST");
  const port = pick(env, "MAILBOX_IMAP_PORT", "IMAP_PORT");
  const user = pick(env, "MAILBOX_IMAP_USER", "MAILBOX_USER", "IMAP_USER");
  const password = pick(env, "MAILBOX_IMAP_PASSWORD", "MAILBOX_PASSWORD", "IMAP_PASSWORD");
  if (host) env.MAILBOX_IMAP_HOST = host;
  if (port) env.MAILBOX_IMAP_PORT = port;
  if (user) env.MAILBOX_IMAP_USER = user;
  if (password) env.MAILBOX_IMAP_PASSWORD = password;

  return env;
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
