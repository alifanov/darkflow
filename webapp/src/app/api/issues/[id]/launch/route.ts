import { NextRequest, NextResponse } from "next/server";
import { spawn } from "node:child_process";
import { prisma } from "@/lib/prisma";

// This route shells out to the host's `cmux` CLI, so it must run on the Node.js
// runtime (not edge) and only works when the dashboard runs as a host process.
export const runtime = "nodejs";

export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const issue = await prisma.issue.findUnique({
      where: { id },
      include: { project: { select: { localPath: true, name: true } } },
    });
    if (!issue) {
      return NextResponse.json({ error: "Issue not found" }, { status: 404 });
    }

    const localPath = issue.project.localPath?.trim();
    if (!localPath) {
      return NextResponse.json(
        { error: "Set the project's Local path in Settings first." },
        { status: 400 }
      );
    }

    const n = issue.number;
    // Interactive claude session focused on this one needs-human issue. Keep the
    // prompt free of single quotes — it is wrapped in single quotes inside the
    // shell command cmux runs.
    const prompt =
      `Issue #${n} помечен needs-human и требует ручного вмешательства. ` +
      `Посмотри его: df task view ${n}. ` +
      `Разберись, почему он заблокирован, и давай вместе доведём до решения.`;
    const safePrompt = prompt.replace(/'/g, "");
    // --worktree isolates each fix in its own git worktree so several issues can be
    // worked on in parallel without stepping on each other.
    const command = `claude --worktree issue-${n} '${safePrompt}'`;

    // Workspace title: "[project] #123"
    const wsName = `[${issue.project.name}] #${n}`;

    // Override with CMUX_BIN if the cmux CLI shim isn't named `cmux` on PATH.
    const cmuxBin = process.env.CMUX_BIN?.trim() || "cmux";
    const child = spawn(
      cmuxBin,
      ["new-workspace", "--name", wsName, "--cwd", localPath, "--command", command, "--focus", "true"],
      { stdio: ["ignore", "pipe", "pipe"] }
    );

    // `cmux new-workspace` is a short-lived socket client: it prints
    // "OK workspace:N" and exits on success, or an "Error: ..." line with a
    // non-zero code on failure. Wait for the real exit and inspect it — do NOT
    // report success on `spawn` alone. A common failure: when this dashboard
    // runs under launchd, the cmux control socket refuses the detached session
    // ("Failed to write to socket (Broken pipe, errno 32)") so no workspace is
    // ever created. Surfacing that beats a silent, lying `{ ok: true }`.
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));

    const exitCode = await new Promise<number>((resolve, reject) => {
      const timer = setTimeout(() => {
        child.kill();
        reject(new Error("cmux new-workspace timed out after 10s"));
      }, 10_000);
      child.once("error", (e) => {
        clearTimeout(timer);
        reject(e);
      });
      child.once("close", (code) => {
        clearTimeout(timer);
        resolve(code ?? 0);
      });
    });

    if (exitCode !== 0 || !/\bOK\s+workspace:/i.test(stdout)) {
      const detail =
        (stderr || stdout).trim() || `cmux exited with code ${exitCode}`;
      console.error("launch issue in cmux failed:", detail);
      const hint = /broken pipe|write to socket/i.test(detail)
        ? " (the cmux socket rejects launchd-detached processes — run the dashboard from an interactive session)"
        : "";
      return NextResponse.json(
        { error: `cmux couldn't create the workspace: ${detail}${hint}` },
        { status: 502 }
      );
    }

    // Bring the cmux app to the foreground (macOS). `--focus true` selects the new
    // workspace inside cmux, but the OS window still needs activating. Best-effort.
    const appMatch = cmuxBin.match(/^(.*\.app)\//);
    const openArgs = appMatch ? [appMatch[1]] : ["-a", "cmux"];
    try {
      const opener = spawn("open", openArgs, { detached: true, stdio: "ignore" });
      opener.on("error", () => {});
      opener.unref();
    } catch {
      // activation is non-critical — the workspace was already created
    }

    return NextResponse.json({ ok: true });
  } catch (err) {
    const code = (err as NodeJS.ErrnoException)?.code;
    if (code === "ENOENT") {
      return NextResponse.json(
        { error: "`cmux` CLI not found on PATH. Is the dashboard running on the host?" },
        { status: 500 }
      );
    }
    console.error("launch issue in cmux:", err);
    return NextResponse.json({ error: "Failed to launch cmux workspace" }, { status: 500 });
  }
}
