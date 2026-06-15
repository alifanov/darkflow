-- Track when the worker last pulled settings from the Web UI (via get-config.sh),
-- so the dashboard can flag projects whose running worker hasn't applied the
-- latest config yet (settingsUpdatedAt > configSyncedAt).
ALTER TABLE "WorkerStatus" ADD COLUMN "configSyncedAt" TIMESTAMP(3);
