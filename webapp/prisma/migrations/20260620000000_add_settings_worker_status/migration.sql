-- AlterTable
ALTER TABLE "Settings" ADD COLUMN     "workerVersion" TEXT,
ADD COLUMN     "workerLastSeen" TIMESTAMP(3),
ADD COLUMN     "workerRoutine" TEXT;
