import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { readConstraints, writeConstraints } from "@/lib/constraints";

// Reads/writes a file on the host project checkout — host process only, not Docker.
export const runtime = "nodejs";

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;

  const project = await prisma.project.findUnique({
    where: { id },
    select: { localPath: true },
  });
  if (!project) {
    return NextResponse.json({ error: "Project not found" }, { status: 404 });
  }

  return NextResponse.json({
    constraints: readConstraints(project.localPath),
    hasLocalPath: Boolean(project.localPath?.trim()),
  });
}

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;

  let body: { constraints?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const project = await prisma.project.findUnique({
    where: { id },
    select: { localPath: true },
  });
  if (!project) {
    return NextResponse.json({ error: "Project not found" }, { status: 404 });
  }
  const localPath = project.localPath?.trim();
  if (!localPath) {
    return NextResponse.json(
      { error: "Project has no Local path — set it in Settings first" },
      { status: 400 }
    );
  }

  try {
    writeConstraints(localPath, body.constraints ?? "");
  } catch (err) {
    console.error("write constraints:", err);
    return NextResponse.json({ error: "Could not write constraints file" }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
