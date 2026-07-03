-- AlterTable
ALTER TABLE "Issue" DROP COLUMN "pendingStatus";
ALTER TABLE "Issue" DROP COLUMN "pendingStatusAt";
ALTER TABLE "Issue" DROP COLUMN "pendingComment";
ALTER TABLE "Issue" ADD COLUMN "action" TEXT;
