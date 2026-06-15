-- Add an optional production domain to projects (deployment URL surfaced in the Web UI).
ALTER TABLE "Project" ADD COLUMN "domain" TEXT;
