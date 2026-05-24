-- AddColumn
ALTER TABLE "Issue" ADD COLUMN "pendingStatus" TEXT;
ALTER TABLE "Issue" ADD COLUMN "pendingStatusAt" TIMESTAMP(3);
