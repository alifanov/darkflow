-- Merge `state` (open/closed) into `status`, collapsing "rejected" into "closed".
-- Closedness used to live on a separate `state` column mirroring GitHub Issues'
-- open/closed field; now that `status` is Dark Flow's own free-form lifecycle
-- value, "closed" becomes a 5th status instead of a parallel boolean-ish axis.
UPDATE "Issue" SET status = 'closed' WHERE state = 'closed' OR status = 'rejected';

DROP INDEX IF EXISTS "Issue_state_idx";
DROP INDEX IF EXISTS "Issue_projectId_state_idx";
ALTER TABLE "Issue" DROP COLUMN "state";

ALTER TABLE "Issue" ALTER COLUMN "status" SET DEFAULT 'proposed';

CREATE INDEX "Issue_status_idx" ON "Issue"("status");
CREATE INDEX "Issue_projectId_status_idx" ON "Issue"("projectId", "status");
