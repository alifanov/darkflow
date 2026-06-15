import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function DELETE(
  _req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;

  try {
    const project = await prisma.project.findUnique({ where: { id } });
    if (!project) {
      return NextResponse.json({ error: "Project not found" }, { status: 404 });
    }

    await prisma.project.delete({ where: { id } });

    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("delete project:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}

interface RoutinePatch {
  name: string;
  cron?: string | null;
  model?: string | null;
  engine?: string | null;
  enabled?: boolean;
  permissionMode?: string | null;
}

interface SettingsPatchBody {
  name?: string;
  slug?: string;
  domain?: string | null;
  localPath?: string | null;
  branch?: string;
  language?: string;
  mergeStrategy?: string;
  modules?: string[];
  maxConcurrent?: number;
  posthogProjectId?: string | null;
  obsTool?: string | null;
  obsUrl?: string | null;
  routines?: RoutinePatch[];
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;

  let body: SettingsPatchBody;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  try {
    const project = await prisma.project.findUnique({ where: { id } });
    if (!project) {
      return NextResponse.json({ error: "Project not found" }, { status: 404 });
    }

    // Update scalar settings — only whitelisted fields
    await prisma.project.update({
      where: { id },
      data: {
        ...(body.name !== undefined && { name: body.name }),
        ...(body.slug !== undefined && { slug: body.slug }),
        ...(body.domain !== undefined && { domain: body.domain }),
        ...(body.localPath !== undefined && { localPath: body.localPath }),
        ...(body.branch !== undefined && { branch: body.branch }),
        ...(body.language !== undefined && { language: body.language }),
        ...(body.mergeStrategy !== undefined && { mergeStrategy: body.mergeStrategy }),
        ...(body.modules !== undefined && { modules: body.modules }),
        ...(body.maxConcurrent !== undefined && { maxConcurrent: body.maxConcurrent }),
        ...(body.posthogProjectId !== undefined && { posthogProjectId: body.posthogProjectId }),
        ...(body.obsTool !== undefined && { obsTool: body.obsTool }),
        ...(body.obsUrl !== undefined && { obsUrl: body.obsUrl }),
        settingsUpdatedAt: new Date(),
      },
    });

    // Upsert routine configs if provided
    if (body.routines !== undefined) {
      for (const r of body.routines) {
        await prisma.routineConfig.upsert({
          where: { projectId_name: { projectId: id, name: r.name } },
          create: {
            projectId: id,
            name: r.name,
            cron: r.cron ?? null,
            model: r.model ?? null,
            engine: r.engine ?? "claude",
            enabled: r.enabled ?? true,
            permissionMode: r.permissionMode ?? null,
          },
          update: {
            ...(r.cron !== undefined && { cron: r.cron }),
            ...(r.model !== undefined && { model: r.model }),
            ...(r.engine !== undefined && { engine: r.engine }),
            ...(r.enabled !== undefined && { enabled: r.enabled }),
            ...(r.permissionMode !== undefined && { permissionMode: r.permissionMode }),
          },
        });
      }
    }

    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("patch project settings:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
