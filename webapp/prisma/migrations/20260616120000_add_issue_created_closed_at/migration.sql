-- AlterTable
ALTER TABLE "Issue" ADD COLUMN     "createdAt" TIMESTAMP(3),
ADD COLUMN     "closedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "Issue_createdAt_idx" ON "Issue"("createdAt");

-- CreateIndex
CREATE INDEX "Issue_closedAt_idx" ON "Issue"("closedAt");
