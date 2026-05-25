import fs from "fs";
import path from "path";

export function getLatestDarkflowVersion(): string {
  if (process.env.DARKFLOW_LATEST_VERSION) {
    return process.env.DARKFLOW_LATEST_VERSION.trim();
  }

  // Dev: cwd is webapp/, prod (Docker): VERSION mounted at /app/VERSION
  const candidates = [
    path.join(process.cwd(), "VERSION"),
    path.join(process.cwd(), "..", "VERSION"),
  ];

  for (const p of candidates) {
    try {
      return fs.readFileSync(p, "utf-8").trim();
    } catch {
      // try next
    }
  }

  return "unknown";
}
