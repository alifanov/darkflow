import fs from "fs";
import path from "path";

/**
 * Mailbox IMAP credentials live in each project's `<localPath>/.env.darkflow`
 * (git-ignored, never stored in the DB). These helpers read that file on the
 * host so the dashboard can sync the project's inbox into the DB.
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

/**
 * Read `<localPath>/.env.darkflow` and return only its MAILBOX_* keys.
 * Returns null if localPath is empty or the file does not exist.
 */
export function readMailboxEnv(localPath: string | null | undefined): MailboxEnv | null {
  const dir = localPath?.trim();
  if (!dir) return null;

  let raw: string;
  try {
    raw = fs.readFileSync(path.join(dir, ".env.darkflow"), "utf-8");
  } catch {
    return null;
  }

  const env: MailboxEnv = {};
  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    if (!key.startsWith("MAILBOX_")) continue;
    env[key] = stripQuotes(trimmed.slice(eq + 1));
  }
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
