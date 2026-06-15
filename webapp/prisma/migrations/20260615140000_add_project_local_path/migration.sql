-- Local filesystem path of the project checkout on the host running the dashboard.
-- Used by the "Fix in cmux" launch button to set the cmux workspace working dir.
ALTER TABLE "Project" ADD COLUMN "localPath" TEXT;
