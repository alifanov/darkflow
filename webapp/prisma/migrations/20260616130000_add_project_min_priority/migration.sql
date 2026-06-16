-- Per-project minimum issue priority threshold (Web UI slider).
-- Routines won't file issues below this level; existing lower-priority issues
-- are highlighted in the Web UI issue list. Default "medium" preserves the prior
-- behavior (routine priority:low auto-discarded; critical/high/medium kept).
ALTER TABLE "Project" ADD COLUMN "minPriority" TEXT NOT NULL DEFAULT 'medium';
