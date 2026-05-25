import fs from "fs";
import path from "path";

let _cached: string | null = null;

export function getLatestDarkflowVersion(): string {
  if (_cached !== null) return _cached;

  if (process.env.DARKFLOW_LATEST_VERSION) {
    _cached = process.env.DARKFLOW_LATEST_VERSION.trim();
    return _cached;
  }

  // Dev: cwd is webapp/, prod (Docker): VERSION mounted at /app/VERSION
  const candidates = [
    path.join(process.cwd(), "VERSION"),
    path.join(process.cwd(), "..", "VERSION"),
  ];

  for (const p of candidates) {
    try {
      _cached = fs.readFileSync(p, "utf-8").trim();
      return _cached;
    } catch {
      // try next
    }
  }

  _cached = "unknown";
  return _cached;
}
