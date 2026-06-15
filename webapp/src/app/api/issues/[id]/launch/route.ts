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
      `Посмотри его: gh issue view ${n}. ` +
      `Разберись, почему он заблокирован, и давай вместе доведём до решения.`;
    const safePrompt = prompt.replace(/'/g, "");
    const command = `claude '${safePrompt}'`;

    // Override with CMUX_BIN if the cmux CLI shim isn't named `cmux` on PATH.
    const cmuxBin = process.env.CMUX_BIN?.trim() || "cmux";
    const child = spawn(
      cmuxBin,
      ["new-workspace", "--cwd", localPath, "--command", command],
      { detached: true, stdio: "ignore" }
    );

    await new Promise<void>((resolve, reject) => {
      child.once("error", reject);
      child.once("spawn", () => {
        child.unref();
        resolve();
      });
    });

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
