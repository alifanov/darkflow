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

// Best-effort synchronous label push so the UI doesn't sit on "Pending Sync"
// until the worker's ~5-min cycle. Returns true when GitHub now reflects the
// target (caller then clears pendingStatus); false on any failure, leaving
// pendingStatus for the worker to reconcile.
// ponytail: relies on ambient `gh auth` on the host — fine for single-account
// setups; if multi-account/token-per-repo is needed, thread the project token in.
export async function applyStatusToGitHub(
  issueId: string,
  target: "approved" | "rejected" | "closed"
): Promise<boolean> {
  const issue = await prisma.issue.findUnique({
    where: { id: issueId },
    select: { number: true, project: { select: { repoUrl: true } } },
  });
  const repoUrl = issue?.project?.repoUrl;
  if (!repoUrl) return false;
  const slug = repoSlug(repoUrl);
  if (!slug) return false;

  const num = String(issue!.number);
  const removeArgs = STATUS_LABELS.flatMap((l) => ["--remove-label", l]);
  const opts = { timeout: 15000 } as const;

  try {
    if (target === "closed") {
      await execFileP(
        "gh",
        ["issue", "edit", num, "-R", slug, ...removeArgs, "--remove-label", "needs-human"],
        opts
      ).catch(() => {});
      await execFileP("gh", ["issue", "close", num, "-R", slug], opts);
    } else {
      await execFileP(
        "gh",
        ["issue", "edit", num, "-R", slug, ...removeArgs, "--add-label", `status:${target}`],
        opts
      );
      if (target === "rejected") {
        await execFileP("gh", ["issue", "close", num, "-R", slug], opts).catch(() => {});
      }
    }
    return true;
  } catch {
    return false;
  }
}
