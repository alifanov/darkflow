-- Additive only: snooze timestamp for tasks ("do not pick up before").
ALTER TABLE "Issue" ADD COLUMN "scheduledFor" TIMESTAMP(3);
