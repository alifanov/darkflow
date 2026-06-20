import { prisma } from "@/lib/prisma";
import { getLatestDarkflowVersion } from "@/lib/darkflow-version";

export const dynamic = "force-dynamic";

// One global worker services every project, so its version and liveness are
// machine-level. This header badge is the single source of truth for both — it
// replaces the old per-project version + worker columns on the dashboard.
export async function GlobalWorkerStatus() {
  const [settings, latest] = await Promise.all([
    prisma.settings.findUnique({ where: { id: "global" } }),
    Promise.resolve(getLatestDarkflowVersion()),
  ]);

  const lastSeen = settings?.workerLastSeen ? new Date(settings.workerLastSeen).getTime() : null;
  // Worker beats every ~30s tick; allow a couple of misses before "offline".
  const alive = lastSeen != null && Date.now() - lastSeen < 90 * 1000;
  const version = settings?.workerVersion ?? null;
  const outdated = version != null && version !== latest;

  return (
    <div className="ml-auto flex items-center gap-3 text-xs">
      {/* Version */}
      {version == null ? (
        <span className="font-mono px-1.5 py-0.5 rounded" style={{ background: "var(--border)", color: "var(--muted)" }}>
          DF —
        </span>
      ) : outdated ? (
        <span
          className="font-mono px-1.5 py-0.5 rounded bg-yellow-100 text-yellow-900 dark:bg-yellow-900/30 dark:text-yellow-200"
          title={`Worker on v${version}; latest is v${latest}. Run install.sh --self-update.`}
        >
          v{version} ⚠ →{latest}
        </span>
      ) : (
        <span className="font-mono px-1.5 py-0.5 rounded" style={{ background: "var(--border)", color: "var(--muted)" }}>
          v{version}
        </span>
      )}

      {/* Worker liveness */}
      {alive ? (
        <span className="flex items-center gap-1.5" style={{ color: "var(--green)" }}>
          <span
            className={settings?.workerRoutine ? "worker-dot-running shrink-0" : "shrink-0"}
            style={{
              width: 7,
              height: 7,
              borderRadius: "50%",
              background: "var(--green)",
              opacity: settings?.workerRoutine ? 1 : 0.55,
              display: "inline-block",
            }}
          />
          {settings?.workerRoutine ? `worker: ${settings.workerRoutine}` : "worker online"}
        </span>
      ) : (
        <span className="flex items-center gap-1.5" style={{ color: "var(--muted)" }} title="No worker heartbeat in the last 90s">
          <span
            className="shrink-0"
            style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--muted)", opacity: 0.6, display: "inline-block" }}
          />
          worker offline
        </span>
      )}
    </div>
  );
}
