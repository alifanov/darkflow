import { NextRequest, NextResponse } from "next/server";
import { spawn } from "node:child_process";
import path from "node:path";
import { prisma } from "@/lib/prisma";
import { readMailboxEnv, isMailboxConfigured } from "@/lib/mailbox-config";

// Reads the project's IMAP mailbox via a host-side python script, so it must run
// on the Node.js runtime and only works when the dashboard runs as a host process.
export const runtime = "nodejs";

interface FetchedEmail {
  uid: string;
  from: string;
  subject: string;
  sent_at: string | null;
  message_id: string;
  seen: boolean;
  body: string;
}

export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const project = await prisma.project.findUnique({
      where: { id },
      select: { id: true, localPath: true },
    });
    if (!project) {
      return NextResponse.json({ error: "Project not found" }, { status: 404 });
    }

    const localPath = project.localPath?.trim();
    if (!localPath) {
      return NextResponse.json(
        { error: "Set the project's Local path in Settings first." },
        { status: 400 }
      );
    }

    const mailboxEnv = readMailboxEnv(localPath);
    if (!isMailboxConfigured(mailboxEnv)) {
      return NextResponse.json({ configured: false });
    }

    const scriptPath = path.join(process.cwd(), "scripts", "mailbox-fetch.py");
    const stdout = await new Promise<string>((resolve, reject) => {
      const child = spawn("python3", [scriptPath, "--limit", "50"], {
        env: { ...process.env, ...mailboxEnv },
      });
      let out = "";
      let err = "";
      child.stdout.on("data", (d) => (out += d));
      child.stderr.on("data", (d) => (err += d));
      child.once("error", reject);
      child.once("close", (code) => {
        if (code === 0) resolve(out);
        else reject(new Error(err.trim() || `mailbox-fetch exited with code ${code}`));
      });
    });

    const messages = JSON.parse(stdout) as FetchedEmail[];

    let synced = 0;
    for (const m of messages) {
      const messageId = m.message_id || `uid:${m.uid}`;
      const sentAt = m.sent_at ? new Date(m.sent_at) : null;
      await prisma.email.upsert({
        where: { projectId_messageId: { projectId: project.id, messageId } },
        create: {
          projectId: project.id,
          uid: m.uid,
          messageId,
          fromAddr: m.from,
          subject: m.subject,
          body: m.body,
          seen: m.seen,
          sentAt: sentAt && !isNaN(sentAt.getTime()) ? sentAt : null,
        },
        update: {
          uid: m.uid,
          fromAddr: m.from,
          subject: m.subject,
          body: m.body,
          seen: m.seen,
          sentAt: sentAt && !isNaN(sentAt.getTime()) ? sentAt : null,
        },
      });
      synced++;
    }

    return NextResponse.json({ configured: true, synced });
  } catch (err) {
    const code = (err as NodeJS.ErrnoException)?.code;
    if (code === "ENOENT") {
      return NextResponse.json(
        { error: "`python3` not found on PATH. Is the dashboard running on the host?" },
        { status: 500 }
      );
    }
    console.error("mailbox sync:", err);
    const message = err instanceof Error ? err.message : "Failed to sync mailbox";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
