-- AddColumn: slug, maxConcurrent, posthogProjectId, obsTool, obsUrl, settingsUpdatedAt to Project
-- These fields make the DB the source of truth for project settings (previously local-only in .darkflow).

ALTER TABLE "Project" ADD COLUMN "slug" TEXT;
ALTER TABLE "Project" ADD COLUMN "maxConcurrent" INTEGER NOT NULL DEFAULT 3;
ALTER TABLE "Project" ADD COLUMN "posthogProjectId" TEXT;
ALTER TABLE "Project" ADD COLUMN "obsTool" TEXT;
ALTER TABLE "Project" ADD COLUMN "obsUrl" TEXT;
ALTER TABLE "Project" ADD COLUMN "settingsUpdatedAt" TIMESTAMP(3);
