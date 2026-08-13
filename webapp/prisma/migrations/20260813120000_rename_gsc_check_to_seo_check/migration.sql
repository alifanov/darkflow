-- Routine `gsc-check` was renamed to `seo-check` in 4.35.0: it always was a full
-- SEO audit with Search Console as its data half, and the old name hid that.
-- Rename the stored schedule and its history in place so each project keeps its
-- cron/model/enabled settings and its run streak (`df runs`, which counts by
-- RoutineLog.routine). Data-only — no schema change, nothing deleted except a
-- duplicate row that would collide with the @@unique([projectId, name]) index.

DELETE FROM "RoutineConfig" a
  USING "RoutineConfig" b
  WHERE a.name = 'gsc-check'
    AND b.name = 'seo-check'
    AND a."projectId" = b."projectId";

UPDATE "RoutineConfig" SET name    = 'seo-check' WHERE name    = 'gsc-check';
UPDATE "RoutineLog"    SET routine = 'seo-check' WHERE routine = 'gsc-check';
