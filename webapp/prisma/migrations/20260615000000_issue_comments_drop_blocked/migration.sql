-- Add comments storage for issues (GitHub issue comments, synced for needs-human issues)
ALTER TABLE "Issue" ADD COLUMN "comments" JSONB;

-- Deprecate the "blocked" status: an agent can't act on a blocked issue, so it is
-- now folded into needs-human. Convert every existing blocked issue in place.
UPDATE "Issue" SET "needsHuman" = true, "status" = 'none' WHERE "status" = 'blocked';
