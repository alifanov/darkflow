-- Performance indexes for Issue queries
CREATE INDEX "Issue_state_idx" ON "Issue"("state");
CREATE INDEX "Issue_projectId_state_idx" ON "Issue"("projectId", "state");
CREATE INDEX "Issue_projectId_needsHuman_idx" ON "Issue"("projectId", "needsHuman");

-- Performance indexes for RoutineLog queries
CREATE INDEX "RoutineLog_projectId_timestamp_idx" ON "RoutineLog"("projectId", "timestamp" DESC);

-- Performance indexes for AnalyticsSnapshot queries
CREATE INDEX "AnalyticsSnapshot_projectId_capturedAt_idx" ON "AnalyticsSnapshot"("projectId", "capturedAt" DESC);
