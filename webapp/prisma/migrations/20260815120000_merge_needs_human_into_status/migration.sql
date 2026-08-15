-- needsHuman was never an independent flag: every write path paired it with a
-- status ("block" → proposed+needsHuman, "approve" → approved+cleared). Collapse
-- it into the status value it always travelled with.
UPDATE "Issue" SET "status" = 'needs-human' WHERE "needsHuman" = true AND "status" <> 'closed';

DROP INDEX IF EXISTS "Issue_projectId_needsHuman_idx";
ALTER TABLE "Issue" DROP COLUMN "needsHuman";
