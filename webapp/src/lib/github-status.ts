import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { prisma } from "@/lib/prisma";

const execFileP = promisify(execFile);

// Mirror of STATUS_LABELS_ALL in darkflow-run.sh — removed wholesale so exactly
// one status:* label remains. gh tolerates removing labels not on the issue.
const STATUS_LABELS = [
  "status:proposed",
  "status:approved",
  "status:rejected",
  "status:in-progress",
  "status:blocked",
];

// owner/repo from a GitHub URL or git remote (https or ssh form).
function repoSlug(url: string): string | null {
  const m = url.match(/github\.com[/:]([^/]+\/[^/.\s]+)/);
  return m ? m[1] : null;
}

const gh = (args: string[]) => execFileP("gh", args, { timeout: 20000 });

// `gh issue close` on an already-closed issue exits non-zero; treat that as
// success so the operation is idempotent.
async function closeIdempotent(num: string, slug: string): Promise<void> {
  try {
    await gh(["issue", "close", num, "-R", slug]);
  } catch (e) {
    const s = `${(e as { stderr?: string }).stderr ?? ""}${(e as { stdout?: string }).stdout ?? ""}`.toLowerCase();
    if (!s.includes("already") && !s.includes("closed")) throw e;
  }
}

// Synchronously push the status to GitHub via `gh` on the host. The caller waits
// for this and only mutates the DB on { ok: true } — no optimistic writes. On
// failure the DB is left untouched and `error` is surfaced to the UI.
// ponytail: relies on ambient `gh auth` on the host (single-account). No worker
// fallback anymore — in the Docker profile without gh these actions just fail.
export async function applyStatusToGitHub(
  issueId: string,
  target: "approved" | "rejected" | "closed"
): Promise<{ ok: boolean; error?: string }> {
  const issue = await prisma.issue.findUnique({
    where: { id: issueId },
    select: { number: true, project: { select: { repoUrl: true } } },
  });
  const repoUrl = issue?.project?.repoUrl;
  if (!repoUrl) return { ok: false, error: "issue or repo not found" };
  const slug = repoSlug(repoUrl);
  if (!slug) return { ok: false, error: `could not parse repo from ${repoUrl}` };

  const num = String(issue!.number);
  const removeArgs = STATUS_LABELS.flatMap((l) => ["--remove-label", l]);

  try {
    if (target === "closed") {
      await gh(["issue", "edit", num, "-R", slug, ...removeArgs, "--remove-label", "needs-human"]).catch(() => {});
      await closeIdempotent(num, slug);
    } else {
      // Approving routes the issue to the autonomous agent, so it overrides the
      // needs-human gate — the worker excludes needs-human from its queue, so
      // leaving it on would make an "approved" issue silently never get picked
      // up. (The close path strips it too.)
      await gh(["issue", "edit", num, "-R", slug, ...removeArgs, "--remove-label", "needs-human", "--add-label", `status:${target}`]);
      if (target === "rejected") await closeIdempotent(num, slug);
    }
    return { ok: true };
  } catch (e) {
    const msg = `${(e as { stderr?: string }).stderr ?? (e as Error).message ?? "gh failed"}`.split("\n")[0];
    return { ok: false, error: msg };
  }
}
