import fs from "fs";
import path from "path";

/**
 * Per-project routine constraints live in `<localPath>/.darkflow.d/constraints.md`
 * (a plain-text file in the project repo, imported into every agent's context via
 * `.darkflow.d/claude.md`). The webapp reads/writes it directly through the
 * project's `localPath`, the same way mailbox creds are read from `.env`.
 */

function constraintsPath(localPath: string): string {
  return path.join(localPath, ".darkflow.d", "constraints.md");
}

/** Read the constraints file. Returns "" if localPath or the file is missing. */
export function readConstraints(localPath: string | null | undefined): string {
  const dir = localPath?.trim();
  if (!dir) return "";
  try {
    return fs.readFileSync(constraintsPath(dir), "utf-8");
  } catch {
    return "";
  }
}

/** Write the constraints file, creating `.darkflow.d/` if needed. */
export function writeConstraints(localPath: string, text: string): void {
  const file = constraintsPath(localPath);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text, "utf-8");
}
