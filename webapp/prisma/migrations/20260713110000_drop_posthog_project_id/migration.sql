-- Dark Flow moved analytics off PostHog to OpenPanel. The per-project PostHog
-- project id is obsolete under the new model (each project registers its own
-- OpenPanel read-client MCP, which is already scoped to a single project), so
-- the column is dropped.
ALTER TABLE "Project" DROP COLUMN "posthogProjectId";
