-- CreateTable
CREATE TABLE "WorkerStatus" (
    "id" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "routine" TEXT,
    "status" TEXT NOT NULL DEFAULT 'idle',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WorkerStatus_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "WorkerStatus_projectId_key" ON "WorkerStatus"("projectId");

-- AddForeignKey
ALTER TABLE "WorkerStatus" ADD CONSTRAINT "WorkerStatus_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE CASCADE ON UPDATE CASCADE;
